// Events.mo
// Sistema de eventos, logging y auditoría

import Time "mo:base/Time";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Types "./Types";

module {
    
    // Tipos de eventos del sistema
    public type EventType = {
        #PropertyCreated;
        #PropertyUpdated;
        #TokenPurchased;
        #TokenTransferred;
        #PaymentProcessed;
        #PaymentFailed;
        #UserRegistered;
        #UserUpdated;
        #SystemError;
        #SecurityAlert;
        #AdminAction;
    };
    
    // Nivel de severidad del evento
    public type EventLevel = {
        #Info;
        #Warning;
        #Error;
        #Critical;
        #Debug;
    };
    
    // Estructura del evento
    public type Event = {
        id: Nat;
        eventType: EventType;
        level: EventLevel;
        timestamp: Int;
        actor: Principal;
        message: Text;
        metadata: ?Text; // JSON string con datos adicionales
        propertyId: ?Types.PropertyId;
        userId: ?Types.UserId;
        transactionId: ?Text;
        amount: ?Nat;
    };
    
    // Filtros para consultar eventos
    public type EventFilter = {
        eventType: ?EventType;
        level: ?EventLevel;
        actor: ?Principal;
        propertyId: ?Types.PropertyId;
        userId: ?Types.UserId;
        fromTimestamp: ?Int;
        toTimestamp: ?Int;
        limit: ?Nat;
    };
    
    // Estadísticas de eventos
    public type EventStats = {
        totalEvents: Nat;
        eventsByType: [(EventType, Nat)];
        eventsByLevel: [(EventLevel, Nat)];
        recentErrors: Nat;
        systemHealth: {#Healthy; #Warning; #Critical};
    };
    
    public class EventManager() {
        
        // Estado privado
        private stable var nextEventId: Nat = 1;
        private stable var eventsData: [Event] = [];
        private var events = Buffer.Buffer<Event>(0);
        private var eventsByType = HashMap.HashMap<EventType, Nat>(10, eventTypeEqual, eventTypeHash);
        private var eventsByLevel = HashMap.HashMap<EventLevel, Nat>(5, eventLevelEqual, eventLevelHash);
        
        // Inicialización
        public func init() {
            events := Buffer.fromArray(eventsData);
            rebuildStats();
        };
        
        // Registrar un nuevo evento
        public func logEvent(
            eventType: EventType,
            level: EventLevel,
            actor: Principal,
            message: Text,
            metadata: ?Text,
            propertyId: ?Types.PropertyId,
            userId: ?Types.UserId,
            transactionId: ?Text,
            amount: ?Nat
        ) : Event {
            
            let event: Event = {
                id = nextEventId;
                eventType = eventType;
                level = level;
                timestamp = Time.now();
                actor = actor;
                message = message;
                metadata = metadata;
                propertyId = propertyId;
                userId = userId;
                transactionId = transactionId;
                amount = amount;
            };
            
            events.add(event);
            nextEventId += 1;
            
            // Actualizar estadísticas
            updateEventTypeCount(eventType);
            updateEventLevelCount(level);
            
            // Log crítico en consola
            if (level == #Critical or level == #Error) {
                Debug.print("🚨 " # eventTypeToText(eventType) # ": " # message);
            };
            
            // Mantener solo los últimos 10000 eventos para evitar crecimiento infinito
            if (events.size() > 10000) {
                let newEvents = Buffer.Buffer<Event>(9000);
                let startIndex = events.size() - 9000;
                for (i in startIndex..(events.size() - 1)) {
                    newEvents.add(events.get(i));
                };
                events := newEvents;
            };
            
            event
        };
        
        // Funciones de conveniencia para diferentes tipos de eventos
        public func logPropertyCreated(
            actor: Principal, 
            propertyId: Types.PropertyId, 
            propertyName: Text
        ) : Event {
            logEvent(
                #PropertyCreated,
                #Info,
                actor,
                "Property created: " # propertyName,
                null,
                ?propertyId,
                ?actor,
                null,
                null
            )
        };
        
        public func logTokenPurchase(
            actor: Principal,
            propertyId: Types.PropertyId,
            amount: Nat,
            tokenQuantity: Nat
        ) : Event {
            let metadata = "{\"tokenQuantity\":" # debug_show(tokenQuantity) # ",\"pricePerToken\":" # debug_show(amount / tokenQuantity) # "}";
            logEvent(
                #TokenPurchased,
                #Info,
                actor,
                "Tokens purchased: " # debug_show(tokenQuantity) # " tokens",
                ?metadata,
                ?propertyId,
                ?actor,
                null,
                ?amount
            )
        };
        
        public func logPaymentProcessed(
            actor: Principal,
            transactionId: Text,
            amount: Nat,
            propertyId: ?Types.PropertyId
        ) : Event {
            logEvent(
                #PaymentProcessed,
                #Info,
                actor,
                "Payment processed successfully",
                null,
                propertyId,
                ?actor,
                ?transactionId,
                ?amount
            )
        };
        
        public func logPaymentFailed(
            actor: Principal,
            transactionId: Text,
            errorMessage: Text,
            amount: Nat
        ) : Event {
            logEvent(
                #PaymentFailed,
                #Error,
                actor,
                "Payment failed: " # errorMessage,
                null,
                null,
                ?actor,
                ?transactionId,
                ?amount
            )
        };
        
        public func logSystemError(
            actor: Principal,
            errorMessage: Text,
            context: ?Text
        ) : Event {
            logEvent(
                #SystemError,
                #Error,
                actor,
                "System error: " # errorMessage,
                context,
                null,
                null,
                null,
                null
            )
        };
        
        public func logSecurityAlert(
            actor: Principal,
            alertMessage: Text,
            severity: EventLevel
        ) : Event {
            logEvent(
                #SecurityAlert,
                severity,
                actor,
                "Security alert: " # alertMessage,
                null,
                null,
                ?actor,
                null,
                null
            )
        };
        
        // Obtener eventos con filtros
        public func getEvents(filter: EventFilter) : [Event] {
            let results = Buffer.Buffer<Event>(0);
            let limit = switch (filter.limit) {
                case (?l) l;
                case null 100; // Límite por defecto
            };
            
            var count = 0;
            // Iterar en orden inverso para obtener los más recientes primero
            let eventsArray = Buffer.toArray(events);
            let size = eventsArray.size();
            
            if (size == 0) return [];
            
            var i: Int = size - 1;
            while (i >= 0 and count < limit) {
                let event = eventsArray[Int.abs(i)];
                
                if (matchesFilter(event, filter)) {
                    results.add(event);
                    count += 1;
                };
                
                i -= 1;
            };
            
            Buffer.toArray(results)
        };
        
        // Obtener eventos por tipo
        public func getEventsByType(eventType: EventType, limit: ?Nat) : [Event] {
            let filter: EventFilter = {
                eventType = ?eventType;
                level = null;
                actor = null;
                propertyId = null;
                userId = null;
                fromTimestamp = null;
                toTimestamp = null;
                limit = limit;
            };
            getEvents(filter)
        };
        
        // Obtener eventos por usuario
        public func getEventsByUser(userId: Types.UserId, limit: ?Nat) : [Event] {
            let filter: EventFilter = {
                eventType = null;
                level = null;
                actor = null;
                propertyId = null;
                userId = ?userId;
                fromTimestamp = null;
                toTimestamp = null;
                limit = limit;
            };
            getEvents(filter)
        };
        
        // Obtener eventos por propiedad
        public func getEventsByProperty(propertyId: Types.PropertyId, limit: ?Nat) : [Event] {
            let filter: EventFilter = {
                eventType = null;
                level = null;
                actor = null;
                propertyId = ?propertyId;
                userId = null;
                fromTimestamp = null;
                toTimestamp = null;
                limit = limit;
            };
            getEvents(filter)
        };
        
        // Obtener eventos recientes
        public func getRecentEvents(limit: ?Nat) : [Event] {
            let actualLimit = switch (limit) {
                case (?l) l;
                case null 50;
            };
            
            let size = events.size();
            if (size == 0) return [];
            
            let startIndex = if (size > actualLimit) size - actualLimit else 0;
            let results = Buffer.Buffer<Event>(actualLimit);
            
            for (i in startIndex..(size - 1)) {
                results.add(events.get(i));
            };
            
            // Reverse para tener los más recientes primero
            let resultsArray = Buffer.toArray(results);
            Array.reverse(resultsArray)
        };
        
        // Obtener estadísticas del sistema
        public func getSystemStats() : EventStats {
            let recentTimestamp = Time.now() - (24 * 60 * 60 * 1_000_000_000); // Últimas 24 horas
            var recentErrors = 0;
            
            for (event in events.vals()) {
                if (event.timestamp >= recentTimestamp and 
                   (event.level == #Error or event.level == #Critical)) {
                    recentErrors += 1;
                };
            };
            
            let systemHealth = if (recentErrors > 50) {
                #Critical
            } else if (recentErrors > 10) {
                #Warning
            } else {
                #Healthy
            };
            
            {
                totalEvents = events.size();
                eventsByType = eventsByType.entries() |> Iter.toArray(_);
                eventsByLevel = eventsByLevel.entries() |> Iter.toArray(_);
                recentErrors = recentErrors;
                systemHealth = systemHealth;
            }
        };
        
        // Funciones para persistencia
        public func preUpgrade() : [Event] {
            Buffer.toArray(events)
        };
        
        public func postUpgrade(savedEvents: [Event]) {
            events := Buffer.fromArray(savedEvents);
            eventsData := savedEvents;
            rebuildStats();
        };
        
        // Funciones privadas auxiliares
        private func matchesFilter(event: Event, filter: EventFilter) : Bool {
            // Filtro por tipo de evento
            switch (filter.eventType) {
                case (?eventType) {
                    if (event.eventType != eventType) return false;
                };
                case null {};
            };
            
            // Filtro por nivel
            switch (filter.level) {
                case (?level) {
                    if (event.level != level) return false;
                };
                case null {};
            };
            
            // Filtro por actor
            switch (filter.actor) {
                case (?actor) {
                    if (event.actor != actor) return false;
                };
                case null {};
            };
            
            // Filtro por propiedad
            switch (filter.propertyId) {
                case (?propertyId) {
                    switch (event.propertyId) {
                        case (?eventPropertyId) {
                            if (eventPropertyId != propertyId) return false;
                        };
                        case null return false;
                    };
                };
                case null {};
            };
            
            // Filtro por usuario
            switch (filter.userId) {
                case (?userId) {
                    switch (event.userId) {
                        case (?eventUserId) {
                            if (eventUserId != userId) return false;
                        };
                        case null return false;
                    };
                };
                case null {};
            };
            
            // Filtro por timestamp
            switch (filter.fromTimestamp) {
                case (?from) {
                    if (event.timestamp < from) return false;
                };
                case null {};
            };
            
            switch (filter.toTimestamp) {
                case (?to) {
                    if (event.timestamp > to) return false;
                };
                case null {};
            };
            
            true
        };
        
        private func updateEventTypeCount(eventType: EventType) {
            let currentCount = switch (eventsByType.get(eventType)) {
                case (?count) count;
                case null 0;
            };
            eventsByType.put(eventType, currentCount + 1);
        };
        
        private func updateEventLevelCount(level: EventLevel) {
            let currentCount = switch (eventsByLevel.get(level)) {
                case (?count) count;
                case null 0;
            };
            eventsByLevel.put(level, currentCount + 1);
        };
        
        private func rebuildStats() {
            eventsByType := HashMap.HashMap<EventType, Nat>(10, eventTypeEqual, eventTypeHash);
            eventsByLevel := HashMap.HashMap<EventLevel, Nat>(5, eventLevelEqual, eventLevelHash);
            
            for (event in events.vals()) {
                updateEventTypeCount(event.eventType);
                updateEventLevelCount(event.level);
            };
        };
        
        private func eventTypeToText(eventType: EventType) : Text {
            switch (eventType) {
                case (#PropertyCreated) "PROPERTY_CREATED";
                case (#PropertyUpdated) "PROPERTY_UPDATED";
                case (#TokenPurchased) "TOKEN_PURCHASED";
                case (#TokenTransferred) "TOKEN_TRANSFERRED";
                case (#PaymentProcessed) "PAYMENT_PROCESSED";
                case (#PaymentFailed) "PAYMENT_FAILED";
                case (#UserRegistered) "USER_REGISTERED";
                case (#UserUpdated) "USER_UPDATED";
                case (#SystemError) "SYSTEM_ERROR";
                case (#SecurityAlert) "SECURITY_ALERT";
                case (#AdminAction) "ADMIN_ACTION";
            }
        };
    };
    
    // Funciones auxiliares para hashing y comparación
    private func eventTypeEqual(a: EventType, b: EventType) : Bool {
        a == b
    };
    
    private func eventTypeHash(eventType: EventType) : Nat32 {
        switch (eventType) {
            case (#PropertyCreated) 0;
            case (#PropertyUpdated) 1;
            case (#TokenPurchased) 2;
            case (#TokenTransferred) 3;
            case (#PaymentProcessed) 4;
            case (#PaymentFailed) 5;
            case (#UserRegistered) 6;
            case (#UserUpdated) 7;
            case (#SystemError) 8;
            case (#SecurityAlert) 9;
            case (#AdminAction) 10;
        }
    };
    
    private func eventLevelEqual(a: EventLevel, b: EventLevel) : Bool {
        a == b
    };
    
    private func eventLevelHash(level: EventLevel) : Nat32 {
        switch (level) {
            case (#Info) 0;
            case (#Warning) 1;
            case (#Error) 2;
            case (#Critical) 3;
            case (#Debug) 4;
        }
    };
}

// Importaciones necesarias
import Iter "mo:base/Iter";