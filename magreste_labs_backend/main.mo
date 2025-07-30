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

actor MagresteLabs {
    // ========== FUNCIÓN HASH PERSONALIZADA ==========
    private func natHash(n: Nat): Hash.Hash {
        Text.hash(Nat.toText(n))
    };

    // ========== FUNCIÓN AUXILIAR PARA VERIFICAR SI EXISTE UNA CLAVE ==========
    private func containsKey<K, V>(map: HashMap.HashMap<K, V>, key: K) : Bool {
        switch(map.get(key)) {
            case (?_) true;
            case null false;
        }
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
    private stable var transactionsEntries: [(Types.TransactionId, Types.TransactionRecord)] = [];
    private stable var paymentRecordsEntries: [(Text, Types.PaymentRecord)] = [];
    private stable var userTokensEntries: [(Types.UserId, [Types.TokenId])] = [];

    // ========== HASHMAPS ==========
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

    private var transactions = HashMap.HashMap<Types.TransactionId, Types.TransactionRecord>(
        0,
        Nat.equal,
        natHash
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
        usersEntries := Iter.toArray(users.entries());
        propertiesEntries := Iter.toArray(properties.entries());
        tokensEntries := Iter.toArray(tokens.entries());
        transactionsEntries := Iter.toArray(transactions.entries());
        paymentRecordsEntries := Iter.toArray(paymentRecords.entries());
        userTokensEntries := Iter.toArray(userTokens.entries());
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
        
        transactions := HashMap.fromIter<Types.TransactionId, Types.TransactionRecord>(
            transactionsEntries.vals(),
            transactionsEntries.size(),
            Nat.equal,
            natHash
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
    
    public shared(msg) func createUser(request: Types.CreateUserRequest): async ?Types.UserProfile {
        let caller = msg.caller;
        
        if (containsKey(users, caller)) {
            return null;
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
        };

        users.put(caller, user);
        ?user
    };

    public func getUser(userId: Types.UserId): async ?Types.UserProfile {
        users.get(userId)
    };

    public query func getUserById(userId: Types.UserId): async ?Types.UserProfile { 
        users.get(userId)
    };

    // ========== FUNCIONES DE PROPIEDADES ==========
    
    public shared(msg) func createProperty(request: Types.CreatePropertyRequest): async ?Types.Property {
        let caller = msg.caller;
        let propertyId = nextPropertyId;
        nextPropertyId += 1;

        if (not containsKey(users, caller)) {
            return null;
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
            owner = caller;
            isActive = true;
            createdAt = Time.now();
            imageUrls = request.imageUrls;
            expectedAnnualReturn = request.expectedAnnualReturn;
            propertyType = request.propertyType;
            squareMeters = request.squareMeters;
        };

        properties.put(propertyId, property);
        ?property
    };

    public func getProperty(propertyId: Types.PropertyId): async ?Types.Property {
        properties.get(propertyId)
    };

    public query func getPropertyById(propertyId: Types.PropertyId): async ?Types.Property {
        properties.get(propertyId)
    };

    public func getAllProperties(): async [Types.Property] {
        let propertyArray = Iter.toArray(properties.entries());
        Array.map<(Types.PropertyId, Types.Property), Types.Property>(propertyArray, func(entry) = entry.1)
    };

    public func getPropertyAvailability(propertyId: Types.PropertyId): async (Types.PropertyId, ?Bool) {
        switch (properties.get(propertyId)) {
            case (?property) {
                let availableTokens = property.totalTokens - property.tokensSold;
                let isAvailable = availableTokens > 0 and property.isActive; 
                (propertyId, ?isAvailable)
            };
            case null (propertyId, null);
        }
    };

    // ========== FUNCIONES DE TOKENS ==========
    
    public func createTokens(propertyId: Types.PropertyId, quantity: Nat): async [Types.PropertyToken] {
        switch (properties.get(propertyId)) {
            case (?property) {
                var createdTokens: [Types.PropertyToken] = [];
                var i = 0;
                
                while (i < quantity) {
                    let tokenId = nextTokenId;
                    nextTokenId += 1;
                    
                    let token: Types.PropertyToken = {
                        id = tokenId;
                        propertyId = propertyId;
                        owner = property.owner;
                        price = property.pricePerToken;
                        currentValue = property.pricePerToken;
                        createdAt = Time.now();
                        canTransfer = false;
                        transferEnabledAt = Time.now() + (30 * 24 * 60 * 60 * 1_000_000_000);
                        metadata = null;
                    };
                    
                    tokens.put(tokenId, token);
                    createdTokens := Array.append(createdTokens, [token]);
                    i += 1;
                };
                
                createdTokens
            };
            case null [];
        }
    };

    public func getToken(tokenId: Types.TokenId): async ?Types.PropertyToken {
        tokens.get(tokenId)
    };

    public func getTokensByProperty(propertyId: Types.PropertyId): async [Types.PropertyToken] {
        let tokenArray = Iter.toArray(tokens.entries());
        let filteredTokens = Array.filter<(Types.TokenId, Types.PropertyToken)>(tokenArray, func(entry) = entry.1.propertyId == propertyId);
        Array.map<(Types.TokenId, Types.PropertyToken), Types.PropertyToken>(filteredTokens, func(entry) = entry.1)
    };

    public func getTokensByUser(userId: Types.UserId): async [Types.PropertyToken] {
        switch (userTokens.get(userId)) {
            case (?tokenIds) {
                var userTokensList: [Types.PropertyToken] = [];
                for (tokenId in tokenIds.vals()) {
                    switch (tokens.get(tokenId)) {
                        case (?token) {
                            userTokensList := Array.append(userTokensList, [token]);
                        };
                        case null {};
                    };
                };
                userTokensList
            };
            case null [];
        }
    };

    public func getAllTokens(): async [Types.PropertyToken] {
        let tokenArray = Iter.toArray(tokens.entries());
        Array.map<(Types.TokenId, Types.PropertyToken), Types.PropertyToken>(tokenArray, func(entry) = entry.1)
    };

    // ========== FUNCIONES DE TRANSACCIONES ==========
    
    public shared(msg) func buyTokens(request: Types.BuyTokensRequest): async ?Types.TransactionRecord {
        let caller = msg.caller;
        
        if (not containsKey(users, caller)) {
            return null;
        };
        
        switch (properties.get(request.propertyId)) {
            case (?property) {
                let availableTokens = property.totalTokens - property.tokensSold;
                if (availableTokens < request.quantity) {
                    return null;
                };
                
                let totalPrice = Float.fromInt(request.quantity) * property.pricePerToken;
                let transactionId = nextTransactionId;
                nextTransactionId += 1;
                
                let transaction: Types.TransactionRecord = {
                    id = transactionId;
                    tokenId = null;
                    propertyId = request.propertyId;
                    fromUser = null;
                    toUser = ?caller;
                    price = totalPrice;
                    fees = totalPrice * 0.025;
                    timestamp = Time.now();
                    transactionType = #Purchase;
                };
                
                transactions.put(transactionId, transaction);
                
                let updatedProperty = {
                    property with
                    tokensSold = property.tokensSold + request.quantity;
                };
                properties.put(request.propertyId, updatedProperty);
                
                switch (users.get(caller)) {
                    case (?user) {
                        let updatedUser = {
                            user with
                            totalInvested = user.totalInvested + totalPrice;
                            propertyTokensOwned = user.propertyTokensOwned + request.quantity;
                        };
                        users.put(caller, updatedUser);
                    };
                    case null {};
                };
                
                ?transaction
            };
            case null null;
        }
    };

    public func getTransaction(transactionId: Types.TransactionId): async ?Types.TransactionRecord {
        transactions.get(transactionId)
    };

    public func getTransactionsByUser(userId: Types.UserId): async [Types.TransactionRecord] {
        let transactionArray = Iter.toArray(transactions.entries());
        let filteredTransactions = Array.filter<(Types.TransactionId, Types.TransactionRecord)>(transactionArray, func(entry) {
            let transaction = entry.1;
            switch (transaction.fromUser, transaction.toUser) {
                case (?from, _) { Principal.equal(from, userId) };
                case (_, ?to) { Principal.equal(to, userId) };
                case (null, null) { false };
            }
        });
        Array.map<(Types.TransactionId, Types.TransactionRecord), Types.TransactionRecord>(filteredTransactions, func(entry) = entry.1)
    };

    public func getAllTransactions(): async [Types.TransactionRecord] {
        let transactionArray = Iter.toArray(transactions.entries());
        Array.map<(Types.TransactionId, Types.TransactionRecord), Types.TransactionRecord>(transactionArray, func(entry) = entry.1)
    };

    // ========== FUNCIONES DE ESTADÍSTICAS ==========
    
    public func getSystemStats(): async Types.SystemStats {
        var totalValueLocked: Float = 0.0;
        for (property in properties.vals()) {
            totalValueLocked += property.totalValue;
        };
        
        {
            totalProperties = properties.size();
            totalTokens = tokens.size();
            totalTransactions = transactions.size();
            activeUsers = users.size();
            totalValueLocked = totalValueLocked;
            systemUptime = Time.now();
        }
    };

    public func getPropertyStats(propertyId: Types.PropertyId): async ?Types.PropertyStats {
        switch (properties.get(propertyId)) {
            case (?property) {
                var uniqueOwners = 0;
                var ownersSet: [Types.UserId] = [];
                
                let tokenArray = Iter.toArray(tokens.entries());
                let propertyTokens = Array.filter<(Types.TokenId, Types.PropertyToken)>(tokenArray, func(entry) = entry.1.propertyId == propertyId);
                
                for (tokenEntry in propertyTokens.vals()) {
                    let owner = tokenEntry.1.owner;
                    var found = false;
                    for (existingOwner in ownersSet.vals()) {
                        if (Principal.equal(existingOwner, owner)) {
                            found := true;
                        };
                    };
                    if (not found) {
                        ownersSet := Array.append(ownersSet, [owner]);
                        uniqueOwners += 1;
                    };
                };
                
                let averageOwnership = if (uniqueOwners > 0) {
                    Float.fromInt(property.tokensSold) / Float.fromInt(uniqueOwners)
                } else {
                    0.0
                };
                
                let utilizationRate = if (property.totalTokens > 0) {
                    Float.fromInt(property.tokensSold) / Float.fromInt(property.totalTokens)
                } else {
                    0.0
                };
                
                ?{
                    totalTokens = property.totalTokens;
                    tokensIssued = property.tokensIssued;
                    tokensSold = property.tokensSold;
                    uniqueOwners = uniqueOwners;
                    averageOwnership = averageOwnership;
                    totalValueLocked = property.totalValue;
                    utilizationRate = utilizationRate;
                    currentValue = property.totalValue;
                }
            };
            case null null;
        }
    };

    // ========== FUNCIONES DE UTILIDAD ==========
    
    public func getUserCount(): async Nat {
        users.size()
    };

    public func getPropertyCount(): async Nat {
        properties.size()
    };

    public func getTokenCount(): async Nat {
        tokens.size()
    };

    public func getTransactionCount(): async Nat {
        transactions.size()
    };
}