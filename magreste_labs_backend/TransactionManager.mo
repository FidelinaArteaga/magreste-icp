// TransactionManager.mo
// Gestión de transacciones del sistema

import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Option "mo:base/Option";
import Hash "mo:base/Hash";
import Types "./Types";
import Utils "./Utils";

module {
    
    public class TransactionManager() {
        
        // ========== ESTADO PRIVADO ==========
        private var transactions = HashMap.HashMap<Types.TransactionId, Types.TransactionRecord>(100, Nat.equal, Hash.hash);
        private var userTransactions = HashMap.HashMap<Types.UserId, [Types.TransactionId]>(50, Principal.equal, Principal.hash);
        private var propertyTransactions = HashMap.HashMap<Types.PropertyId, [Types.TransactionId]>(20, Nat.equal, Hash.hash);
        private var nextTransactionId: Types.TransactionId = 1;
        
        // Configuración del sistema
        private let TRANSACTION_FEE_PERCENT: Float = 0.025; // 2.5% de comisión
        private let MIN_TRANSACTION_FEE: Float = 1.0; // $1 mínimo
        private let MAX_TRANSACTION_FEE: Float = 100.0; // $100 máximo
        
        // ========== REGISTRO DE TRANSACCIONES ==========
        
        // Registrar mint de tokens
        public func recordMintTransaction(
            propertyId: Types.PropertyId,
            tokenIds: [Types.TokenId],
            totalAmount: Float,
            toUser: Types.UserId
        ) : Result.Result<Types.TransactionId, Types.SystemError> {
            
            let fees = calculateTransactionFees(totalAmount);
            let transaction: Types.TransactionRecord = {
                id = nextTransactionId;
                transactionType = #Mint;
                propertyId = propertyId;
                tokenId = ?tokenIds[0];
                fromUser = null;
                toUser = ?toUser;
                price = Float.fromInt(tokenIds.size());
                fees = fees;
                timestamp = Time.now();
            };
            
            transactions.put(nextTransactionId, transaction);
            let transactionId = nextTransactionId;
            nextTransactionId += 1;
            
            // Actualizar índices
            updateUserTransactions(toUser);
            updatePropertyTransactions(propertyId);
            
            #ok(transactionId)
        };
        
        // Registrar compra de tokens
        public func recordPurchaseTransaction(
            propertyId: Types.PropertyId,
            tokenIds: [Types.TokenId],
            buyer: Types.UserId,
            totalAmount: Float
        ) : Result.Result<Types.TransactionId, Types.SystemError> {
            
            if (tokenIds.size() == 0) {
                return #err(#InvalidQuantity);
            };
            
            let fees = calculateTransactionFees(totalAmount);
            let transaction: Types.TransactionRecord = {
                id = nextTransactionId;
                transactionType = #Purchase;
                propertyId = propertyId;
                tokenId = ?tokenIds[0];
                fromUser = null; // Sistema vende
                toUser = ?buyer;
                price = totalAmount;
                fees = fees;
                timestamp = Time.now();
            };
            
            transactions.put(nextTransactionId, transaction);
            let transactionId = nextTransactionId;
            nextTransactionId += 1;
            
            // Actualizar índices
            updateUserTransactions(buyer);
            updatePropertyTransactions(propertyId);
            
            #ok(transactionId)
        };
        
        // Registrar transferencia de tokens
        public func recordTransferTransaction(
            propertyId: Types.PropertyId,
            tokenId: Types.TokenId,
            fromUser: Types.UserId,
            toUser: Types.UserId,
            price: Float
        ) : Result.Result<Types.TransactionId, Types.SystemError> {
            
            let fees = calculateTransactionFees(price);
            let transaction: Types.TransactionRecord = {
                id = nextTransactionId;
                transactionType = #Transfer;
                propertyId = propertyId;
                tokenId = ?tokenId;
                fromUser = ?fromUser;
                toUser = ?toUser;
                price = price;
                fees = fees;
                timestamp = Time.now();
            };
            
            transactions.put(nextTransactionId, transaction);
            let transactionId = nextTransactionId;
            nextTransactionId += 1;
            
            // Actualizar índices
            updateUserTransactions(fromUser);
            updateUserTransactions(toUser);
            updatePropertyTransactions(propertyId);
            
            #ok(transactionId)
        };
        
        // Registrar generación de utility token
        public func recordUtilityTokenGeneration(
            propertyId: Types.PropertyId,
            utilityTokenId: Types.TokenId,
            user: Types.UserId
        ) : Result.Result<Types.TransactionId, Types.SystemError> {
            
            let transaction: Types.TransactionRecord = {
                id = nextTransactionId;
                transactionType = #UtilityGeneration;
                propertyId = propertyId;
                tokenId = ?utilityTokenId;
                fromUser = null;
                toUser = ?user;
                price = 0.0;
                fees = 0.0;
                timestamp = Time.now();
            };
            
            transactions.put(nextTransactionId, transaction);
            let transactionId = nextTransactionId;
            nextTransactionId += 1;
            
            // Actualizar índices
            updateUserTransactions(user);
            updatePropertyTransactions(propertyId);
            
            #ok(transactionId)
        };
        
        // ========== CONSULTA DE TRANSACCIONES ==========
        
        // Obtener transacciones de un usuario
        public func getUserTransactions(
            user: Types.UserId,
            page: ?Nat,
            pageSize: ?Nat
        ) : Result.Result<[Types.TransactionRecord], Types.SystemError> {
            
            let currentPage = Option.get(page, 0);
            let currentPageSize = Option.get(pageSize, 10);
            
            switch (userTransactions.get(user)) {
                case null { #ok([]) };
                case (?transactionIds) {
                    let buffer = Buffer.Buffer<Types.TransactionRecord>(transactionIds.size());
                    
                    for (transactionId in transactionIds.vals()) {
                        switch (transactions.get(transactionId)) {
                            case (?transaction) {
                                buffer.add(transaction);
                            };
                            case null { /* Skip missing transaction */ };
                        };
                    };
                    
                    let allTransactions = Buffer.toArray(buffer);
                    let startIndex = currentPage * currentPageSize;
                    let endIndex = Nat.min(startIndex + currentPageSize, allTransactions.size());
                    
                    if (startIndex >= allTransactions.size()) {
                        #ok([])
                    } else {
                        let pageTransactions = Array.tabulate<Types.TransactionRecord>(
                            endIndex - startIndex,
                            func(i) = allTransactions[startIndex + i]
                        );
                        #ok(pageTransactions)
                    }
                };
            }
        };
        
        // Obtener transacciones de una propiedad
        public func getPropertyTransactions(
            propertyId: Types.PropertyId,
            page: ?Nat,
            pageSize: ?Nat
        ) : Result.Result<[Types.TransactionRecord], Types.SystemError> {
            
            let currentPage = Option.get(page, 0);
            let currentPageSize = Option.get(pageSize, 10);
            
            switch (propertyTransactions.get(propertyId)) {
                case null { #ok([]) };
                case (?transactionIds) {
                    let buffer = Buffer.Buffer<Types.TransactionRecord>(transactionIds.size());
                    
                    for (transactionId in transactionIds.vals()) {
                        switch (transactions.get(transactionId)) {
                            case (?transaction) {
                                buffer.add(transaction);
                            };
                            case null { /* Skip missing transaction */ };
                        };
                    };
                    
                    let allTransactions = Buffer.toArray(buffer);
                    let startIndex = currentPage * currentPageSize;
                    let endIndex = Nat.min(startIndex + currentPageSize, allTransactions.size());
                    
                    if (startIndex >= allTransactions.size()) {
                        #ok([])
                    } else {
                        let pageTransactions = Array.tabulate<Types.TransactionRecord>(
                            endIndex - startIndex,
                            func(i) = allTransactions[startIndex + i]
                        );
                        #ok(pageTransactions)
                    }
                };
            }
        };
        
        // Obtener una transacción específica
        public func getTransaction(transactionId: Types.TransactionId) : ?Types.TransactionRecord {
            transactions.get(transactionId)
        };
        
        // ========== FUNCIONES AUXILIARES ==========
        
        // Calcular comisiones de transacción
        private func calculateTransactionFees(amount: Float) : Float {
            let feeAmount = amount * TRANSACTION_FEE_PERCENT;
            
            if (feeAmount < MIN_TRANSACTION_FEE) {
                MIN_TRANSACTION_FEE
            } else if (feeAmount > MAX_TRANSACTION_FEE) {
                MAX_TRANSACTION_FEE
            } else {
                feeAmount
            }
        };
        
        // Actualizar índice de transacciones de usuario
        private func updateUserTransactions(user: Types.UserId) {
            let currentTransactionId = nextTransactionId;
            
            switch (userTransactions.get(user)) {
                case null {
                    userTransactions.put(user, [currentTransactionId]);
                };
                case (?existingTransactions) {
                    let buffer = Buffer.fromArray<Types.TransactionId>(existingTransactions);
                    buffer.add(currentTransactionId);
                    userTransactions.put(user, Buffer.toArray(buffer));
                };
            };
        };
        
        // Actualizar índice de transacciones de propiedad
        private func updatePropertyTransactions(propertyId: Types.PropertyId) {
            let currentTransactionId = nextTransactionId;
            
            switch (propertyTransactions.get(propertyId)) {
                case null {
                    propertyTransactions.put(propertyId, [currentTransactionId]);
                };
                case (?existingTransactions) {
                    let buffer = Buffer.fromArray<Types.TransactionId>(existingTransactions);
                    buffer.add(currentTransactionId);
                    propertyTransactions.put(propertyId, Buffer.toArray(buffer));
                };
            };
        };
        
        // ========== FUNCIONES DE ESTADÍSTICAS ==========
        
        // Obtener estadísticas de transacciones
        public func getTransactionStats() : {
            totalTransactions: Nat;
            totalVolume: Float;
            totalFees: Float;
        } {
            var totalVolume: Float = 0.0;
            var totalFees: Float = 0.0;
            var count: Nat = 0;
            
            for (transaction in transactions.vals()) {
                totalVolume += transaction.price;
                totalFees += transaction.fees;
                count += 1;
            };
            
            {
                totalTransactions = count;
                totalVolume = totalVolume;
                totalFees = totalFees;
            }
        };
        
        // Obtener transacciones recientes
        public func getRecentTransactions(limit: ?Nat) : [Types.TransactionRecord] {
            let maxLimit = Option.get(limit, 20);
            let buffer = Buffer.Buffer<Types.TransactionRecord>(maxLimit);
            
            // Obtener las transacciones más recientes
            var currentId = nextTransactionId;
            var added = 0;
            
            while (currentId > 1 and added < maxLimit) {
                currentId -= 1;
                switch (transactions.get(currentId)) {
                    case (?transaction) {
                        buffer.add(transaction);
                        added += 1;
                    };
                    case null { /* Skip missing transaction */ };
                };
            };
            
            Buffer.toArray(buffer)
        };
    }
}