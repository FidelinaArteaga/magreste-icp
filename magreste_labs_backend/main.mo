import Types "./Types";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

// Importar módulos personalizados (asegúrate de que estos módulos existen y están correctos)
// import PropertyManager "./PropertyManager";
// import TokenManager "./TokenManager";
// import TransactionManager "./TransactionManager";
// import Validation "./Validation";

actor MagresteLabs {
    // ========== FUNCIÓN HASH PERSONALIZADA ==========
    private func natHash(n: Nat): Hash.Hash {
        Text.hash(Nat.toText(n))
    };

    // ========== CONTADORES ESTABLES ==========
    private stable var nextUserId: Nat = 1;
    private stable var nextPropertyId: Nat = 1;
    private stable var nextTokenId: Nat = 1;
    private stable var nextTransactionId: Nat = 1;

    // ========== ARRAYS ESTABLES PARA PERSISTENCIA ==========
    private stable var usersEntries: [(Types.UserId, Types.UserProfile)] = [];
    private stable var propertiesEntries: [(Types.PropertyId, Types.Property)] = [];
    private stable var tokensEntries: [(Types.TokenId, Types.PropertyToken)] = [];
    private stable var transactionsEntries: [(Text, Types.TransactionRecord)] = [];
    private stable var paymentRecordsEntries: [(Text, Types.PaymentRecord)] = [];
    private stable var userTokensEntries: [(Types.UserId, [Types.TokenId])] = [];

    // ========== HASHMAPS (NO PUEDEN SER STABLE) ==========
    private var users = HashMap.HashMap<Types.UserId, Types.UserProfile>(
        0, 
        Principal.equal, 
        Principal.hash
    );

    private var properties = HashMap.HashMap<Types.PropertyId, Types.Property>(
        0,  
        Nat.equal,  
        natHash
    );

    private var tokens = HashMap.HashMap<Types.TokenId, Types.PropertyToken>(
        0, 
        Nat.equal, 
        natHash
    );

    private var transactions = HashMap.HashMap<Text, Types.TransactionRecord>(
        0,
        Text.equal,
        Text.hash
    );

    private var paymentRecords = HashMap.HashMap<Text, Types.PaymentRecord>(
        0,
        Text.equal,
        Text.hash
    );

    private var userTokens = HashMap.HashMap<Types.UserId, [Types.TokenId]>(
        0, 
        Principal.equal, 
        Principal.hash
    );

    // ========== FUNCIONES DE UPGRADE PARA PERSISTENCIA ==========
    system func preupgrade() {
        usersEntries := users.entries() |> Iter.toArray(_);
        propertiesEntries := properties.entries() |> Iter.toArray(_);
        tokensEntries := tokens.entries() |> Iter.toArray(_);
        transactionsEntries := transactions.entries() |> Iter.toArray(_);
        paymentRecordsEntries := paymentRecords.entries() |> Iter.toArray(_);
        userTokensEntries := userTokens.entries() |> Iter.toArray(_);
    };

    system func postupgrade() {
        users := HashMap.fromIter<Types.UserId, Types.UserProfile>(
            usersEntries.vals(),
            usersEntries.size(),
            Principal.equal,
            Principal.hash
        );
        
        properties := HashMap.fromIter<Types.PropertyId, Types.Property>(
            propertiesEntries.vals(),
            propertiesEntries.size(),
            Nat.equal,
            natHash
        );
        
        tokens := HashMap.fromIter<Types.TokenId, Types.PropertyToken>(
            tokensEntries.vals(),
            tokensEntries.size(),
            Nat.equal,
            natHash
        );
        
        transactions := HashMap.fromIter<Text, Types.TransactionRecord>(
            transactionsEntries.vals(),
            transactionsEntries.size(),
            Text.equal,
            Text.hash
        );
        
        paymentRecords := HashMap.fromIter<Text, Types.PaymentRecord>(
            paymentRecordsEntries.vals(),
            paymentRecordsEntries.size(),
            Text.equal,
            Text.hash
        );
        
        userTokens := HashMap.fromIter<Types.UserId, [Types.TokenId]>(
            userTokensEntries.vals(),
            userTokensEntries.size(),
            Principal.equal,
            Principal.hash
        );
        
        // Limpiar arrays después de la restauración
        usersEntries := [];
        propertiesEntries := [];
        tokensEntries := [];
        transactionsEntries := [];
        paymentRecordsEntries := [];
        userTokensEntries := [];
    };

    // ========== FUNCIONES DE USUARIO ==========
    
    public func createUser(request: Types.CreateUserRequest): async Types.CreateUserResponse {
        let caller = msg.caller;
        
        // Validar si el usuario ya existe
        if (users.containsKey(caller)) {
            return #err(#AlreadyInitialized);
        };

        let user: Types.UserProfile = { 
            id = caller;
            email = request.email;
            firstName = request.firstName;
            lastName = request.lastName;
            phone = request.phone;
            isVerified = false;
            joinedAt = Time.now();
            lastActivity = Time.now();
            kycStatus = #NotStarted; 
            totalInvested = 0.0;
            propertyTokensOwned = 0;
            utilityTokensOwned = 0;
            role = #Investor; 
            permissions = [#ViewPublicData]; 
            country = request.country;
            isActive = true;
        };

        users.put(caller, user);
        #ok(user)
    };

    public func getUser(userId: Types.UserId): async Types.GetUserResponse {
        switch (users.get(userId)) {
            case (?user) { #ok(user) };
            case null { #err(#NotFound) }; 
        }
    };

    public query func getUserById(userId: Types.UserId): async ?Types.UserProfile { 
        switch (users.get(userId)) {
            case (?user) {
                let updatedUser: Types.UserProfile = { 
                    id = user.id;
                    email = user.email;
                    firstName = user.firstName;
                    lastName = user.lastName;
                    phone = user.phone;
                    isVerified = user.isVerified;
                    joinedAt = user.joinedAt;
                    lastActivity = Time.now(); 
                    kycStatus = user.kycStatus;
                    totalInvested = calculateUserInvestment(userId);
                    propertyTokensOwned = calculateUserTokens(userId);
                    utilityTokensOwned = user.utilityTokensOwned;
                    role = user.role;
                    permissions = user.permissions;
                    country = user.country;
                    isActive = user.isActive;
                };
                ?updatedUser 
            };
            case null { null }; 
        }
    };

    // ========== FUNCIONES DE PROPIEDADES ==========
    
    public func createProperty(request: Types.CreatePropertyRequest, ownerId: Types.UserId): async Types.CreatePropertyResponse {
        let propertyId = nextPropertyId;
        nextPropertyId += 1;

        // Validar que el ownerId existe como usuario registrado
        if (not users.containsKey(ownerId)) {
            return #err(#UserNotFound);
        };

        let property: Types.Property = {
            id = propertyId;
            name = request.name; 
            description = request.description;
            location = request.location;
            totalValue = request.totalValue;
            pricePerToken = request.pricePerToken; 
            totalTokens = request.totalTokens;
            tokensIssued = request.totalTokens; 
            tokensSold = 0; 
            owner = ownerId;
            isActive = true; 
            createdAt = Time.now();
            imageUrls = request.imageUrls; 
            expectedAnnualReturn = request.expectedAnnualReturn; 
            propertyType = request.propertyType; 
            squareMeters = request.squareMeters; 
        };

        properties.put(propertyId, property);
        #ok(property)
    };

    public func getPropertyAvailability(propertyId: Types.PropertyId): async (Types.PropertyId, ?Bool) {
        switch (properties.get(propertyId)) {
            case (?property) {
                let availableTokens = property.totalTokens - property.tokensSold;
                let isAvailable = availableTokens > 0 and property.isActive; 
                (propertyId, ?isAvailable)
            };
            case null { (propertyId, null) };
        }
    };

    // ========== FUNCIONES DE TOKENS ==========
    public func createTokens(propertyId: Types.PropertyId, quantity: Nat): async [Types.PropertyToken] {
        var createdTokens: [Types.PropertyToken] = [];
        
        switch (properties.get(propertyId)) {
            case (?property) {
                if (property.tokensIssued + quantity > property.totalTokens) {
                    Debug.print("Attempted to issue more tokens than totalTokens for property " # Nat.toText(propertyId));
                    return []; 
                };

                for (i in Iter.range(0, quantity - 1)) {
                    let tokenId = nextTokenId;
                    nextTokenId += 1;
                    
                    let token: Types.PropertyToken = {
                        id = tokenId;
                        propertyId = propertyId;
                        owner = Principal.anonymous(); 
                        price = property.pricePerToken; 
                        currentValue = property.pricePerToken; 
                        canTransfer = false;
                        transferEnabledAt = Time.now() + (30 * 24 * 60 * 60 * 1_000_000_000); 
                        createdAt = Time.now();
                        metadata = null;
                    };
                    
                    tokens.put(tokenId, token);
                    createdTokens := Array.append(createdTokens, [token]);
                };

                let updatedProperty: Types.Property = {
                    property with 
                    tokensIssued = property.tokensIssued + quantity
                };
                properties.put(propertyId, updatedProperty); 
            };
            case null {
                Debug.print("Property not found for token creation: " # Nat.toText(propertyId));
            };
        };
        createdTokens
    };

    // ========== FUNCIONES DE TRANSACCIONES ==========
    
    public func createTransaction(
        propertyId: Types.PropertyId, 
        quantity: Nat, 
        price: Float,  
        userId: Types.UserId 
    ): async (Types.PropertyId, Nat, Float, Types.UserId) { 
        let currentTransactionId = nextTransactionId;
        nextTransactionId += 1; 

        let transactionIdText = Nat.toText(currentTransactionId); 

        let transaction: Types.TransactionRecord = { 
            id = transactionIdText; 
            fromUser = null; 
            toUser = ?userId; 
            propertyId = propertyId;
            tokenId = null; 
            amount = price * Float.fromInt(quantity); 
            tokenAmount = quantity; 
            transactionType = #Purchase; 
            status = "pending"; 
            timestamp = Time.now();
            fees = 0.0; 
        };
        
        transactions.put(transactionIdText, transaction);
        (propertyId, quantity, price, userId) 
    };

    public func buyTokens(request: Types.BuyTokensRequest, userId: Types.UserId): async Types.BuyTokensResponse {
        if (not users.containsKey(userId)) {
            return #err(#UserNotFound);
        };

        switch (properties.get(request.propertyId)) {
            case (?property) {
                let availableTokens = property.totalTokens - property.tokensSold;
                
                if (availableTokens < request.quantity) {
                    return #err(#InsufficientTokens); 
                };
                
                let totalCost = property.pricePerToken * Float.fromInt(request.quantity); 
                if (totalCost > request.maxPrice) {
                    return #err(#InvalidAmount); 
                };
                
                let (_, _, _, _) = await createTransaction(
                    request.propertyId, 
                    request.quantity, 
                    property.pricePerToken, 
                    userId
                );
                
                var currentUsersTokens = switch (userTokens.get(userId)) {
                    case (?tokensList) { tokensList };
                    case null { [] };
                };

                for (i in Iter.range(0, request.quantity - 1)) {
                    let tokenOpt = Iter.find(tokens.vals(), func (t: Types.PropertyToken): Bool { 
                        t.propertyId == request.propertyId and t.owner == Principal.anonymous() 
                    });

                    switch (tokenOpt) {
                        case (?tokenToAssign) {
                            let updatedToken: Types.PropertyToken = {
                                tokenToAssign with 
                                owner = userId
                            };
                            tokens.put(tokenToAssign.id, updatedToken); 
                            currentUsersTokens := Array.append(currentUsersTokens, [tokenToAssign.id]);
                        };
                        case null {
                            Debug.print("No available token found for property " # Nat.toText(request.propertyId));
                            return #err(#SystemError("Failed to assign all tokens."));
                        };
                    };
                };
                userTokens.put(userId, currentUsersTokens); 

                let updatedProperty: Types.Property = {
                    property with 
                    tokensSold = property.tokensSold + request.quantity
                };
                properties.put(request.propertyId, updatedProperty);

                let actualTransactionId = Nat.toText(nextTransactionId - 1); 
                let transactionRecordOpt = transactions.get(actualTransactionId);
                
                let finalTransactionRecord = switch (transactionRecordOpt) {
                    case (?tx) { tx };
                    case null {
                        {
                            id = actualTransactionId;
                            fromUser = null;
                            toUser = ?userId;
                            propertyId = request.propertyId;
                            tokenId = null;
                            amount = totalCost;
                            tokenAmount = request.quantity;
                            transactionType = #Purchase;
                            status = "completed";
                            timestamp = Time.now();
                            fees = 0.0;
                        }
                    };
                };

                #ok({
                    transaction = finalTransactionRecord; 
                    newTokenBalance = currentUsersTokens.size(); 
                })
            };
            case null { #err(#PropertyNotFound) }; 
        }
    };

    // ========== FUNCIONES DE PAGOS ==========
    
    public func createPayment(paymentData: Types.PaymentRecord): async Result.Result<Types.PaymentRecord, Types.SystemError> { 
        // Validación básica
        if (not properties.containsKey(paymentData.propertyId)) {
            return #err(#PropertyNotFound);
        };
        if (not users.containsKey(paymentData.payeeId)) { 
            return #err(#UserNotFound);
        };
        
        let paymentId = paymentData.id; 
        paymentRecords.put(paymentId, paymentData);
        #ok(paymentData)
    };

    // ========== FUNCIONES AUXILIARES ==========
    private func calculateUserInvestment(userId: Types.UserId): Float {
        var totalInvestment: Float = 0.0;
        for ((_, transaction) in transactions.entries()) {
            switch (transaction.toUser) {
                case (?user) {
                    if (user == userId and transaction.transactionType == #Purchase) {
                        totalInvestment += transaction.amount;
                    };
                };
                case null {};
            };
        };
        totalInvestment
    };

    private func calculateUserTokens(userId: Types.UserId): Nat {
        switch (userTokens.get(userId)) {
            case (?tokensList) { tokensList.size() };
            case null { 0 };
        }
    };
}