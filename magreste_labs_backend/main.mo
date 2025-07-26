import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";

// Import your modules
import Types "Types";
import Authentication "Authentication";
import PropertyManager "PropertyManager"; 
import TokenManager "TokenManager";
import TransactionManager "TransactionManager";
import PaymentManager "PaymentManager";
import Validation "Validation";
import Events "Events";
import Utils "Utils";

actor MagresteLabs {
    // Type aliases for cleaner code
    type Result<T, E> = Result.Result<T, E>;
    type UserId = Types.UserId;
    type PropertyId = Types.PropertyId;
    type TokenId = Types.TokenId;
    type TransactionId = Types.TransactionId;
    type SystemError = Types.SystemError;
    type Property = Types.Property;
    type PropertyToken = Types.PropertyToken;
    type User = Types.User;
    type TransactionRecord = Types.TransactionRecord;
    type PaymentRecord = Types.PaymentRecord;
    type PurchaseRequest = Types.PurchaseRequest;
    type PropertyType = Types.PropertyType;
    type Location = Types.Location;

    // Stable variables for upgrade persistence
    private stable var userEntries : [(Principal, User)] = [];
    private stable var propertyEntries : [(Text, Property)] = [];
    private stable var tokenEntries : [(Text, PropertyToken)] = [];
    private stable var transactionEntries : [(Text, TransactionRecord)] = [];

    // Initialize managers
    private var authentication = Authentication.Authentication(HashMap.fromIter<Principal, User>(userEntries.vals(), 10, Principal.equal, Principal.hash));
    private var propertyManager = PropertyManager.PropertyManager(HashMap.fromIter<Text, Property>(propertyEntries.vals(), 10, Text.equal, Text.hash));
    private var tokenManager = TokenManager.TokenManager(HashMap.fromIter<Text, PropertyToken>(tokenEntries.vals(), 10, Text.equal, Text.hash));
    private var transactionManager = TransactionManager.TransactionManager(HashMap.fromIter<Text, TransactionRecord>(transactionEntries.vals(), 10, Text.equal, Text.hash));
    private var paymentManager = PaymentManager.PaymentManager();

    // System upgrade hooks
    system func preupgrade() {
        userEntries := authentication.getEntries();
        propertyEntries := propertyManager.getEntries();
        tokenEntries := tokenManager.getEntries();
        transactionEntries := transactionManager.getEntries();
    };

    system func postupgrade() {
        userEntries := [];
        propertyEntries := [];
        tokenEntries := [];
        transactionEntries := [];
    };

    // Helper function to convert validation errors to system errors
    private func convertValidationError(error: Validation.ValidationError) : SystemError {
        switch (error) {
            case (#Required(field)) { #ValidationError("Required field: " # field) };
            case (#TooLong({field; maxLength})) { #ValidationError("Field " # field # " too long, max: " # Nat.toText(maxLength)) };
            case (#TooShort({field; minLength})) { #ValidationError("Field " # field # " too short, min: " # Nat.toText(minLength)) };
            case (#InvalidFormat(msg)) { #ValidationError("Invalid format: " # msg) };
            case (#InvalidEmail) { #ValidationError("Invalid email format") };
            case (#InvalidPhone) { #ValidationError("Invalid phone format") };
            case (#InvalidURL) { #ValidationError("Invalid URL format") };
            case (#InvalidPrice) { #ValidationError("Invalid price") };
            case (#InvalidPercentage) { #ValidationError("Invalid percentage") };
            case (#InvalidDate) { #ValidationError("Invalid date") };
            case (#InvalidAddress) { #ValidationError("Invalid address") };
            case (#InvalidCoordinates) { #ValidationError("Invalid coordinates") };
            case (#OutOfRange({field; min; max})) { #ValidationError("Field " # field # " out of range") };
            case (#DuplicateValue(field)) { #ValidationError("Duplicate value in field: " # field) };
            case (#WeakPassword) { #ValidationError("Password too weak") };
            case (#ProfanityDetected(field)) { #ValidationError("Inappropriate content in field: " # field) };
            case (#FileTooLarge) { #ValidationError("File too large") };
            case (#InvalidFileFormat) { #ValidationError("Invalid file format") };
            case (#InvalidKYCDocument) { #ValidationError("Invalid KYC document") };
            case (#InvalidEnum({field; validValues})) { #ValidationError("Invalid enum value for field: " # field) };
            case (#CustomError(msg)) { #ValidationError(msg) };
        }
    };

    // Helper function to require user registration
    private func requireRegistration(userId: Principal) : Result<User, SystemError> {
        switch (authentication.getUser(userId)) {
            case (#ok(user)) { #ok(user) };
            case (#err(_)) { #err(#UserNotFound) };
        }
    };

    // PROPERTY MANAGEMENT

    public query func getProperties() : async Result<[Property], SystemError> {
        let properties = propertyManager.getActiveProperties();
        #ok(properties)
    };

    public query func getUserPropertiesByOwner(userId: Principal) : async [Property] {
        propertyManager.getPropertiesByOwner(userId)
    };

    public query func getProperty(propertyId: PropertyId) : async Result<Property, SystemError> {
        propertyManager.getProperty(propertyId)
    };

    public func createProperty(
        name: Text,
        description: Text,
        location: Text, // Simplified - you may want to parse this into Location type
        totalTokens: Nat,
        ownerId: Principal,
        imageUrl: ?Text,
        propertyTypeStr: Text,
        squareMeters: ?Nat,
        estimatedValue: ?Nat
    ) : async Result<PropertyId, SystemError> {
        // Validate user exists
        switch (requireRegistration(ownerId)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        // Validate input
        let validationResult = Validation.validatePropertyData({
            name = name;
            description = description;
            location = { city = location; country = ""; coordinates = null }; // Simplified
            totalTokens = totalTokens;
            pricePerToken = 100.0; // Default value
            expectedAnnualReturn = 8.0; // Default value
            propertyType = #Residential; // Default - parse propertyTypeStr if needed
            squareMeters = squareMeters;
            imageUrls = switch (imageUrl) { case (?url) [url]; case null [] };
            totalValue = Float.fromInt(Int.abs(totalTokens * 100)); // Calculate from tokens and price
        });

        switch (validationResult) {
            case (#err(validationError)) { 
                return #err(convertValidationError(validationError))
            };
            case (#ok(_)) {};
        };

        // Create property
        propertyManager.createProperty(
            name,
            description, 
            location,
            totalTokens,
            ownerId,
            imageUrl,
            propertyTypeStr,
            squareMeters,
            estimatedValue
        )
    };

    // TOKEN MANAGEMENT

    public query func getPropertyTokens(propertyId: PropertyId) : async Result<[PropertyToken], SystemError> {
        let tokens = tokenManager.getTokensByProperty(propertyId);
        #ok(tokens)
    };

    public query func getUserTokens(userId: Principal) : async Result<[PropertyToken], SystemError> {
        let tokens = tokenManager.getUserPropertyTokens(userId);
        #ok(tokens)
    };

    public query func getToken(tokenId: TokenId) : async Result<PropertyToken, SystemError> {
        switch (tokenManager.getPropertyToken(tokenId)) {
            case (?token) { #ok(token) };
            case null { #err(#TokenNotFound) };
        }
    };

    public func createPropertyTokens(propertyId: PropertyId, quantity: Nat) : async Result<[TokenId], SystemError> {
        // Validate property exists
        switch (propertyManager.getProperty(propertyId)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        tokenManager.mintPropertyTokens(propertyId, quantity)
    };

    // TRANSACTION MANAGEMENT

    public func purchaseTokens(propertyId: PropertyId, quantity: Nat) : async Result<TransactionId, SystemError> {
        let userId = Principal.fromActor(MagresteLabs); // Get caller principal in real implementation
        
        // Validate user registration
        switch (requireRegistration(userId)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        // Create purchase transaction record
        let tokenIds = []; // In real implementation, you'd assign specific token IDs
        let totalAmount = Float.fromInt(Int.abs(quantity * 100)); // Calculate based on token price
        
        transactionManager.recordPurchaseTransaction(propertyId, tokenIds, userId, totalAmount)
    };

    public func transferToken(tokenId: TokenId, fromUser: Principal, toUser: Principal) : async Result<TransactionId, SystemError> {
        // Validate both users exist
        switch (requireRegistration(fromUser)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };
        
        switch (requireRegistration(toUser)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        // Get token info
        switch (tokenManager.getPropertyToken(tokenId)) {
            case null { return #err(#TokenNotFound) };
            case (?token) {
                transactionManager.recordTransferTransaction(
                    token.propertyId, 
                    tokenId, 
                    fromUser, 
                    toUser, 
                    token.currentValue
                )
            };
        }
    };

    public query func getTransactionHistory(userId: Principal, limit: ?Nat, offset: ?Nat) : async Result<[TransactionRecord], SystemError> {
        transactionManager.getUserTransactions(userId, limit, offset)
    };

    public query func getTransaction(transactionId: TransactionId) : async Result<TransactionRecord, SystemError> {
        switch (transactionManager.getTransaction(transactionId)) {
            case (?transaction) { #ok(transaction) };
            case null { #err(#TransactionNotFound) };
        }
    };

    // PAYMENT MANAGEMENT

    public func createPurchaseRequest(userId: Principal, request: PurchaseRequest) : async Result<Nat, SystemError> {
        // Validate user registration
        switch (requireRegistration(userId)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        paymentManager.createPaymentRequest(userId, request)
    };

    public query func getPaymentStatus(paymentId: Nat) : async Result<PaymentRecord, SystemError> {
        paymentManager.getPaymentStatus(paymentId)
    };

    public query func getUserPayments(userId: Principal) : async [PaymentRecord] {
        paymentManager.getUserPayments(userId)
    };

    // USER MANAGEMENT

    public func registerUser(userData: {
        email: Text;
        firstName: Text; 
        lastName: Text;
        password: ?Text;
        phone: ?Text;
    }) : async Result<User, SystemError> {
        let userId = Principal.fromActor(MagresteLabs); // Get caller principal in real implementation
        
        switch (authentication.createUser(userId, userData.firstName, userData.lastName, userData.email)) {
            case (#ok(user)) { #ok(user) };
            case (#err(error)) { #err(error) };
        }
    };

    public query func getUserProfile(userId: Principal) : async Result<User, SystemError> {
        switch (authentication.getUser(userId)) {
            case (#ok(user)) { #ok(user) };
            case (#err(_)) { #err(#UserNotFound) };
        }
    };

    public func updateProfile(userId: Principal, updates: {
        name: ?Text;
        email: ?Text;
        phone: ?Text;
        country: ?Text;
    }) : async Result<(), SystemError> {
        // In a real implementation, you'd have an updateUserProfile method
        // For now, return success if user exists
        switch (requireRegistration(userId)) {
            case (#err(error)) { #err(error) };
            case (#ok(_)) { #ok(()) };
        }
    };

    // ADMIN/STATS FUNCTIONS

    public query func getSystemStats() : async {
        totalUsers: Nat;
        totalProperties: Nat;
        totalTransactions: Nat;
        totalTokensIssued: Nat;
    } {
        let userStats = authentication.getUserStats();
        let propertyStats = propertyManager.getPropertyStats();
        let transactionStats = transactionManager.getTransactionStats();
        
        {
            totalUsers = userStats.totalUsers;
            totalProperties = propertyStats.totalProperties;
            totalTransactions = transactionStats.totalTransactions;
            totalTokensIssued = propertyStats.totalTokensIssued;
        }
    };

    public query func healthCheck() : async Bool {
        true
    };
}