// Authentication.mo
// Sistema completo de autenticación y autorización

import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Int "mo:base/Int";

import Types "./Types";

module {
    
    // ========================================
    // TIPOS DE AUTENTICACIÓN
    // ========================================
    
    public type UserRole = {
        #Owner;          // Dueño del contrato (máximo nivel)
        #Admin;          // Administrador del sistema
        #PropertyOwner;  // Propietario de propiedades
        #Investor;       // Inversor/comprador de tokens
        #Viewer;         // Solo lectura
        #Suspended;      // Usuario suspendido
    };
    
    public type Permission = {
        #SystemManagement;        // Gestionar sistema completo
        #UserManagement;          // Gestionar usuarios
        #PropertyManagement;      // Crear/editar propiedades
        #TokenManagement;         // Mint/transferir tokens
        #PaymentManagement;       // Procesar pagos
        #ViewSensitiveData;       // Ver datos sensibles
        #ViewPublicData;          // Ver datos públicos
        #EmergencyActions;        // Acciones de emergencia
    };
    
    public type UserProfile = {
        id: Types.UserId;
        role: UserRole;
        permissions: [Permission];
        isActive: Bool;
        isVerified: Bool;
        createdAt: Int;
        lastLoginAt: ?Int;
        email: ?Text;
        name: ?Text;
        country: ?Text;
        kycStatus: KYCStatus;
        sessionToken: ?Text;
        sessionExpiry: ?Int;
    };
    
    public type KYCStatus = {
        #NotStarted;
        #InProgress;
        #Approved;
        #Rejected;
        #Expired;
    };
    
    public type SessionInfo = {
        userId: Types.UserId;
        token: Text;
        createdAt: Int;
        expiresAt: Int;
        isActive: Bool;
        lastActivity: Int;
    };
    
    public type AuthError = {
        #NotAuthenticated;
        #NotAuthorized;
        #SessionExpired;
        #UserSuspended;
        #UserNotFound;
        #InvalidCredentials;
        #KYCRequired;
        #SystemError: Text;
    };
    
    // ========================================
    // CLASE AUTHENTICATION MANAGER
    // ========================================
    
    public class AuthenticationManager() {
        
        // Storage para usuarios y sesiones
        private var users = HashMap.HashMap<Types.UserId, UserProfile>(100, Principal.equal, Principal.hash);
        private var sessions = HashMap.HashMap<Text, SessionInfo>(100, Text.equal, Text.hash);
        
        // Helper function para roleToText (necesaria antes del HashMap)
        private func roleToText(role: UserRole) : Text {
            switch (role) {
                case (#Owner) { "Owner" };
                case (#Admin) { "Admin" };
                case (#PropertyOwner) { "PropertyOwner" };
                case (#Investor) { "Investor" };
                case (#Viewer) { "Viewer" };
                case (#Suspended) { "Suspended" };
            }
        };
        
        private var rolePermissions = HashMap.HashMap<UserRole, [Permission]>(10, func(a: UserRole, b: UserRole) : Bool { 
            roleToText(a) == roleToText(b) 
        }, func(role: UserRole) : Nat32 { 
            Text.hash(roleToText(role))
        });
        
        // Configuración
        private let SESSION_DURATION: Int = 24 * 60 * 60 * 1000000000; // 24 horas en nanosegundos
        private let MAX_SESSIONS_PER_USER: Nat = 5;
        
        // ========================================
        // INICIALIZACIÓN
        // ========================================
        
        public func initialize(contractOwner: Types.UserId) {
            setupRolePermissions();
            createOwnerAccount(contractOwner);
        };
        
        private func setupRolePermissions() {
            // Owner - Todos los permisos
            rolePermissions.put(#Owner, [
                #SystemManagement, #UserManagement, #PropertyManagement,
                #TokenManagement, #PaymentManagement, #ViewSensitiveData,
                #ViewPublicData, #EmergencyActions
            ]);
            
            // Admin - Casi todos los permisos
            rolePermissions.put(#Admin, [
                #UserManagement, #PropertyManagement, #TokenManagement,
                #PaymentManagement, #ViewSensitiveData, #ViewPublicData
            ]);
            
            // PropertyOwner - Gestión de propiedades y tokens
            rolePermissions.put(#PropertyOwner, [
                #PropertyManagement, #TokenManagement, #ViewSensitiveData, #ViewPublicData
            ]);
            
            // Investor - Compra y visualización
            rolePermissions.put(#Investor, [
                #ViewPublicData, #ViewSensitiveData
            ]);
            
            // Viewer - Solo lectura
            rolePermissions.put(#Viewer, [
                #ViewPublicData
            ]);
            
            // Suspended - Sin permisos
            rolePermissions.put(#Suspended, []);
        };
        
        private func createOwnerAccount(ownerId: Types.UserId) {
            let ownerProfile: UserProfile = {
                id = ownerId;
                role = #Owner;
                permissions = getRolePermissions(#Owner);
                isActive = true;
                isVerified = true;
                createdAt = Time.now();
                lastLoginAt = null;
                email = null;
                name = ?"System Owner";
                country = null;
                kycStatus = #Approved;
                sessionToken = null;
                sessionExpiry = null;
            };
            users.put(ownerId, ownerProfile);
        };
        
        // ========================================
        // GESTIÓN DE USUARIOS
        // ========================================
        
        public func registerUser(
            userId: Types.UserId,
            email: ?Text,
            name: ?Text,
            country: ?Text
        ) : Result.Result<UserProfile, AuthError> {
            
            // Verificar si el usuario ya existe
            switch (users.get(userId)) {
                case (?_) { return #err(#SystemError("User already exists")) };
                case (null) {};
            };
            
            let newUser: UserProfile = {
                id = userId;
                role = #Investor; // Rol por defecto
                permissions = getRolePermissions(#Investor);
                isActive = true;
                isVerified = false;
                createdAt = Time.now();
                lastLoginAt = null;
                email = email;
                name = name;
                country = country;
                kycStatus = #NotStarted;
                sessionToken = null;
                sessionExpiry = null;
            };
            
            users.put(userId, newUser);
            #ok(newUser)
        };
        
        public func getUser(userId: Types.UserId) : Result.Result<UserProfile, AuthError> {
            switch (users.get(userId)) {
                case (?user) { #ok(user) };
                case (null) { #err(#UserNotFound) };
            }
        };
        
        public func updateUserRole(
            adminId: Types.UserId,
            targetUserId: Types.UserId,
            newRole: UserRole
        ) : Result.Result<UserProfile, AuthError> {
            
            // Verificar permisos del admin
            switch (hasPermission(adminId, #UserManagement)) {
                case (#err(error)) { return #err(error) };
                case (#ok(false)) { return #err(#NotAuthorized) };
                case (#ok(true)) {};
            };
            
            // Obtener usuario objetivo
            switch (users.get(targetUserId)) {
                case (null) { return #err(#UserNotFound) };
                case (?user) {
                    // No permitir cambiar el rol del owner
                    if (user.role == #Owner and adminId != targetUserId) {
                        return #err(#NotAuthorized);
                    };
                    
                    let updatedUser: UserProfile = {
                        user with 
                        role = newRole;
                        permissions = getRolePermissions(newRole);
                    };
                    
                    users.put(targetUserId, updatedUser);
                    #ok(updatedUser)
                };
            }
        };
        
        public func suspendUser(
            adminId: Types.UserId,
            targetUserId: Types.UserId,
            _reason: Text
        ) : Result.Result<(), AuthError> {
            
            switch (updateUserRole(adminId, targetUserId, #Suspended)) {
                case (#ok(_)) {
                    // Invalidar todas las sesiones del usuario
                    invalidateUserSessions(targetUserId);
                    #ok()
                };
                case (#err(error)) { #err(error) };
            }
        };
        
        public func updateKYCStatus(
            adminId: Types.UserId,
            targetUserId: Types.UserId,
            newStatus: KYCStatus
        ) : Result.Result<UserProfile, AuthError> {
            
            // Verificar permisos
            switch (hasPermission(adminId, #UserManagement)) {
                case (#err(error)) { return #err(error) };
                case (#ok(false)) { return #err(#NotAuthorized) };
                case (#ok(true)) {};
            };
            
            switch (users.get(targetUserId)) {
                case (null) { #err(#UserNotFound) };
                case (?user) {
                    let updatedUser: UserProfile = {
                        user with 
                        kycStatus = newStatus;
                        isVerified = (newStatus == #Approved);
                    };
                    
                    users.put(targetUserId, updatedUser);
                    #ok(updatedUser)
                };
            }
        };
        
        // ========================================
        // SISTEMA DE SESIONES
        // ========================================
        
        public func createSession(userId: Types.UserId) : Result.Result<SessionInfo, AuthError> {
            
            // Verificar que el usuario existe y está activo
            switch (users.get(userId)) {
                case (null) { return #err(#UserNotFound) };
                case (?user) {
                    if (not user.isActive) {
                        return #err(#UserSuspended);
                    };
                };
            };
            
            // Limpiar sesiones expiradas del usuario
            cleanupUserSessions(userId);
            
            // Verificar límite de sesiones
            let userSessions = getUserActiveSessions(userId);
            if (userSessions.size() >= MAX_SESSIONS_PER_USER) {
                // Eliminar la sesión más antigua
                removeOldestSession(userId);
            };
            
            // Crear nueva sesión
            let now = Time.now();
            let sessionToken = generateSessionToken(userId, now);
            let sessionInfo: SessionInfo = {
                userId = userId;
                token = sessionToken;
                createdAt = now;
                expiresAt = now + SESSION_DURATION;
                isActive = true;
                lastActivity = now;
            };
            
            sessions.put(sessionToken, sessionInfo);
            
            // Actualizar último login del usuario
            switch (users.get(userId)) {
                case (?user) {
                    let updatedUser: UserProfile = {
                        user with 
                        lastLoginAt = ?now;
                        sessionToken = ?sessionToken;
                        sessionExpiry = ?sessionInfo.expiresAt;
                    };
                    users.put(userId, updatedUser);
                };
                case (null) {};
            };
            
            #ok(sessionInfo)
        };
        
        public func validateSession(sessionToken: Text) : Result.Result<Types.UserId, AuthError> {
            switch (sessions.get(sessionToken)) {
                case (null) { #err(#NotAuthenticated) };
                case (?session) {
                    let now = Time.now();
                    
                    if (not session.isActive) {
                        return #err(#NotAuthenticated);
                    };
                    
                    if (now > session.expiresAt) {
                        // Sesión expirada
                        let expiredSession = { session with isActive = false };
                        sessions.put(sessionToken, expiredSession);
                        return #err(#SessionExpired);
                    };
                    
                    // Actualizar actividad de la sesión
                    let updatedSession = { session with lastActivity = now };
                    sessions.put(sessionToken, updatedSession);
                    
                    #ok(session.userId)
                };
            }
        };
        
        public func invalidateSession(sessionToken: Text) : Result.Result<(), AuthError> {
            switch (sessions.get(sessionToken)) {
                case (null) { #err(#NotAuthenticated) };
                case (?session) {
                    let invalidatedSession = { session with isActive = false };
                    sessions.put(sessionToken, invalidatedSession);
                    #ok()
                };
            }
        };
        
        public func invalidateUserSessions(userId: Types.UserId) {
            for ((token, session) in sessions.entries()) {
                if (Principal.equal(session.userId, userId)) {
                    let invalidatedSession = { session with isActive = false };
                    sessions.put(token, invalidatedSession);
                };
            };
        };
        
        // ========================================
        // SISTEMA DE AUTORIZACIÓN
        // ========================================
        
        public func hasPermission(userId: Types.UserId, permission: Permission) : Result.Result<Bool, AuthError> {
            switch (users.get(userId)) {
                case (null) { return #err(#UserNotFound) };
                case (?user) {
                    if (not user.isActive) {
                        return #err(#UserSuspended);
                    };
                    
                    if (user.role == #Suspended) {
                        return #err(#UserSuspended);
                    };
                    
                    // Verificar si tiene el permiso específico
                    for (userPermission in user.permissions.vals()) {
                        if (permissionEqual(userPermission, permission)) {
                            return #ok(true);
                        };
                    };
                    
                    #ok(false)
                };
            }
        };
        
        public func requirePermission(userId: Types.UserId, permission: Permission) : Result.Result<(), AuthError> {
            switch (hasPermission(userId, permission)) {
                case (#ok(true)) { #ok() };
                case (#ok(false)) { #err(#NotAuthorized) };
                case (#err(error)) { #err(error) };
            }
        };
        
        public func requireKYC(userId: Types.UserId) : Result.Result<(), AuthError> {
            switch (users.get(userId)) {
                case (null) { #err(#UserNotFound) };
                case (?user) {
                    switch (user.kycStatus) {
                        case (#Approved) { #ok() };
                        case (#NotStarted or #InProgress or #Rejected or #Expired) { #err(#KYCRequired) };
                    }
                };
            }
        };
        
        public func canAccessProperty(userId: Types.UserId, propertyOwnerId: Types.UserId) : Result.Result<Bool, AuthError> {
            switch (users.get(userId)) {
                case (null) { return #err(#UserNotFound) };
                case (?user) {
                    // Owner y Admin pueden acceder a todo
                    if (user.role == #Owner or user.role == #Admin) {
                        return #ok(true);
                    };
                    
                    // El dueño de la propiedad puede acceder
                    if (Principal.equal(userId, propertyOwnerId)) {
                        return #ok(true);
                    };
                    
                    // Otros usuarios solo pueden ver datos públicos
                    hasPermission(userId, #ViewPublicData)
                };
            }
        };
        
        // ========================================
        // FUNCIONES AUXILIARES
        // ========================================
        
        private func getRolePermissions(role: UserRole) : [Permission] {
            switch (rolePermissions.get(role)) {
                case (?permissions) { permissions };
                case (null) { [] };
            }
        };
        
        private func permissionEqual(a: Permission, b: Permission) : Bool {
            switch (a, b) {
                case (#SystemManagement, #SystemManagement) { true };
                case (#UserManagement, #UserManagement) { true };
                case (#PropertyManagement, #PropertyManagement) { true };
                case (#TokenManagement, #TokenManagement) { true };
                case (#PaymentManagement, #PaymentManagement) { true };
                case (#ViewSensitiveData, #ViewSensitiveData) { true };
                case (#ViewPublicData, #ViewPublicData) { true };
                case (#EmergencyActions, #EmergencyActions) { true };
                case (_, _) { false };
            }
        };
        
        private func generateSessionToken(userId: Types.UserId, timestamp: Int) : Text {
            let userText = Principal.toText(userId);
            let timeText = Int.toText(timestamp);
            userText # "-" # timeText # "-session"
        };
        
        private func getUserActiveSessions(userId: Types.UserId) : [SessionInfo] {
            let userSessions = Buffer.Buffer<SessionInfo>(0);
            let now = Time.now();
            
            for ((_, session) in sessions.entries()) {
                if (Principal.equal(session.userId, userId) and session.isActive and now <= session.expiresAt) {
                    userSessions.add(session);
                };
            };
            
            Buffer.toArray(userSessions)
        };
        
        private func removeOldestSession(userId: Types.UserId) {
            var oldestToken: ?Text = null;
            var oldestTime: Int = Time.now();
            
            for ((token, session) in sessions.entries()) {
                if (Principal.equal(session.userId, userId) and session.isActive) {
                    if (session.createdAt < oldestTime) {
                        oldestTime := session.createdAt;
                        oldestToken := ?token;
                    };
                };
            };
            
            switch (oldestToken) {
                case (?token) { ignore invalidateSession(token) };
                case (null) {};
            };
        };
        
        private func cleanupUserSessions(userId: Types.UserId) {
            let now = Time.now();
            for ((token, session) in sessions.entries()) {
                if (Principal.equal(session.userId, userId) and now > session.expiresAt) {
                    let expiredSession = { session with isActive = false };
                    sessions.put(token, expiredSession);
                };
            };
        };
        
        // ========================================
        // FUNCIONES PÚBLICAS DE CONSULTA
        // ========================================
        
        public func getAllUsers() : [UserProfile] {
            let usersList = Buffer.Buffer<UserProfile>(users.size());
            for ((_, user) in users.entries()) {
                usersList.add(user);
            };
            Buffer.toArray(usersList)
        };
        
        public func getActiveUsers() : [UserProfile] {
            let activeUsers = Buffer.Buffer<UserProfile>(0);
            for ((_, user) in users.entries()) {
                if (user.isActive and user.role != #Suspended) {
                    activeUsers.add(user);
                };
            };
            Buffer.toArray(activeUsers)
        };
        
        public func getUserStats() : {
            totalUsers: Nat;
            activeUsers: Nat;
            verifiedUsers: Nat;
            suspendedUsers: Nat;
            activeSessions: Nat;
        } {
            var totalUsers = 0;
            var activeUsers = 0;
            var verifiedUsers = 0;
            var suspendedUsers = 0;
            
            for ((_, user) in users.entries()) {
                totalUsers += 1;
                if (user.isActive and user.role != #Suspended) {
                    activeUsers += 1;
                };
                if (user.isVerified) {
                    verifiedUsers += 1;
                };
                if (user.role == #Suspended) {
                    suspendedUsers += 1;
                };
            };
            
            // Contar sesiones activas
            var activeSessions = 0;
            let now = Time.now();
            for ((_, session) in sessions.entries()) {
                if (session.isActive and now <= session.expiresAt) {
                    activeSessions += 1;
                };
            };
            
            {
                totalUsers = totalUsers;
                activeUsers = activeUsers;
                verifiedUsers = verifiedUsers;
                suspendedUsers = suspendedUsers;
                activeSessions = activeSessions;
            }
        };
        
        // ========================================
        // MANTENIMIENTO
        // ========================================
        
        public func cleanupExpiredSessions() : Nat {
            let now = Time.now();
            var cleanedCount = 0;
            
            let activeSessions = HashMap.HashMap<Text, SessionInfo>(sessions.size(), Text.equal, Text.hash);
            
            for ((token, session) in sessions.entries()) {
                if (session.isActive and now <= session.expiresAt) {
                    activeSessions.put(token, session);
                } else {
                    cleanedCount += 1;
                };
            };
            
            sessions := activeSessions;
            cleanedCount
        };
    }
}