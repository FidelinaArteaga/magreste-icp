// PropertyManager.mo
// Gestión de propiedades inmobiliarias - CORREGIDO

import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Types "./Types";

module {
    
    public class PropertyManager() {
        
        // Tipos locales para mejor organización
        private type PropertyId = Types.PropertyId;
        private type UserId = Types.UserId;
        private type Property = Types.Property;
        private type SystemError = Types.SystemError;
        private type PropertyData = Types.PropertyData;
        private type CreatePropertyRequest = Types.CreatePropertyRequest;
        private type CreatePropertyResponse = Types.CreatePropertyResponse;
        
        // ARREGLO: Función hash personalizada para reemplazar deprecated hash
        private func natHash(n: Nat): Hash.Hash {
            Text.hash(Nat.toText(n))
        };
        
        // Estado privado con hash corregido
        private var nextPropertyId: PropertyId = 1;
        private var properties = HashMap.HashMap<PropertyId, Property>(10, Nat.equal, natHash);
        private var propertyOwners = HashMap.HashMap<UserId, [PropertyId]>(10, Principal.equal, Principal.hash);
        
        // Crear nueva propiedad - MÉTODO CORREGIDO
        public func createProperty(request: CreatePropertyRequest, owner: UserId) : CreatePropertyResponse {
            
            // Validar datos básicos
            if (Text.size(request.name) == 0) {
                return #err(#InvalidInput("Property name cannot be empty"));
            };
            
            if (Text.size(request.description) == 0) {
                return #err(#InvalidInput("Property description cannot be empty"));
            };
            
            if (request.totalTokens == 0) {
                return #err(#InvalidInput("Total tokens must be greater than 0"));
            };
            
            if (request.totalValue <= 0.0) {
                return #err(#InvalidInput("Total value must be greater than 0"));
            };
            
            if (request.pricePerToken <= 0.0) {
                return #err(#InvalidInput("Price per token must be greater than 0"));
            };
            
            let now = Time.now();
            let property: Property = {
                id = nextPropertyId;
                name = request.name;
                description = request.description;
                location = request.location;
                totalValue = request.totalValue;
                pricePerToken = request.pricePerToken;
                totalTokens = request.totalTokens;
                tokensIssued = 0;
                tokensSold = 0;
                expectedAnnualReturn = request.expectedAnnualReturn;
                propertyType = request.propertyType;
                squareMeters = request.squareMeters;
                imageUrls = request.imageUrls;
                isActive = true;
                createdAt = now;
                owner = owner;
            };
            
            properties.put(nextPropertyId, property);
            
            // Actualizar propiedades del owner
            updateOwnerProperties(owner, nextPropertyId);
            
            let propertyId = nextPropertyId;
            nextPropertyId += 1;
            
            #ok(property)
        };
        
        // Método de creación alternativo para compatibilidad
        public func createPropertyLegacy(
            name: Text,
            description: Text,
            location: Text,
            totalTokens: Nat,
            owner: UserId,
            imageUrl: ?Text,
            propertyType: Text,
            squareMeters: ?Nat,
            _estimatedValue: ?Nat // ARREGLO: Renombrado para evitar warning de variable no usada (línea 47)
        ) : Result.Result<PropertyId, SystemError> {
            
            // Validar datos básicos
            if (Text.size(name) == 0) {
                return #err(#InvalidInput("Property name cannot be empty"));
            };
            
            if (Text.size(description) == 0) {
                return #err(#InvalidInput("Property description cannot be empty"));
            };
            
            if (totalTokens == 0) {
                return #err(#InvalidInput("Total tokens must be greater than 0"));
            };
            
            let now = Time.now();
            let defaultLocation: Types.Location = {
                address = location;
                city = "";
                state = "";
                country = "";
                zipCode = "";
                coordinates = { lat = 0.0; lng = 0.0 };
            };
            
            let parsedPropertyType = switch (propertyType) {
                case ("residential") #Residential;
                case ("commercial") #Commercial;
                case ("industrial") #Industrial;
                case ("mixed") #Mixed;
                case (_) #Residential;
            };
            
            let property: Property = {
                id = nextPropertyId;
                name = name;
                description = description;
                location = defaultLocation;
                totalTokens = totalTokens;
                pricePerToken = 100.0; // Default price
                tokensIssued = 0;
                tokensSold = 0;
                isActive = true;
                createdAt = now;
                owner = owner;
                imageUrls = switch (imageUrl) {
                    case (?url) [url];
                    case null [];
                };
                propertyType = parsedPropertyType;
                squareMeters = squareMeters;
                totalValue = Float.fromInt(totalTokens) * 100.0;
                expectedAnnualReturn = 8.0; // Default 8%
            };
            
            properties.put(nextPropertyId, property);
            
            // Actualizar propiedades del owner
            updateOwnerProperties(owner, nextPropertyId);
            
            let propertyId = nextPropertyId;
            nextPropertyId += 1;
            
            #ok(propertyId)
        };
        
        // Obtener propiedad por ID
        public func getProperty(propertyId: PropertyId) : Result.Result<Property, SystemError> {
            switch (properties.get(propertyId)) {
                case (?property) { #ok(property) };
                case null { #err(#PropertyNotFound) };
            }
        };
        
        // Obtener propiedad por ID (método simple)
        public func getPropertyById(propertyId: PropertyId) : ?Property {
            properties.get(propertyId)
        };
        
        // Obtener todas las propiedades
        public func getAllProperties() : [Property] {
            let propertiesArray = Buffer.Buffer<Property>(0);
            for ((_, property) in properties.entries()) {
                propertiesArray.add(property);
            };
            Buffer.toArray(propertiesArray)
        };
        
        // Obtener propiedades activas
        public func getActiveProperties() : [Property] {
            let activeProperties = Buffer.Buffer<Property>(0);
            for ((_, property) in properties.entries()) {
                if (property.isActive and property.totalTokens > property.tokensSold) {
                    activeProperties.add(property);
                };
            };
            Buffer.toArray(activeProperties)
        };
        
        // Obtener propiedades por owner
        public func getPropertiesByOwner(owner: UserId) : [Property] {
            switch (propertyOwners.get(owner)) {
                case (?propertyIds) {
                    let ownerProperties = Buffer.Buffer<Property>(propertyIds.size());
                    for (id in propertyIds.vals()) {
                        switch (properties.get(id)) {
                            case (?property) ownerProperties.add(property);
                            case null { /* skip missing properties */ };
                        };
                    };
                    Buffer.toArray(ownerProperties)
                };
                case null { [] };
            }
        };
        
        // Verificar disponibilidad de propiedad - MÉTODO PARA RESOLVER ERROR LÍNEA 182
        public func getPropertyAvailability(propertyId: PropertyId) : (PropertyId, ?Bool) {
            switch (properties.get(propertyId)) {
                case (?property) {
                    let isAvailable = property.isActive and property.totalTokens > property.tokensSold;
                    (propertyId, ?isAvailable)
                };
                case null { (propertyId, null) };
            }
        };
        
        // Actualizar propiedad
        public func updateProperty(
            propertyId: PropertyId,
            caller: UserId,
            updates: {
                name: ?Text;
                description: ?Text;
                pricePerToken: ?Float;
                isActive: ?Bool;
                imageUrls: ?[Text];
                expectedAnnualReturn: ?Float;
            }
        ) : Result.Result<(), SystemError> {
            switch (properties.get(propertyId)) {
                case (?property) {
                    // Verificar que el caller es el owner
                    if (property.owner != caller) {
                        return #err(#NotAuthorized);
                    };
                    
                    let updatedProperty: Property = {
                        property with
                        name = switch (updates.name) { case (?n) n; case null property.name };
                        description = switch (updates.description) { case (?d) d; case null property.description };
                        pricePerToken = switch (updates.pricePerToken) { case (?p) p; case null property.pricePerToken };
                        isActive = switch (updates.isActive) { case (?a) a; case null property.isActive };
                        imageUrls = switch (updates.imageUrls) { case (?i) i; case null property.imageUrls };
                        expectedAnnualReturn = switch (updates.expectedAnnualReturn) { case (?r) r; case null property.expectedAnnualReturn };
                    };
                    
                    properties.put(propertyId, updatedProperty);
                    #ok()
                };
                case null { #err(#PropertyNotFound) };
            }
        };
        
        // Actualizar tokens emitidos
        public func updateTokensIssued(propertyId: PropertyId, tokensIssued: Nat) : Result.Result<(), SystemError> {
            switch (properties.get(propertyId)) {
                case (?property) {
                    if (tokensIssued > property.totalTokens) {
                        return #err(#InvalidInput("Tokens issued cannot exceed total tokens"));
                    };
                    
                    let updatedProperty: Property = {
                        property with tokensIssued = tokensIssued
                    };
                    
                    properties.put(propertyId, updatedProperty);
                    #ok()
                };
                case null { #err(#PropertyNotFound) };
            }
        };
        
        // Actualizar tokens vendidos
        public func updateTokensSold(propertyId: PropertyId, tokensSold: Nat) : Result.Result<(), SystemError> {
            switch (properties.get(propertyId)) {
                case (?property) {
                    if (tokensSold > property.totalTokens) {
                        return #err(#InvalidInput("Tokens sold cannot exceed total tokens"));
                    };
                    
                    let updatedProperty: Property = {
                        property with tokensSold = tokensSold
                    };
                    
                    properties.put(propertyId, updatedProperty);
                    #ok()
                };
                case null { #err(#PropertyNotFound) };
            }
        };
        
        // Reducir tokens disponibles (cuando se compran)
        public func reduceAvailableTokens(propertyId: PropertyId, quantity: Nat) : Result.Result<(), SystemError> {
            switch (properties.get(propertyId)) {
                case (?property) {
                    let newTokensSold = property.tokensSold + quantity;
                    if (newTokensSold > property.totalTokens) {
                        return #err(#InsufficientTokens);
                    };
                    
                    let updatedProperty: Property = {
                        property with tokensSold = newTokensSold
                    };
                    
                    properties.put(propertyId, updatedProperty);
                    #ok()
                };
                case null { #err(#PropertyNotFound) };
            }
        };
        
        // Obtener tokens disponibles
        public func getAvailableTokens(propertyId: PropertyId) : Result.Result<Nat, SystemError> {
            switch (properties.get(propertyId)) {
                case (?property) {
                    let available = property.totalTokens - property.tokensSold;
                    #ok(available)
                };
                case null { #err(#PropertyNotFound) };
            }
        };
        
        // Activar/desactivar propiedad
        public func setPropertyStatus(
            propertyId: PropertyId, 
            caller: UserId, 
            isActive: Bool
        ) : Result.Result<(), SystemError> {
            switch (properties.get(propertyId)) {
                case (?property) {
                    if (property.owner != caller) {
                        return #err(#NotAuthorized);
                    };
                    
                    let updatedProperty: Property = {
                        property with isActive = isActive
                    };
                    
                    properties.put(propertyId, updatedProperty);
                    #ok()
                };
                case null { #err(#PropertyNotFound) };
            }
        };
        
        // Funciones helper privadas
        private func updateOwnerProperties(owner: UserId, propertyId: PropertyId) {
            switch (propertyOwners.get(owner)) {
                case (?existingProperties) {
                    let buffer = Buffer.fromArray<PropertyId>(existingProperties);
                    buffer.add(propertyId);
                    propertyOwners.put(owner, Buffer.toArray(buffer));
                };
                case null {
                    propertyOwners.put(owner, [propertyId]);
                };
            }
        };
        
        // Buscar propiedades por criterios
        public func searchProperties(
            location: ?Text,
            propertyType: ?Types.PropertyType,
            minPrice: ?Float,
            maxPrice: ?Float,
            onlyActive: ?Bool
        ) : [Property] {
            let results = Buffer.Buffer<Property>(0);
            
            for ((_, property) in properties.entries()) {
                var matches = true;
                
                // Filtrar por estado activo
                switch (onlyActive) {
                    case (?active) {
                        matches := matches and (property.isActive == active);
                    };
                    case null { 
                        matches := matches and property.isActive; // Por defecto solo activas
                    };
                };
                
                // Filtrar por ubicación
                switch (location) {
                    case (?loc) {
                        let locationText = Text.toLowercase(property.location.address # " " # 
                                                          property.location.city # " " # 
                                                          property.location.state);
                        let searchText = Text.toLowercase(loc);
                        matches := matches and Text.contains(locationText, #text searchText);
                    };
                    case null { /* no filter */ };
                };
                
                // Filtrar por tipo
                switch (propertyType) {
                    case (?pType) {
                        matches := matches and (property.propertyType == pType);
                    };
                    case null { /* no filter */ };
                };
                
                // Filtrar por precio mínimo
                switch (minPrice) {
                    case (?min) {
                        matches := matches and (property.pricePerToken >= min);
                    };
                    case null { /* no filter */ };
                };
                
                // Filtrar por precio máximo
                switch (maxPrice) {
                    case (?max) {
                        matches := matches and (property.pricePerToken <= max);
                    };
                    case null { /* no filter */ };
                };
                
                if (matches) {
                    results.add(property);
                };
            };
            
            Buffer.toArray(results)
        };
        
        // Buscar propiedades con filtros avanzados
        public func searchPropertiesAdvanced(filter: Types.PropertyFilter) : [Property] {
            searchProperties(
                filter.location,
                filter.propertyType,
                filter.minPrice,
                filter.maxPrice,
                filter.isActive
            )
        };
        
        // Obtener estadísticas de propiedades
        public func getPropertyStats() : Types.PropertyStats {
            var totalProperties = 0;
            var activeProperties = 0;
            var totalTokensIssued = 0;
            var totalTokensSold = 0;
            var totalPriceSum = 0.0;
            var activePriceCount = 0;
            var totalValueSum = 0.0;
            var uniqueOwners = HashMap.HashMap<UserId, Bool>(10, Principal.equal, Principal.hash);
            
            for ((_, property) in properties.entries()) {
                totalProperties += 1;
                totalTokensIssued += property.tokensIssued;
                totalTokensSold += property.tokensSold;
                totalValueSum += property.totalValue;
                
                // Contar propietarios únicos
                uniqueOwners.put(property.owner, true);
                
                if (property.isActive) {
                    activeProperties += 1;
                    totalPriceSum += property.pricePerToken;
                    activePriceCount += 1;
                };
            };
            
            let averageOwnership = if (totalTokensIssued > 0 and uniqueOwners.size() > 0) {
                Float.fromInt(totalTokensSold) / Float.fromInt(uniqueOwners.size())
            } else { 0.0 };
            
            let utilizationRate = if (totalTokensIssued > 0) {
                Float.fromInt(totalTokensSold) / Float.fromInt(totalTokensIssued) * 100.0
            } else { 0.0 };
            
            {
                totalTokens = totalTokensIssued;
                tokensIssued = totalTokensIssued;
                tokensSold = totalTokensSold;
                uniqueOwners = uniqueOwners.size();
                averageOwnership = averageOwnership;
                totalValueLocked = totalValueSum;
                utilizationRate = utilizationRate;
                currentValue = totalValueSum;
            }
        };
        
        // Obtener estadísticas generales del sistema
        public func getSystemStats() : {
            totalProperties: Nat;
            activeProperties: Nat;
            totalTokensIssued: Nat;
            totalTokensSold: Nat;
            averagePrice: Float;
            totalValue: Float;
        } {
            var totalProperties = 0;
            var activeProperties = 0;
            var totalTokensIssued = 0;
            var totalTokensSold = 0;
            var totalPriceSum = 0.0;
            var activePriceCount = 0;
            var totalValue = 0.0;
            
            for ((_, property) in properties.entries()) {
                totalProperties += 1;
                totalTokensIssued += property.tokensIssued;
                totalTokensSold += property.tokensSold;
                totalValue += property.totalValue;
                
                if (property.isActive) {
                    activeProperties += 1;
                    totalPriceSum += property.pricePerToken;
                    activePriceCount += 1;
                };
            };
            
            let averagePrice = if (activePriceCount > 0) {
                totalPriceSum / Float.fromInt(activePriceCount)
            } else { 0.0 };
            
            {
                totalProperties = totalProperties;
                activeProperties = activeProperties;
                totalTokensIssued = totalTokensIssued;
                totalTokensSold = totalTokensSold;
                averagePrice = averagePrice;
                totalValue = totalValue;
            }
        };
        
        // Obtener conteo de propiedades
        public func getPropertyCount() : Nat {
            properties.size()
        };
        
        // Verificar si una propiedad existe
        public func propertyExists(propertyId: PropertyId) : Bool {
            switch (properties.get(propertyId)) {
                case (?_) { true };
                case null { false };
            }
        };
        
        // Obtener el siguiente ID de propiedad
        public func getNextPropertyId() : PropertyId {
            nextPropertyId
        };
        
        // Método para testing/debugging
        public func debugGetAllPropertyIds() : [PropertyId] {
            let ids = Buffer.Buffer<PropertyId>(0);
            for ((id, _) in properties.entries()) {
                ids.add(id);
            };
            Buffer.toArray(ids)
        };
    }
}