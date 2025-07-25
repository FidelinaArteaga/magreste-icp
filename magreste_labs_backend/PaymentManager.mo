// PaymentManager.mo
// Gestión de pagos y métodos de pago

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
import Hash "mo:base/Hash";
import Types "./Types";
import Utils "./Utils";

module {
    
    public class PaymentManager() {
        
        // Estado privado
        private var paymentRecords = HashMap.HashMap<Nat, PaymentRecord>(100, Nat.equal, func(n: Nat) : Nat32 { 
            Nat32.fromNat(n % (2**32 - 1))  // LÍNEA CORREGIDA
        });
        private var userPayments = HashMap.HashMap<Types.UserId, [Nat]>(50, Principal.equal, Principal.hash);
        private var nextPaymentId: Nat = 1;
        
        // Tipos específicos para pagos
        public type PaymentRecord = {
            id: Nat;
            user: Types.UserId;
            propertyId: Types.PropertyId;
            tokenIds: [Types.TokenId];
            amount: Nat; // Cantidad en centavos USD
            paymentMethod: Types.PaymentMethod;
            status: PaymentStatus;
            createdAt: Int;
            processedAt: ?Int;
            transactionHash: ?Text;
            fees: PaymentFees;
        };
        
        public type PaymentStatus = {
            #pending;
            #processing;
            #completed;
            #failed;
            #refunded;
        };
        
        public type PaymentFees = {
            platformFee: Nat;
            networkFee: Nat;
            totalFees: Nat;
        };
        
        // Helper function for payment method comparison
        private func paymentMethodEqual(a: Types.PaymentMethod, b: Types.PaymentMethod) : Bool {
            switch (a, b) {
                case (#ICP, #ICP) true;
                case (#USDC, #USDC) true;
                case (#USDT, #USDT) true;
                case (#BTC, #BTC) true;
                case (#ETH, #ETH) true;
                case (_, _) false;
            }
        };
        
        private func paymentMethodHash(method: Types.PaymentMethod) : Nat32 {
            switch (method) {
                case (#ICP) 0;
                case (#USDC) 1;
                case (#USDT) 2;
                case (#BTC) 3;
                case (#ETH) 4;
            }
        };
        
        // Tasas de cambio (simuladas - en producción usar oráculos reales)
        private var exchangeRates = HashMap.HashMap<Types.PaymentMethod, Nat>(5, paymentMethodEqual, paymentMethodHash);
        
        // ========================================
        // INICIALIZACIÓN Y CONFIGURACIÓN
        // ========================================
        
        public func initializeExchangeRates() {
            // Tasas de ejemplo (en centavos USD por unidad)
            exchangeRates.put(#ICP, 1200); // $12.00 por ICP
            exchangeRates.put(#USDC, 100); // $1.00 por USDC
            exchangeRates.put(#USDT, 100); // $1.00 por USDT
            exchangeRates.put(#BTC, 4500000); // $45,000.00 por BTC
            exchangeRates.put(#ETH, 250000); // $2,500.00 por ETH
        };
        
        // Actualizar tasa de cambio
        public func updateExchangeRate(method: Types.PaymentMethod, rateInCents: Nat) : Result.Result<(), Types.SystemError> {
            if (rateInCents == 0) {
                return #err(#SystemError("Exchange rate cannot be zero"));
            };
            
            exchangeRates.put(method, rateInCents);
            #ok()
        };
        
        // ========================================
        // PROCESAMIENTO DE PAGOS
        // ========================================
        
        // Crear solicitud de pago
        public func createPaymentRequest(
            user: Types.UserId,
            request: Types.PurchaseRequest
        ) : Result.Result<Nat, Types.SystemError> {
            
            // Validar método de pago
            if (not Utils.isValidPaymentMethod(request.paymentMethod)) {
                return #err(#SystemError("Invalid payment method"));
            };
            
            // Validar cantidad
            if (not Utils.validateTokenQuantity(request.quantity)) {
                return #err(#InvalidQuantity);
            };
            
            // Convertir Float a Nat para paymentAmount
            let paymentAmountNat = Int.abs(Float.toInt(Float.abs(request.paymentAmount)));
            
            // Calcular fees
            let fees = calculatePaymentFees(paymentAmountNat, request.paymentMethod);
            
            // Crear registro de pago
            let paymentRecord: PaymentRecord = {
                id = nextPaymentId;
                user = user;
                propertyId = request.propertyId;
                tokenIds = []; // Se llenará cuando se procese
                amount = paymentAmountNat;
                paymentMethod = request.paymentMethod;
                status = #pending;
                createdAt = Time.now();
                processedAt = null;
                transactionHash = null;
                fees = fees;
            };
            
            paymentRecords.put(nextPaymentId, paymentRecord);
            updateUserPayments(user, nextPaymentId);
            
            let paymentId = nextPaymentId;
            nextPaymentId += 1;
            
            #ok(paymentId)
        };
        
        // Procesar pago
        public func processPayment(
            paymentId: Nat,
            tokenIds: [Types.TokenId],
            transactionHash: Text
        ) : async Result.Result<(), Types.SystemError> {
            
            switch (paymentRecords.get(paymentId)) {
                case (?payment) {
                    if (payment.status != #pending) {
                        return #err(#SystemError("Payment is not in pending status"));
                    };
                    
                    // Actualizar estado a procesando
                    let processingPayment: PaymentRecord = {
                        payment with 
                        status = #processing;
                        transactionHash = ?transactionHash;
                    };
                    paymentRecords.put(paymentId, processingPayment);
                    
                    // Simular verificación de pago en blockchain
                    let verificationResult = await verifyPaymentOnChain(payment.paymentMethod, transactionHash, payment.amount);
                    
                    switch (verificationResult) {
                        case (#ok()) {
                            // Completar pago
                            let completedPayment: PaymentRecord = {
                                processingPayment with 
                                status = #completed;
                                tokenIds = tokenIds;
                                processedAt = ?Time.now();
                            };
                            paymentRecords.put(paymentId, completedPayment);
                            #ok()
                        };
                        case (#err(error)) {
                            // Marcar como fallido
                            let failedPayment: PaymentRecord = {
                                processingPayment with status = #failed;
                            };
                            paymentRecords.put(paymentId, failedPayment);
                            #err(error)
                        };
                    }
                };
                case null { #err(#SystemError("Payment not found")) };
            }
        };
        
        // Verificar pago en blockchain (simulado)
        private func verifyPaymentOnChain(
            method: Types.PaymentMethod,
            hash: Text,
            _expectedAmount: Nat
        ) : async Result.Result<(), Types.SystemError> {
            // En un sistema real, aquí se verificaría la transacción en la blockchain correspondiente
            
            // Simulación de verificación
            if (hash.size() < 10) {
                return #err(#SystemError("Invalid transaction hash"));
            };
            
            // Simular tiempo de verificación
            // En producción, usar oráculos o servicios de verificación reales
            
            switch (method) {
                case (#ICP) {
                    // Verificar transacción ICP
                    #ok()
                };
                case (#USDC) {
                    // Verificar transacción USDC
                    #ok()
                };
                case (#USDT) {
                    // Verificar transacción USDT
                    #ok()
                };
                case (#BTC) {
                    // Verificar transacción BTC
                    #ok()
                };
                case (#ETH) {
                    // Verificar transacción ETH
                    #ok()
                };
            }
        };
        
        // ========================================
        // CÁLCULO DE FEES
        // ========================================
        
        // Calcular fees de pago
        private func calculatePaymentFees(amount: Nat, method: Types.PaymentMethod) : PaymentFees {
            let platformFeeRate = 250; // 2.5% en puntos base
            let platformFee = (amount * platformFeeRate) / 10000;
            
            let networkFee = switch (method) {
                case (#ICP) 10000; // 0.0001 ICP en e8s
                case (#USDC) 100; // $1.00 en centavos
                case (#USDT) 100; // $1.00 en centavos
                case (#BTC) 50000; // Fee alto para BTC
                case (#ETH) 30000; // Fee para ETH
            };
            
            {
                platformFee = platformFee;
                networkFee = networkFee;
                totalFees = platformFee + networkFee;
            }
        };
        
        // ========================================
        // GESTIÓN DE USUARIOS
        // ========================================
        
        // Actualizar pagos del usuario
        private func updateUserPayments(user: Types.UserId, paymentId: Nat) {
            switch (userPayments.get(user)) {
                case (?existingPayments) {
                    let buffer = Buffer.fromArray<Nat>(existingPayments);
                    buffer.add(paymentId);
                    userPayments.put(user, Buffer.toArray(buffer));
                };
                case null {
                    userPayments.put(user, [paymentId]);
                };
            }
        };
        
        // ========================================
        // CONSULTAS PÚBLICAS
        // ========================================
        
        // Obtener estado de pago
        public func getPaymentStatus(paymentId: Nat) : Result.Result<PaymentRecord, Types.SystemError> {
            switch (paymentRecords.get(paymentId)) {
                case (?payment) #ok(payment);
                case null #err(#SystemError("Payment not found"));
            }
        };
        
        // Obtener pagos del usuario
        public func getUserPayments(user: Types.UserId) : [PaymentRecord] {
            switch (userPayments.get(user)) {
                case (?paymentIds) {
                    let buffer = Buffer.Buffer<PaymentRecord>(paymentIds.size());
                    for (id in paymentIds.vals()) {
                        switch (paymentRecords.get(id)) {
                            case (?payment) buffer.add(payment);
                            case null { /* skip missing payments */ };
                        };
                    };
                    Buffer.toArray(buffer)
                };
                case null [];
            }
        };
        
        // Obtener tasa de cambio
        public func getExchangeRate(method: Types.PaymentMethod) : ?Nat {
            exchangeRates.get(method)
        };
        
        // Convertir cantidad entre métodos de pago
        public func convertAmount(
            fromMethod: Types.PaymentMethod,
            toMethod: Types.PaymentMethod,
            amount: Nat
        ) : Result.Result<Nat, Types.SystemError> {
            switch (exchangeRates.get(fromMethod), exchangeRates.get(toMethod)) {
                case (?fromRate, ?toRate) {
                    let usdAmount = (amount * fromRate) / 100; // Convertir a centavos USD
                    let convertedAmount = (usdAmount * 100) / toRate; // Convertir al método destino
                    #ok(convertedAmount)
                };
                case (_, _) #err(#SystemError("Exchange rate not available"));
            }
        };
        
        // ========================================
        // FUNCIONES DE ADMINISTRACIÓN
        // ========================================
        
        // Procesar reembolso
        public func processRefund(paymentId: Nat) : async Result.Result<(), Types.SystemError> {
            switch (paymentRecords.get(paymentId)) {
                case (?payment) {
                    if (payment.status != #completed) {
                        return #err(#SystemError("Only completed payments can be refunded"));
                    };
                    
                    let refundedPayment: PaymentRecord = {
                        payment with status = #refunded;
                    };
                    paymentRecords.put(paymentId, refundedPayment);
                    #ok()
                };
                case null #err(#SystemError("Payment not found"));
            }
        };
        
        // Obtener estadísticas de pagos
        public func getPaymentStats() : {
            totalPayments: Nat;
            completedPayments: Nat;
            totalVolume: Nat;
            averageAmount: Nat;
        } {
            var totalPayments = 0;
            var completedPayments = 0;
            var totalVolume = 0;
            
            for ((_, payment) in paymentRecords.entries()) {
                totalPayments += 1;
                if (payment.status == #completed) {
                    completedPayments += 1;
                    totalVolume += payment.amount;
                };
            };
            
            let averageAmount = if (completedPayments > 0) {
                totalVolume / completedPayments
            } else { 0 };
            
            {
                totalPayments = totalPayments;
                completedPayments = completedPayments;
                totalVolume = totalVolume;
                averageAmount = averageAmount;
            }
        };
    }
}