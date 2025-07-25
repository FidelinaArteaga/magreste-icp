// Utils.mo
// Funciones de utilidad del sistema

import Time "mo:base/Time";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Types "./Types";

module {
    
    // ========================================
    // VALIDACIONES GENERALES
    // ========================================
    
    // Validar Principal
    public func isValidPrincipal(p: Principal) : Bool {
        not Principal.isAnonymous(p)
    };
    
    // Validar texto no vacío
    public func isValidText(text: Text) : Bool {
        text.size() > 0 and text.size() <= 1000
    };
    
    // Validar cantidad de tokens
    public func validateTokenQuantity(quantity: Nat) : Bool {
        quantity > 0 and quantity <= 10000
    };
    
    // Validar precio
    public func validatePrice(price: Nat) : Bool {
        price > 0 and price <= 1000000000 // Máximo $10M en centavos
    };
    
    // ========================================
    // VALIDACIONES DE MÉTODOS DE PAGO
    // ========================================
    
    // Validar método de pago
    public func isValidPaymentMethod(method: Types.PaymentMethod) : Bool {
        switch (method) {
            case (#ICP) true;
            case (#USDC) true;
            case (#USDT) true;
            case (#BTC) true;
            case (#ETH) true;
        }
    };
    
    // Obtener símbolo del método de pago
    public func getPaymentMethodSymbol(method: Types.PaymentMethod) : Text {
        switch (method) {
            case (#ICP) "ICP";
            case (#USDC) "USDC";
            case (#USDT) "USDT";
            case (#BTC) "BTC";
            case (#ETH) "ETH";
        }
    };
    
    // ========================================
    // UTILIDADES DE TIEMPO
    // ========================================
    
    // Obtener timestamp actual
    public func getCurrentTime() : Int {
        Time.now()
    };
    
    // Validar si una fecha está en el futuro
    public func isFutureDate(timestamp: Int) : Bool {
        timestamp > Time.now()
    };
    
    // Calcular días entre timestamps
    public func daysBetween(start: Int, end: Int) : Nat {
        let diff = Int.abs(end - start);
        let nanosPerDay = 24 * 60 * 60 * 1_000_000_000;
        Int.abs(diff / nanosPerDay)
    };
    
    // ========================================
    // UTILIDADES DE CÁLCULO
    // ========================================
    
    // Calcular porcentaje
    public func calculatePercentage(amount: Nat, percentage: Nat) : Nat {
        (amount * percentage) / 10000 // percentage en puntos base (100 = 1%)
    };
    
    // Calcular rendimiento anual
    public func calculateAPY(principal: Nat, rate: Nat, days: Nat) : Nat {
        let dailyRate = rate / 36500; // rate anual en puntos base / 365 días
        let compoundedAmount = principal + ((principal * dailyRate * days) / 10000);
        if (compoundedAmount > principal) {
            compoundedAmount - principal
        } else {
            0
        }
    };
    
    // ========================================
    // VALIDACIONES DE PROPIEDADES
    // ========================================
    
    // Validar datos de propiedad
    public func validatePropertyData(
        name: Text,
        location: Text,
        pricePerToken: Nat,
        totalTokens: Nat
    ) : Result.Result<(), Types.SystemError> {
        
        if (not isValidText(name)) {
            return #err(#SystemError("Invalid property name"));
        };
        
        if (not isValidText(location)) {
            return #err(#SystemError("Invalid property location"));
        };
        
        if (not validatePrice(pricePerToken)) {
            return #err(#SystemError("Invalid price per token"));
        };
        
        if (not validateTokenQuantity(totalTokens)) {
            return #err(#SystemError("Invalid total tokens"));
        };
        
        #ok()
    };
    
    // ========================================
    // UTILIDADES DE ESTADO
    // ========================================
    
    // Verificar si la propiedad está activa para compras
    public func canPurchaseProperty(isActive: Bool) : Bool {
        isActive
    };
    
    // Verificar si la propiedad permite modificaciones
    public func canModifyProperty(isActive: Bool) : Bool {
        isActive
    };
    
    // ========================================
    // UTILIDADES DE SEGURIDAD
    // ========================================
    
    // Validar hash de transacción
    public func isValidTransactionHash(hash: Text) : Bool {
        hash.size() >= 32 and hash.size() <= 128
    };
    
    // Generar ID único simple
    public func generateSimpleId(counter: Nat, timestamp: Int) : Text {
        Nat.toText(counter) # "_" # Int.toText(timestamp)
    };
    
    // ========================================
    // UTILIDADES DE CONVERSIÓN
    // ========================================
    
    // Convertir centavos a dólares (formato texto)
    public func centsToUSD(cents: Nat) : Text {
        let dollars = cents / 100;
        let remainingCents = cents % 100;
        "$" # Nat.toText(dollars) # "." # 
        (if (remainingCents < 10) "0" else "") # Nat.toText(remainingCents)
    };
    
    // Convertir tokens a texto con formato
    public func formatTokenAmount(amount: Nat) : Text {
        if (amount >= 1000000) {
            let millions = amount / 1000000;
            Nat.toText(millions) # "M tokens"
        } else if (amount >= 1000) {
            let thousands = amount / 1000;
            Nat.toText(thousands) # "K tokens"
        } else {
            Nat.toText(amount) # " tokens"
        }
    };
    
    // ========================================
    // UTILIDADES DE ARRAYS
    // ========================================
    
    // Verificar si un array contiene un elemento
    public func arrayContains<T>(arr: [T], item: T, equal: (T, T) -> Bool) : Bool {
        switch (Array.find<T>(arr, func(x) = equal(x, item))) {
            case (?_) true;
            case null false;
        }
    };
    
    // Remover elemento de array
    public func removeFromArray<T>(arr: [T], item: T, equal: (T, T) -> Bool) : [T] {
        Array.filter<T>(arr, func(x) = not equal(x, item))
    };
    
    // ========================================
    // UTILIDADES DE LÍMITES Y RANGOS
    // ========================================
    
    // Validar límites de paginación
    public func validatePaginationLimits(offset: Nat, limit: Nat) : Result.Result<(), Types.SystemError> {
        if (limit == 0 or limit > 100) {
            return #err(#SystemError("Invalid limit: must be between 1 and 100"));
        };
        
        if (offset > 10000) {
            return #err(#SystemError("Invalid offset: must be less than 10000"));
        };
        
        #ok()
    };
    
    // Aplicar límites seguros
    public func applySafeLimit(requested: Nat, maximum: Nat) : Nat {
        if (requested > maximum) maximum else requested
    };
    
    // ========================================
    // UTILIDADES DE RENDIMIENTO
    // ========================================
    
    // Calcular rendimiento proyectado
    public func calculateProjectedYield(
        investment: Nat,
        annualRate: Nat,
        months: Nat
    ) : Nat {
        let monthlyRate = annualRate / 12;
        (investment * monthlyRate * months) / 10000
    };
    
    // Calcular valor presente neto simplificado
    public func calculateNPV(
        cashFlows: [Nat],
        discountRate: Nat
    ) : Int {
        var npv: Int = 0;
        let rate = discountRate + 10000; // Agregar 100% para evitar división por cero
        
        for (i in cashFlows.keys()) {
            let period = i + 1;
            let discountFactor = 10000; // Simplificado para evitar cálculos complejos
            let presentValue = (cashFlows[i] * discountFactor) / (rate * period);
            npv += presentValue;
        };
        
        npv
    };
}