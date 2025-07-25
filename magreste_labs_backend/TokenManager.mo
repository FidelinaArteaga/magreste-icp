// TokenManager.mo
// Gestión de tokens de propiedad y utilidad

import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";  // AGREGADO: Import para funciones hash
import Types "./Types";
import Utils "./Utils";

module {
    
    public class TokenManager() {
        
        // ========== ESTADO PRIVADO ==========
        private var propertyTokens = HashMap.HashMap<Types.TokenId, Types.PropertyToken>(100, Nat.equal, Hash.hash);
        private var utilityTokens = HashMap.HashMap<Types.TokenId, Types.UtilityToken>(50, Nat.equal, Hash.hash);
        private var userPropertyTokens = HashMap.HashMap<Types.UserId, [Types.TokenId]>(50, Principal.equal, Principal.hash);
        private var userUtilityTokens = HashMap.HashMap<Types.UserId, [Types.TokenId]>(50, Principal.equal, Principal.hash);
        private var propertyTokensByProperty = HashMap.HashMap<Types.PropertyId, [Types.TokenId]>(20, Nat.equal, Hash.hash);
        private var nextTokenId: Types.TokenId = 1;
        
        // Configuración del sistema
        private let _TOKEN_PRICE_USD: Float = 100.0; // $100 por token (no usado actualmente)
        private let TRANSFER_LOCK_PERIOD: Int = 63072000000000000; // 2 años en nanosegundos
        private let UTILITY_TOKEN_VALIDITY: Int = 315360000000000000; // 10 años en nanosegundos
        private let UTILITY_TOKEN_THRESHOLD: Float = 0.75; // 75% de tokens necesarios
        
        // ========== GESTIÓN DE TOKENS DE PROPIEDAD ==========
        
        // Crear (mint) tokens de propiedad
        public func mintPropertyTokens(
            propertyId: Types.PropertyId,
            quantity: Nat,
            pricePerToken: Float,
            owner: Types.UserId
        ) : Result.Result<[Types.TokenId], Types.SystemError> {
            
            if (quantity == 0) {
                return #err(#InvalidQuantity);
            };
            
            let tokenIds = Buffer.Buffer<Types.TokenId>(quantity);
            let now = Time.now();
            
            // Crear tokens - CORREGIDO: usar Iter.range en lugar de Array.range
            for (i in Iter.range(0, quantity - 1)) {
                let token: Types.PropertyToken = {
                    id = nextTokenId;
                    propertyId = propertyId;
                    owner = owner;
                    price = pricePerToken;
                    createdAt = now;
                    canTransfer = false;
                    transferEnabledAt = now + TRANSFER_LOCK_PERIOD;
                    metadata = null;
                };
                
                propertyTokens.put(nextTokenId, token);
                tokenIds.add(nextTokenId);
                nextTokenId += 1;
            };
            
            // Actualizar índices
            updateUserPropertyTokens(owner);
            updatePropertyTokensByProperty(propertyId);
            
            #ok(Buffer.toArray(tokenIds))
        };
        
        // Transferir token de propiedad
        public func transferPropertyToken(
            tokenId: Types.TokenId,
            from: Types.UserId,
            to: Types.UserId
        ) : Result.Result<(), Types.SystemError> {
            
            switch (propertyTokens.get(tokenId)) {
                case (?token) {
                    // Verificar ownership
                    if (not Principal.equal(token.owner, from)) {
                        return #err(#NotAuthorized);
                    };
                    
                    // Verificar si puede transferir
                    if (not canTransferToken(token)) {
                        return #err(#TransferLocked);
                    };
                    
                    // Actualizar token
                    let updatedToken: Types.PropertyToken = {
                        token with 
                        owner = to;
                        canTransfer = true;
                    };
                    
                    propertyTokens.put(tokenId, updatedToken);
                    
                    // Actualizar índices
                    updateUserPropertyTokens(from);
                    updateUserPropertyTokens(to);
                    
                    #ok()
                };
                case null { #err(#TokenNotFound) };
            }
        };
        
        // Obtener token de propiedad
        public func getPropertyToken(tokenId: Types.TokenId) : Result.Result<Types.PropertyToken, Types.SystemError> {
            switch (propertyTokens.get(tokenId)) {
                case (?token) { #ok(token) };
                case null { #err(#TokenNotFound) };
            }
        };
        
        // Obtener todos los tokens de propiedad
        public func getAllPropertyTokens() : Result.Result<[Types.PropertyToken], Types.SystemError> {
            let allTokens = Buffer.Buffer<Types.PropertyToken>(propertyTokens.size());
            
            for ((_, token) in propertyTokens.entries()) {
                allTokens.add(token);
            };
            
            #ok(Buffer.toArray(allTokens))
        };
        
        // Obtener total de tokens
        public func getTotalTokens() : Nat {
            propertyTokens.size() + utilityTokens.size()
        };
        
        // Obtener tokens de propiedad por usuario
        public func getUserPropertyTokens(user: Types.UserId) : Result.Result<[Types.PropertyToken], Types.SystemError> {
            let userTokens = Buffer.Buffer<Types.PropertyToken>(0);
            
            for ((tokenId, token) in propertyTokens.entries()) {
                if (Principal.equal(token.owner, user)) {
                    userTokens.add(token);
                };
            };
            
            #ok(Buffer.toArray(userTokens))
        };
        
        // Obtener tokens de propiedad por usuario y propiedad específica
        public func getUserPropertyTokensByProperty(
            user: Types.UserId, 
            propertyId: Types.PropertyId
        ) : Result.Result<[Types.PropertyToken], Types.SystemError> {
            let userTokens = Buffer.Buffer<Types.PropertyToken>(0);
            
            for ((tokenId, token) in propertyTokens.entries()) {
                if (Principal.equal(token.owner, user) and token.propertyId == propertyId) {
                    userTokens.add(token);
                };
            };
            
            #ok(Buffer.toArray(userTokens))
        };
        
        // Obtener tokens disponibles para venta de una propiedad
        public func getAvailableTokensForSale(
            propertyId: Types.PropertyId,
            quantity: Nat
        ) : Result.Result<[Types.TokenId], Types.SystemError> {
            let availableTokens = Buffer.Buffer<Types.TokenId>(0);
            
            for ((tokenId, token) in propertyTokens.entries()) {
                if (token.propertyId == propertyId and availableTokens.size() < quantity) {
                    // Token está disponible si no tiene owner o es del sistema
                    availableTokens.add(tokenId);
                };
            };
            
            if (availableTokens.size() < quantity) {
                return #err(#TokensUnavailable);
            };
            
            #ok(Buffer.toArray(availableTokens))
        };
        
        // Verificar estado de transferencia de token
        public func getTransferStatus(tokenId: Types.TokenId) : Result.Result<{
            canTransfer: Bool;
            timeLeft: Int;
            transferEnabledAt: Int;
        }, Types.SystemError> {
            switch (propertyTokens.get(tokenId)) {
                case (?token) {
                    let now = Time.now();
                    let canTransfer = canTransferToken(token);
                    let timeLeft = if (token.transferEnabledAt > now) {
                        token.transferEnabledAt - now
                    } else { 0 };
                    
                    #ok({
                        canTransfer = canTransfer;
                        timeLeft = timeLeft;
                        transferEnabledAt = token.transferEnabledAt;
                    })
                };
                case null { #err(#TokenNotFound) };
            }
        };
        
        // ========== GESTIÓN DE TOKENS DE UTILIDAD ==========
        
        // Generar token de utilidad
        public func generateUtilityToken(
            user: Types.UserId,
            propertyId: Types.PropertyId,
            userTokenCount: Nat,
            totalTokens: Nat
        ) : Result.Result<Types.TokenId, Types.SystemError> {
            
            // Verificar si califica
            if (not qualifiesForUtilityToken(userTokenCount, totalTokens)) {
                return #err(#SystemError("User doesn't qualify for utility token"));
            };
            
            // Verificar si ya tiene token de utilidad para esta propiedad
            if (hasUtilityTokenForProperty(user, propertyId)) {
                return #err(#UtilityTokenExists);
            };
            
            let now = Time.now();
            let utilityToken: Types.UtilityToken = {
                id = nextTokenId;
                propertyId = propertyId;
                owner = user;
                createdAt = now;
                expiresAt = now + UTILITY_TOKEN_VALIDITY;
                isValid = true;
                utilizationCount = 0;
                maxUtilizations = 365; // Una vez por día durante un año
            };
            
            utilityTokens.put(nextTokenId, utilityToken);
            let tokenId = nextTokenId;
            nextTokenId += 1;
            
            // Actualizar índices
            updateUserUtilityTokens(user);
            
            #ok(tokenId)
        };
        
        // Obtener token de utilidad
        public func getUtilityToken(tokenId: Types.TokenId) : Result.Result<Types.UtilityToken, Types.SystemError> {
            switch (utilityTokens.get(tokenId)) {
                case (?token) { #ok(token) };
                case null { #err(#TokenNotFound) };
            }
        };
        
        // Obtener tokens de utilidad de usuario
        public func getUserUtilityTokens(user: Types.UserId) : Result.Result<[Types.UtilityToken], Types.SystemError> {
            let userTokens = Buffer.Buffer<Types.UtilityToken>(0);
            
            for ((tokenId, token) in utilityTokens.entries()) {
                if (Principal.equal(token.owner, user) and isUtilityTokenValid(token)) {
                    userTokens.add(token);
                };
            };
            
            #ok(Buffer.toArray(userTokens))
        };
        
        // Verificar validez de token de utilidad
        public func checkUtilityTokenValidity(tokenId: Types.TokenId) : Result.Result<Bool, Types.SystemError> {
            switch (utilityTokens.get(tokenId)) {
                case (?token) {
                    let isValid = isUtilityTokenValid(token);
                    
                    // Si el token expiró, marcarlo como inválido
                    if (not isValid and token.isValid) {
                        let updatedToken: Types.UtilityToken = {
                            token with isValid = false;
                        };
                        utilityTokens.put(tokenId, updatedToken);
                    };
                    
                    #ok(isValid)
                };
                case null { #err(#TokenNotFound) };
            }
        };
        
        // Usar token de utilidad (incrementar contador)
        public func useUtilityToken(tokenId: Types.TokenId, user: Types.UserId) : Result.Result<(), Types.SystemError> {
            switch (utilityTokens.get(tokenId)) {
                case (?token) {
                    // Verificar ownership
                    if (not Principal.equal(token.owner, user)) {
                        return #err(#NotAuthorized);
                    };
                    
                    // Verificar validez
                    let isValid = isUtilityTokenValid(token);
                    if (not isValid) {
                        return #err(#UtilityTokenExpired);
                    };
                    
                    // Verificar si ha excedido el límite de usos
                    if (token.utilizationCount >= token.maxUtilizations) {
                        return #err(#SystemError("Utility token usage limit exceeded"));
                    };
                    
                    // Incrementar contador de uso
                    let updatedToken: Types.UtilityToken = {
                        token with utilizationCount = token.utilizationCount + 1;
                    };
                    
                    utilityTokens.put(tokenId, updatedToken);
                    #ok()
                };
                case null { #err(#TokenNotFound) };
            }
        };
        
        // Limpiar tokens de utilidad expirados
        public func cleanupExpiredUtilityTokens() : Nat {
            var cleanedCount = 0;
            let now = Time.now();
            
            for ((tokenId, token) in utilityTokens.entries()) {
                if (now > token.expiresAt and token.isValid) {
                    let updatedToken: Types.UtilityToken = {
                        token with isValid = false;
                    };
                    utilityTokens.put(tokenId, updatedToken);
                    cleanedCount += 1;
                };
            };
            
            cleanedCount
        };
        
        // ========== FUNCIONES DE ESTADÍSTICAS ==========
        
        // Obtener estadísticas de tokens por propiedad
        public func getPropertyTokenStats(propertyId: Types.PropertyId) : Result.Result<{
            totalTokens: Nat;
            uniqueOwners: Nat;
            transferableTokens: Nat;
            lockedTokens: Nat;
        }, Types.SystemError> {
            let owners = HashMap.HashMap<Types.UserId, Nat>(10, Principal.equal, Principal.hash);
            var totalTokens = 0;
            var transferableTokens = 0;
            var lockedTokens = 0;
            
            for ((tokenId, token) in propertyTokens.entries()) {
                if (token.propertyId == propertyId) {
                    totalTokens += 1;
                    
                    // Contar owners únicos
                    switch (owners.get(token.owner)) {
                        case (?count) { owners.put(token.owner, count + 1) };
                        case null { owners.put(token.owner, 1) };
                    };
                    
                    // Contar tokens transferibles vs bloqueados
                    if (canTransferToken(token)) {
                        transferableTokens += 1;
                    } else {
                        lockedTokens += 1;
                    };
                };
            };
            
            #ok({
                totalTokens = totalTokens;
                uniqueOwners = owners.size();
                transferableTokens = transferableTokens;
                lockedTokens = lockedTokens;
            })
        };
        
        // Obtener estadísticas generales de tokens
        public func getSystemTokenStats() : {
            totalPropertyTokens: Nat;
            totalUtilityTokens: Nat;
            activeUtilityTokens: Nat;
            expiredUtilityTokens: Nat;
        } {
            var activeUtilityTokens = 0;
            var expiredUtilityTokens = 0;
            
            for ((tokenId, token) in utilityTokens.entries()) {
                if (isUtilityTokenValid(token)) {
                    activeUtilityTokens += 1;
                } else {
                    expiredUtilityTokens += 1;
                };
            };
            
            {
                totalPropertyTokens = propertyTokens.size();
                totalUtilityTokens = utilityTokens.size();
                activeUtilityTokens = activeUtilityTokens;
                expiredUtilityTokens = expiredUtilityTokens;
            }
        };
        
        // Obtener conteo de tokens de usuario por propiedad
        public func getUserPropertyTokenCount(user: Types.UserId, propertyId: Types.PropertyId) : Nat {
            var count = 0;
            for ((tokenId, token) in propertyTokens.entries()) {
                if (Principal.equal(token.owner, user) and token.propertyId == propertyId) {
                    count += 1;
                };
            };
            count
        };
        
        // Verificar si usuario tiene suficientes tokens para utility token
        public func checkUtilityTokenEligibility(
            user: Types.UserId, 
            propertyId: Types.PropertyId, 
            totalTokens: Nat
        ) : Bool {
            let userTokenCount = getUserPropertyTokenCount(user, propertyId);
            qualifiesForUtilityToken(userTokenCount, totalTokens) and 
            not hasUtilityTokenForProperty(user, propertyId)
        };
        
        // ========== FUNCIONES AUXILIARES PRIVADAS ==========
        
        // Verificar si un token puede ser transferido
        private func canTransferToken(token: Types.PropertyToken) : Bool {
            let now = Time.now();
            now >= token.transferEnabledAt
        };
        
        // Verificar si un token de utilidad es válido
        private func isUtilityTokenValid(token: Types.UtilityToken) : Bool {
            let now = Time.now();
            token.isValid and now <= token.expiresAt
        };
        
        // Verificar si califica para token de utilidad
        private func qualifiesForUtilityToken(userTokenCount: Nat, totalTokens: Nat) : Bool {
            if (totalTokens == 0) return false;
            let percentage = Float.fromInt(userTokenCount) / Float.fromInt(totalTokens);
            percentage >= UTILITY_TOKEN_THRESHOLD
        };
        
        // Actualizar índice de tokens de propiedad por usuario
        private func updateUserPropertyTokens(user: Types.UserId) {
            let userTokens = Buffer.Buffer<Types.TokenId>(0);
            
            for ((tokenId, token) in propertyTokens.entries()) {
                if (Principal.equal(token.owner, user)) {
                    userTokens.add(tokenId);
                };
            };
            
            userPropertyTokens.put(user, Buffer.toArray(userTokens));
        };
        
        // Actualizar índice de tokens de utilidad por usuario
        private func updateUserUtilityTokens(user: Types.UserId) {
            let userTokens = Buffer.Buffer<Types.TokenId>(0);
            
            for ((tokenId, token) in utilityTokens.entries()) {
                if (Principal.equal(token.owner, user) and isUtilityTokenValid(token)) {
                    userTokens.add(tokenId);
                };
            };
            
            userUtilityTokens.put(user, Buffer.toArray(userTokens));
        };
        
        // Actualizar índice de tokens por propiedad
        private func updatePropertyTokensByProperty(propertyId: Types.PropertyId) {
            let propertyTokenIds = Buffer.Buffer<Types.TokenId>(0);
            
            for ((tokenId, token) in propertyTokens.entries()) {
                if (token.propertyId == propertyId) {
                    propertyTokenIds.add(tokenId);
                };
            };
            
            propertyTokensByProperty.put(propertyId, Buffer.toArray(propertyTokenIds));
        };
        
        // Verificar si usuario tiene token de utilidad para una propiedad
        private func hasUtilityTokenForProperty(user: Types.UserId, propertyId: Types.PropertyId) : Bool {
            for ((tokenId, token) in utilityTokens.entries()) {
                if (Principal.equal(token.owner, user) and 
                    token.propertyId == propertyId and 
                    isUtilityTokenValid(token)) {
                    return true;
                };
            };
            false
        };
        
        // ========== FUNCIONES DE BÚSQUEDA Y FILTRADO ==========
        
        // Buscar tokens por propietario con paginación
        public func searchTokensByOwner(
            owner: Types.UserId,
            page: Nat,
            pageSize: Nat
        ) : Result.Result<Types.PaginatedResult<Types.PropertyToken>, Types.SystemError> {
            let allUserTokens = Buffer.Buffer<Types.PropertyToken>(0);
            
            for ((_, token) in propertyTokens.entries()) {
                if (Principal.equal(token.owner, owner)) {
                    allUserTokens.add(token);
                };
            };
            
            let total = allUserTokens.size();
            let startIndex = page * pageSize;
            let endIndex = Nat.min(startIndex + pageSize, total);
            
            if (startIndex >= total) {
                return #ok({
                    data = [];
                    total = total;
                    page = page;
                    pageSize = pageSize;
                    hasNext = false;
                    hasPrev = page > 0;
                });
            };
            
            let pageData = Buffer.Buffer<Types.PropertyToken>(pageSize);
            let allTokensArray = Buffer.toArray(allUserTokens);
            
            // CORREGIDO: usar Iter.range en lugar de Array.range
            for (i in Iter.range(startIndex, endIndex - 1)) {
                pageData.add(allTokensArray[i]);
            };
            
            #ok({
                data = Buffer.toArray(pageData);
                total = total;
                page = page;
                pageSize = pageSize;
                hasNext = endIndex < total;
                hasPrev = page > 0;
            })
        };
        
        // Obtener tokens por propiedad con filtros
        public func getTokensByProperty(
            propertyId: Types.PropertyId,
            transferableOnly: ?Bool
        ) : Result.Result<[Types.PropertyToken], Types.SystemError> {
            let filteredTokens = Buffer.Buffer<Types.PropertyToken>(0);
            
            for ((_, token) in propertyTokens.entries()) {
                if (token.propertyId == propertyId) {
                    switch (transferableOnly) {
                        case (?true) {
                            if (canTransferToken(token)) {
                                filteredTokens.add(token);
                            };
                        };
                        case (?false) {
                            if (not canTransferToken(token)) {
                                filteredTokens.add(token);
                            };
                        };
                        case (null) {
                            filteredTokens.add(token);
                        };
                    };
                };
            };
            
            #ok(Buffer.toArray(filteredTokens))
        };
    }
}