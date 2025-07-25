// Types.mo
// Definiciones de tipos para el sistema de tokenización de inmuebles

import Principal "mo:base/Principal";

module {
    // ========== TIPOS BÁSICOS ==========
    public type TokenId = Nat;
    public type PropertyId = Nat;
    public type UserId = Principal;
    public type TransactionId = Nat;
    
    // ========== TIPOS DE PROPIEDADES ==========
    
    // Coordenadas geográficas
    public type Coordinates = {
        lat: Float;
        lng: Float;
    };
    
    // Ubicación de la propiedad
    public type Location = {
        address: Text;
        city: Text;
        state: Text;
        country: Text;
        zipCode: Text;
        coordinates: Coordinates;
    };
    
    // Datos de entrada para crear una propiedad
    public type PropertyData = {
        name: Text;
        description: Text;
        location: Location;
        totalValue: Float;
        pricePerToken: Float;
        totalTokens: Nat;
        expectedAnnualReturn: Float;
        propertyType: PropertyType;
        squareMeters: ?Nat;
        imageUrls: [Text];
    };
    
    // Tipo de propiedad
    public type PropertyType = {
        #Residential;
        #Commercial;
        #Industrial;
        #Mixed;
    };
    
    // Propiedad completa
    public type Property = {
        id: PropertyId;
        name: Text;
        description: Text;
        location: Location;
        totalValue: Float;
        pricePerToken: Float;
        totalTokens: Nat;
        tokensIssued: Nat;
        tokensSold: Nat;
        expectedAnnualReturn: Float;
        propertyType: PropertyType;
        squareMeters: ?Nat;
        imageUrls: [Text];
        isActive: Bool;
        createdAt: Int;
        owner: UserId;
    };
    
    // ========== TIPOS DE TOKENS ==========
    
    // Token de propiedad
    public type PropertyToken = {
        id: TokenId;
        propertyId: PropertyId;
        owner: UserId;
        price: Float;
        createdAt: Int;
        canTransfer: Bool;
        transferEnabledAt: Int;
        metadata: ?Text;
    };
    
    // Token de utilidad
    public type UtilityToken = {
        id: TokenId;
        propertyId: PropertyId;
        owner: UserId;
        createdAt: Int;
        expiresAt: Int;
        isValid: Bool;
        utilizationCount: Nat;
        maxUtilizations: Nat;
    };
    
    // ========== TIPOS DE TRANSACCIONES ==========
    
    // Tipos de transacciones
    public type TransactionType = {
        #Mint;
        #Purchase;
        #Transfer;
        #UtilityGeneration;
    };
    
    // Registro de transacción
    public type TransactionRecord = {
        id: TransactionId;
        tokenId: ?TokenId;
        propertyId: PropertyId;
        fromUser: ?UserId;
        toUser: ?UserId;
        price: Float;
        fees: Float;
        timestamp: Int;
        transactionType: TransactionType;
    };
    
    // Datos de transacción para validación
    public type TransactionData = {
        amount: Float;
        tokenAmount: Nat;
        pricePerToken: Float;
        timestamp: Int;
    };
    
    // ========== TIPOS DE PAGOS ==========
    
    // Métodos de pago
    public type PaymentMethod = {
        #ICP;
        #USDC;
        #USDT;
        #BTC;
        #ETH;
    };
    
    // Solicitud de compra
    public type PurchaseRequest = {
        propertyId: PropertyId;
        quantity: Nat;
        paymentAmount: Float;
        paymentMethod: PaymentMethod;
    };
    
    // Estado del pago
    public type PaymentStatus = {
        #Pending;
        #Confirmed;
        #Failed;
        #Refunded;
    };
    
    // Registro de pago
    public type PaymentRecord = {
        id: Nat;
        transactionId: TransactionId;
        amount: Float;
        method: PaymentMethod;
        status: PaymentStatus;
        timestamp: Int;
        confirmationHash: ?Text;
    };
    
    // ========== TIPOS DE USUARIOS ==========
    
    // Datos de registro de usuario
    public type UserRegistrationData = {
        firstName: Text;
        lastName: Text;
        email: Text;
        phone: ?Text;
        password: ?Text;
    };
    
    // Perfil de usuario
    public type UserProfile = {
        id: UserId;
        firstName: Text;
        lastName: Text;
        email: Text;
        phone: ?Text;
        propertyTokensOwned: Nat;
        utilityTokensOwned: Nat;
        totalInvested: Float;
        joinedAt: Int;
        lastActivity: Int;
        isVerified: Bool;
        kycStatus: KYCStatus;
    };
    
    // ========== TIPOS DE KYC ==========
    
    // Estado de KYC
    public type KYCStatus = {
        #NotStarted;
        #Pending;
        #Approved;
        #Rejected;
        #RequiresUpdate;
    };
    
    // Documento KYC
    public type KYCDocument = {
        documentType: Text;
        documentNumber: Text;
        issueDate: Int;
        expiryDate: Int;
        country: Text;
        documentUrl: ?Text;
    };
    
    // ========== TIPOS DE AUTENTICACIÓN ==========
    
    // Roles de usuario
    public type UserRole = {
        #Owner;
        #Admin;
        #PropertyOwner;
        #Investor;
        #Viewer;
        #Suspended;
    };
    
    // Permisos del sistema
    public type Permission = {
        #SystemManagement;
        #UserManagement;
        #PropertyManagement;
        #TokenManagement;
        #PaymentManagement;
        #ViewSensitiveData;
        #ViewPublicData;
        #EmergencyActions;
    };
    
    // Sesión de usuario
    public type UserSession = {
        userId: UserId;
        sessionToken: Text;
        createdAt: Int;
        expiresAt: Int;
        isActive: Bool;
    };
    
    // ========== TIPOS DE EVENTOS DEL SISTEMA ==========
    
    // Tipos de eventos
    public type SystemEventType = {
        #SystemConfigUpdated;
        #PropertyCreated;
        #TokensMinted;
        #TokensPurchased;
        #TokenTransferred;
        #UtilityTokenGenerated;
        #PaymentProcessed;
        #MaintenancePerformed;
        #UserRegistered;
        #KYCUpdated;
    };
    
    // Evento del sistema
    public type SystemEvent = {
        id: Nat;
        eventType: SystemEventType;
        description: Text;
        userId: ?UserId;
        timestamp: Int;
    };
    
    // ========== TIPOS DE ESTADÍSTICAS ==========
    
    // Estadísticas de propiedad
    public type PropertyStats = {
        totalTokens: Nat;
        tokensIssued: Nat;
        tokensSold: Nat;
        uniqueOwners: Nat;
        averageOwnership: Float;
        totalValueLocked: Float;
        utilizationRate: Float;
        currentValue: Float;
    };
    
    // Estadísticas del sistema
    public type SystemStats = {
        totalProperties: Nat;
        totalTokens: Nat;
        totalTransactions: Nat;
        activeUsers: Nat;
        totalValueLocked: Float;
        systemUptime: Int;
    };
    
    // ========== TIPOS DE INFORMACIÓN DEL SISTEMA ==========
    
    // Información general del sistema
    public type SystemInfo = {
        isInitialized: Bool;
        isPaused: Bool;
        contractOwner: Principal;
        totalEvents: Nat;
        activeUsers: Nat;
        systemUptime: Int;
    };
    
    // Estado de salud del sistema
    public type HealthStatus = {
        timestamp: Int;
        isHealthy: Bool;
        managers: {
            propertyManager: Bool;
            tokenManager: Bool;
            transactionManager: Bool;
            paymentManager: Bool;
            authManager: Bool;
        };
        activeConnections: Nat;
    };
    
    // Configuración del sistema
    public type SystemConfiguration = {
        contractOwner: Principal;
        isInitialized: Bool;
        isPaused: Bool;
        maxEventsStored: Nat;
        eventRetentionDays: Nat;
        maintenanceMode: Bool;
    };
    
    // ========== TIPOS DE CONFIGURACIÓN ==========
    
    // Configuración del sistema
    public type SystemConfig = {
        tokenPriceUSD: Float;
        transferLockPeriod: Int;
        utilityTokenValidity: Int;
        utilityTokenThreshold: Float;
        maxTokensPerProperty: Nat;
        minTokensPerProperty: Nat;
        transactionFeeRate: Float;
        maxSessionDuration: Int;
        maxSessionsPerUser: Nat;
    };
    
    // ========== TIPOS DE ERRORES ==========
    
    // Errores del sistema
    public type SystemError = {
        #PropertyNotFound;
        #TokenNotFound;
        #UserNotFound;
        #TransactionNotFound;
        #InsufficientBalance;
        #InsufficientTokens;
        #TransferLocked;
        #NotAuthorized;
        #InvalidPayment;
        #TokensUnavailable;
        #UtilityTokenExists;
        #UtilityTokenExpired;
        #InvalidQuantity;
        #PropertyInactive;
        #SystemPaused;
        #NotInitialized;
        #AlreadyInitialized;
        #InvalidInput: Text;
        #ValidationError: Text;
        #KYCRequired;
        #KYCPending;
        #SessionExpired;
        #SessionNotFound;
        #TooManySessions;
        #SystemError: Text;
    };
    
    // ========== TIPOS DE RESULTADOS ==========
    
    // Resultado de operaciones
    public type OperationResult<T> = {
        #success: T;
        #error: SystemError;
    };
    
    // Resultado de búsqueda paginada
    public type PaginatedResult<T> = {
        data: [T];
        total: Nat;
        page: Nat;
        pageSize: Nat;
        hasNext: Bool;
        hasPrev: Bool;
    };
    
    // ========== TIPOS DE FILTROS Y BÚSQUEDA ==========
    
    // Filtros para propiedades
    public type PropertyFilter = {
        propertyType: ?PropertyType;
        minPrice: ?Float;
        maxPrice: ?Float;
        location: ?Text;
        isActive: ?Bool;
        hasAvailableTokens: ?Bool;
    };
    
    // Parámetros de ordenamiento
    public type SortOrder = {
        #Ascending;
        #Descending;
    };
    
    public type PropertySortBy = {
        #CreatedAt;
        #Name;
        #Price;
        #TokensAvailable;
        #ExpectedReturn;
    };
    
    // Parámetros de paginación
    public type PaginationParams = {
        page: Nat;
        pageSize: Nat;
        sortBy: ?PropertySortBy;
        sortOrder: ?SortOrder;
    };
}