// Main.mo - FUNCIONES FALTANTES COMPLETADAS Y CORREGIDAS
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Types "./Types";
import Utils "./Utils";
import PropertyManager "./PropertyManager";
import TokenManager "./TokenManager";
import TransactionManager "./TransactionManager";
import PaymentManager "./PaymentManager";
import Authentication "./Authentication";
import Validation "./Validation";

// ACTOR PRINCIPAL
actor RealEstateTokenization {
    
    // ========== VARIABLES DE ESTADO ==========
    private stable var contractOwner: Principal = Principal.fromText("2vxsx-fae"); // Cambiar por tu principal
    private stable var isInitialized: Bool = false;
    private stable var isPaused: Bool = false;
    private stable var nextEventId: Nat = 1;
    
    // HashMap para eventos del sistema
    private var systemEvents = HashMap.HashMap<Nat, Types.SystemEvent>(0, Nat.equal, Nat.hash);
    
    // ========== MANAGERS ==========
    private let propertyManager = PropertyManager.PropertyManager();
    private let tokenManager = TokenManager.TokenManager();
    private let transactionManager = TransactionManager.TransactionManager();
    private let paymentManager = PaymentManager.PaymentManager();
    private let authManager = Authentication.AuthenticationManager();
    private let validator = Validation.ValidationManager();
    
    // ========== INICIALIZACIÓN ==========
    public func initialize(owner: Principal): async Result.Result<(), Types.SystemError> {
        if (isInitialized) {
            return #err(#AlreadyInitialized);
        };
        
        contractOwner := owner;
        authManager.initialize(contractOwner);
        isInitialized := true;
        
        // Registrar evento de inicialización
        let _ = recordSystemEvent(#SystemConfigUpdated, "System initialized", ?owner);
        
        #ok(())
    };
    
    // ========== FUNCIONES FALTANTES COMPLETADAS ==========
    
    // 1. FUNCIÓN recordSystemEvent
    private func recordSystemEvent(
        eventType: Types.SystemEventType, 
        description: Text, 
        userId: ?Types.UserId
    ) : Nat {
        let eventId = nextEventId;
        let event: Types.SystemEvent = {
            id = eventId;
            eventType = eventType;
            description = description;
            userId = userId;
            timestamp = Time.now();
        };
        
        systemEvents.put(eventId, event);
        nextEventId += 1;
        eventId
    };
    
    // 2. FUNCIÓN getActiveUsersCount
    private func getActiveUsersCount() : Nat {
        let allUsers = Buffer.Buffer<Types.UserId>(0);
        
        // Obtener usuarios únicos de tokens de propiedad
        switch (tokenManager.getAllPropertyTokens()) {
            case (#ok(propertyTokens)) {
                for (token in propertyTokens.vals()) {
                    if (not containsUser(allUsers, token.owner)) {
                        allUsers.add(token.owner);
                    };
                };
            };
            case (#err(_)) {};
        };
        
        // Obtener usuarios únicos de transacciones recientes (últimos 30 días)
        let thirtyDaysAgo = Time.now() - 2592000000000000; // 30 días en nanosegundos
        switch (transactionManager.getTransactionsSince(thirtyDaysAgo)) {
            case (#ok(recentTransactions)) {
                for (transaction in recentTransactions.vals()) {
                    switch (transaction.fromUser) {
                        case (?user) {
                            if (not containsUser(allUsers, user)) {
                                allUsers.add(user);
                            };
                        };
                        case (null) {};
                    };
                    
                    switch (transaction.toUser) {
                        case (?user) {
                            if (not containsUser(allUsers, user)) {
                                allUsers.add(user);
                            };
                        };
                        case (null) {};
                    };
                };
            };
            case (#err(_)) {};
        };
        
        allUsers.size()
    };
    
    // Función auxiliar para verificar si un usuario ya está en el buffer
    private func containsUser(users: Buffer.Buffer<Types.UserId>, user: Types.UserId) : Bool {
        for (existingUser in users.vals()) {
            if (Principal.equal(existingUser, user)) {
                return true;
            };
        };
        false
    };
    
    // 3. FUNCIÓN verifyTransactionIntegrity (completa)
    public query func verifyTransactionIntegrity(transactionId: Types.TransactionId) : async Result.Result<Bool, Types.SystemError> {
        switch (transactionManager.getTransaction(transactionId)) {
            case (#ok(transaction)) {
                // Verificar que la transacción existe y es válida
                let isValid = verifyTransactionData(transaction);
                
                // Verificar que los tokens referenciados existen
                switch (transaction.tokenId) {
                    case (?tokenId) {
                        switch (tokenManager.getPropertyToken(tokenId)) {
                            case (#ok(_)) {
                                #ok(isValid)
                            };
                            case (#err(_)) {
                                #ok(false) // Token no existe, transacción inválida
                            };
                        }
                    };
                    case (null) {
                        #ok(isValid) // Transacciones sin token (como mint) son válidas si pasan otras verificaciones
                    };
                }
            };
            case (#err(error)) { #err(error) };
        }
    };
    
    // Función auxiliar para verificar datos de la transacción
    private func verifyTransactionData(transaction: Types.TransactionRecord) : Bool {
        // Verificar que el timestamp es válido (no futuro, no muy antiguo)
        let now = Time.now();
        let oneYearAgo = now - 31536000000000000; // 1 año en nanosegundos
        
        if (transaction.timestamp > now or transaction.timestamp < oneYearAgo) {
            return false;
        };
        
        // Verificar que el precio es positivo
        if (transaction.price <= 0) {
            return false;
        };
        
        // Verificar que las fees son válidas
        if (transaction.fees < 0) {
            return false;
        };
        
        // Verificar que el tipo de transacción es válido
        switch (transaction.transactionType) {
            case (#Mint or #Purchase or #Transfer or #UtilityGeneration) {
                true
            };
        }
    };
    
    // ========== FUNCIONES PÚBLICAS ADICIONALES ==========
    
    // 4. FUNCIÓN para obtener eventos del sistema (para administradores)
    public query func getSystemEvents(limit: ?Nat) : async Result.Result<[Types.SystemEvent], Types.SystemError> {
        let caller = Principal.fromActor(RealEstateTokenization);
        
        // Verificar permisos de administrador
        switch (authManager.requirePermission(caller, #SystemManagement)) {
            case (#err(_)) { return #err(#NotAuthorized) };
            case (#ok()) {};
        };
        
        let eventsList = Buffer.Buffer<Types.SystemEvent>(systemEvents.size());
        for ((_, event) in systemEvents.entries()) {
            eventsList.add(event);
        };
        
        // Ordenar por timestamp (más recientes primero)
        let sortedEvents = Array.sort(Buffer.toArray(eventsList), func(a: Types.SystemEvent, b: Types.SystemEvent) : {#less; #equal; #greater} {
            if (a.timestamp > b.timestamp) { #less }
            else if (a.timestamp < b.timestamp) { #greater }
            else { #equal }
        });
        
        // Aplicar límite si se especifica
        let finalEvents = switch (limit) {
            case (?lim) { 
                if (lim < sortedEvents.size()) {
                    Array.take(sortedEvents, lim)
                } else {
                    sortedEvents
                }
            };
            case (null) { sortedEvents };
        };
        
        #ok(finalEvents)
    };
    
    // 5. FUNCIÓN para obtener eventos de un usuario específico
    public query func getUserSystemEvents(userId: Types.UserId, limit: ?Nat) : async Result.Result<[Types.SystemEvent], Types.SystemError> {
        let caller = Principal.fromActor(RealEstateTokenization);
        
        // Solo el propio usuario o administradores pueden ver los eventos
        if (not Principal.equal(caller, userId)) {
            switch (authManager.requirePermission(caller, #SystemManagement)) {
                case (#err(_)) { return #err(#NotAuthorized) };
                case (#ok()) {};
            };
        };
        
        let userEvents = Buffer.Buffer<Types.SystemEvent>(0);
        for ((_, event) in systemEvents.entries()) {
            switch (event.userId) {
                case (?eventUserId) {
                    if (Principal.equal(eventUserId, userId)) {
                        userEvents.add(event);
                    };
                };
                case (null) {};
            };
        };
        
        // Ordenar por timestamp (más recientes primero)
        let sortedEvents = Array.sort(Buffer.toArray(userEvents), func(a: Types.SystemEvent, b: Types.SystemEvent) : {#less; #equal; #greater} {
            if (a.timestamp > b.timestamp) { #less }
            else if (a.timestamp < b.timestamp) { #greater }
            else { #equal }
        });
        
        // Aplicar límite si se especifica
        let finalEvents = switch (limit) {
            case (?lim) { 
                if (lim < sortedEvents.size()) {
                    Array.take(sortedEvents, lim)
                } else {
                    sortedEvents
                }
            };
            case (null) { sortedEvents };
        };
        
        #ok(finalEvents)
    };
    
    // 6. FUNCIÓN para limpiar eventos antiguos
    public func cleanupOldEvents(olderThanDays: Nat) : async Result.Result<Nat, Types.SystemError> {
        let caller = Principal.fromActor(RealEstateTokenization);
        
        // Solo administradores pueden limpiar eventos
        switch (authManager.requirePermission(caller, #SystemManagement)) {
            case (#err(_)) { return #err(#NotAuthorized) };
            case (#ok()) {};
        };
        
        let cutoffTime = Time.now() - (Int.fromNat(olderThanDays) * 86400000000000); // días a nanosegundos
        var deletedCount = 0;
        
        let keysToDelete = Buffer.Buffer<Nat>(0);
        for ((eventId, event) in systemEvents.entries()) {
            if (event.timestamp < cutoffTime) {
                keysToDelete.add(eventId);
            };
        };
        
        for (eventId in keysToDelete.vals()) {
            systemEvents.delete(eventId);
            deletedCount += 1;
        };
        
        let _ = recordSystemEvent(#MaintenancePerformed, "Cleaned up " # Nat.toText(deletedCount) # " old events", ?caller);
        
        #ok(deletedCount)
    };
    
    // 7. FUNCIÓN para obtener información del sistema
    public query func getSystemInfo() : async Types.SystemInfo {
        {
            isInitialized = isInitialized;
            isPaused = isPaused;
            contractOwner = contractOwner;
            totalEvents = systemEvents.size();
            activeUsers = getActiveUsersCount();
            systemUptime = Time.now(); // Simplificado, normalmente sería tiempo desde inicialización
        }
    };
    
    // 8. FUNCIÓN de verificación de salud del sistema
    public query func healthCheck() : async Types.HealthStatus {
        let now = Time.now();
        let managerStatus = {
            propertyManager = true; // Simplificado, normalmente verificarías el estado real
            tokenManager = true;
            transactionManager = true;
            paymentManager = true;
            authManager = true;
        };
        
        {
            timestamp = now;
            isHealthy = not isPaused and isInitialized;
            managers = managerStatus;
            activeConnections = getActiveUsersCount();
        }
    };
    
    // 9. FUNCIÓN para obtener configuración del sistema
    public query func getSystemConfiguration() : async Result.Result<Types.SystemConfiguration, Types.SystemError> {
        let caller = Principal.fromActor(RealEstateTokenization);
        
        // Solo administradores pueden ver la configuración completa
        switch (authManager.requirePermission(caller, #SystemManagement)) {
            case (#err(_)) { return #err(#NotAuthorized) };
            case (#ok()) {};
        };
        
        #ok({
            contractOwner = contractOwner;
            isInitialized = isInitialized;
            isPaused = isPaused;
            maxEventsStored = 10000; // Configuración de ejemplo
            eventRetentionDays = 365;
            maintenanceMode = isPaused;
        })
    };
    
    // 10. FUNCIONES DE EMERGENCIA
    public func emergencyPause() : async Result.Result<(), Types.SystemError> {
        let caller = Principal.fromActor(RealEstateTokenization);
        
        // Solo el owner puede pausar en emergencia
        if (not Principal.equal(caller, contractOwner)) {
            return #err(#NotAuthorized);
        };
        
        isPaused := true;
        let _ = recordSystemEvent(#MaintenancePerformed, "System paused for emergency", ?caller);
        
        #ok(())
    };
    
    public func emergencyResume() : async Result.Result<(), Types.SystemError> {
        let caller = Principal.fromActor(RealEstateTokenization);
        
        // Solo el owner puede reanudar
        if (not Principal.equal(caller, contractOwner)) {
            return #err(#NotAuthorized);
        };
        
        isPaused := false;
        let _ = recordSystemEvent(#MaintenancePerformed, "System resumed from emergency pause", ?caller);
        
        #ok(())
    };
    
    // ========== FUNCIÓN DE EJEMPLO PARA CREAR PROPIEDAD CON VALIDACIÓN ==========
    public func createProperty(data: Types.PropertyData): async Result.Result<Types.PropertyId, Text> {
        let caller = Principal.fromActor(RealEstateTokenization);
        
        // Verificar que el sistema no esté pausado
        if (isPaused) {
            return #err("System is currently paused");
        };
        
        // Verificar permisos
        switch (authManager.requirePermission(caller, #PropertyManagement)) {
            case (#err(error)) { 
                return #err("Not authorized to create properties"); 
            };
            case (#ok()) {};
        };
        
        // Validar datos de la propiedad
        switch (validator.validatePropertyData(data)) {
            case (#err(error)) { 
                return #err(validator.formatError(error)); 
            };
            case (#ok(validData)) {
                // Crear la propiedad usando el PropertyManager
                switch (propertyManager.createProperty(validData, caller)) {
                    case (#ok(propertyId)) {
                        let _ = recordSystemEvent(#PropertyCreated, "Property created: " # Nat.toText(propertyId), ?caller);
                        #ok(propertyId)
                    };
                    case (#err(error)) {
                        #err("Failed to create property: " # debug_show(error))
                    };
                };
            };
        };
    };
    
    // ========== FUNCIONES DE ESTADÍSTICAS MEJORADAS ==========
    public query func getSystemStats() : async Types.SystemStats {
        let totalProperties = propertyManager.getTotalProperties();
        let totalTokens = tokenManager.getTotalTokens();
        let totalTransactions = transactionManager.getTotalTransactions();
        let activeUsers = getActiveUsersCount();
        
        {
            totalProperties = totalProperties;
            totalTokens = totalTokens;
            totalTransactions = totalTransactions;
            activeUsers = activeUsers;
            totalValueLocked = calculateTotalValueLocked();
            systemUptime = Time.now(); // Simplificado
        }
    };
    
    // Función auxiliar para calcular el valor total bloqueado
    private func calculateTotalValueLocked() : Float {
        switch (propertyManager.getAllProperties()) {
            case (#ok(properties)) {
                var total : Float = 0.0;
                for (property in properties.vals()) {
                    total += property.totalValue;
                };
                total
            };
            case (#err(_)) { 0.0 };
        }
    };
    
    // ========== FUNCIONES DE UPGRADE ==========
    system func preupgrade() {
        // Código para mantener el estado durante upgrades
    };
    
    system func postupgrade() {
        // Código para restaurar el estado después de upgrades
    };
}