// PropertyManager.mo
// Gestión de propiedades inmobiliarias

import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Types "./Types";
import Utils "./Utils";

module {
    
    public class PropertyManager() {
        
        // Tipos locales para mejor organización
        private type PropertyId = Types.PropertyId;
        private type UserId = Types.UserId;
        private type Property = Types.Property;
        private type SystemError = Types.SystemError;
        
        // Estado privado
        private var nextPropertyId: PropertyId = 1;
        private var properties = HashMap.HashMap<PropertyId, Property>(10, Nat.equal, func(n: Nat) : Nat32 { 
            Nat32.fromNat(n % (2**32 - 1))  // CORREGIDO
        });
        private var propertyOwners = HashMap.HashMap<UserId, [PropertyId]>(10, Principal.equal, Principal.hash);
        
        // Crear nueva propiedad
        public func createProperty(
            name: Text,
            description: Text,
            location: Text,
            totalTokens: Nat,
            owner: UserId,
            imageUrl: ?Text,
            propertyType: Text,
            squareMeters: ?Nat,
            estimatedValue: ?Nat
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
            
            // Validar owner usando Utils si está disponible
            if (not Utils.isValidPrincipal(owner)) {
                return #err(#NotAuthorized);
            };
            
            let now = Time.now();
            let property: Property = {
                id = nextPropertyId;
                name = name;
                description = description;
                location = {
                    address = location;
                    city = "";
                    state = "";
                    country = "";
                    zipCode = "";
                    coordinates = { lat = 0.0; lng = 0.0 };
                };
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
                propertyType = switch (propertyType) {
                    case ("residential") #Residential;
                    case ("commercial") #Commercial;
                    case ("industrial") #Industrial;
                    case ("mixed") #Mixed;
                    case (_) #Residential;
                };
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
        
        // Obtener todas las propiedades
        public func getAllProperties() : [Property] {
            let propertiesArray = Buffer.Buffer<Property>(0);
            for ((id, property) in properties.entries()) {
                propertiesArray.add(property);
            };
            Buffer.toArray(propertiesArray)
        };
        
        // Obtener propiedades activas
        public func getActiveProperties() : [Property] {
            let activeProperties = Buffer.Buffer<Property>(0);
            for ((id, property) in properties.entries()) {
                if (property.isActive) {
                    activeProperties.add(property);  // COMPLETADO
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
                case null [];
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
                    };
                    
                    properties.put(propertyId, updatedProperty);
                    #ok()
                };
                case null #err(#PropertyNotFound);
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
                case null #err(#PropertyNotFound);
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
            maxPrice: ?Float
        ) : [Property] {
            let results = Buffer.Buffer<Property>(0);
            
            for ((id, property) in properties.entries()) {
                var matches = property.isActive;
                
                // Filtrar por ubicación
                switch (location) {
                    case (?loc) {
                        matches := matches and Text.contains(property.location.address, #text loc);
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
        
        // Obtener estadísticas de propiedades
        public func getPropertyStats() : {
            totalProperties: Nat;
            activeProperties: Nat;
            totalTokensIssued: Nat;
            totalTokensSold: Nat;
            averagePrice: Float;
        } {
            var totalProperties = 0;
            var activeProperties = 0;
            var totalTokensIssued = 0;
            var totalTokensSold = 0;
            var totalPriceSum = 0.0;
            var activePriceCount = 0;
            
            for ((_, property) in properties.entries()) {
                totalProperties += 1;
                totalTokensIssued += property.tokensIssued;
                totalTokensSold += property.tokensSold;
                
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
            }
        };
    }
}