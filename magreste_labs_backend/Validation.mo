// Módulo para validaciones de entrada
// Valida datos de propiedades, tokens, pagos, etc.
import Text "mo:base/Text";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Char "mo:base/Char";
import Result "mo:base/Result";
import Types "./Types";

module {
    
    // TIPOS DE ERROR DE VALIDACIÓN
    public type ValidationError = {
        #InvalidFormat : Text;
        #TooShort : { field: Text; minLength: Nat };
        #TooLong : { field: Text; maxLength: Nat };
        #OutOfRange : { field: Text; min: Float; max: Float };
        #Required : Text;
        #InvalidEmail;
        #InvalidPhone;
        #InvalidDate;
        #InvalidPrice;
        #InvalidPercentage;
        #InvalidAddress;
        #InvalidCoordinates;
        #WeakPassword;
        #ProfanityDetected : Text;
        #InvalidFileFormat;
        #FileTooLarge;
        #InvalidURL;
        #InvalidKYCDocument;
        #DuplicateValue : Text;
        #InvalidEnum : { field: Text; validValues: [Text] };
        #CustomError : Text;
    };

    public type ValidationResult<T> = Result.Result<T, ValidationError>;

    // CONSTANTES DE VALIDACIÓN
    private let MIN_PASSWORD_LENGTH = 8;
    private let MAX_PASSWORD_LENGTH = 128;
    private let MIN_NAME_LENGTH = 2;
    private let MAX_NAME_LENGTH = 100;
    private let MAX_DESCRIPTION_LENGTH = 2000;
    private let MAX_ADDRESS_LENGTH = 200;
    private let MIN_PRICE = 0.01;
    private let MAX_PRICE = 999999999.99;
    private let MAX_FILE_SIZE = 10485760; // 10MB
    
    // Palabras prohibidas básicas (puedes expandir esta lista)
    private let PROFANITY_WORDS = [
        "spam", "scam", "fraud", "fake", "illegal", "hack"
    ];

    // CLASE PRINCIPAL DE VALIDACIÓN
    public class ValidationManager() {

        // ========== VALIDACIONES BÁSICAS ==========

        // Validar texto no vacío
        public func validateRequired(value: ?Text, fieldName: Text): ValidationResult<Text> {
            switch (value) {
                case (null) { #err(#Required(fieldName)) };
                case (?text) {
                    if (Text.size(text) == 0) {
                        #err(#Required(fieldName))
                    } else {
                        #ok(text)
                    }
                };
            }
        };

        // Validar longitud de texto
        public func validateLength(text: Text, fieldName: Text, minLength: Nat, maxLength: Nat): ValidationResult<Text> {
            let size = Text.size(text);
            if (size < minLength) {
                #err(#TooShort({ field = fieldName; minLength = minLength }))
            } else if (size > maxLength) {
                #err(#TooLong({ field = fieldName; maxLength = maxLength }))
            } else {
                #ok(text)
            }
        };

        // Validar rango numérico
        public func validateRange(value: Float, fieldName: Text, min: Float, max: Float): ValidationResult<Float> {
            if (value < min or value > max) {
                #err(#OutOfRange({ field = fieldName; min = min; max = max }))
            } else {
                #ok(value)
            }
        };

        // ========== VALIDACIONES ESPECÍFICAS ==========

        // Validar email
        public func validateEmail(email: Text): ValidationResult<Text> {
            if (Text.size(email) == 0) {
                return #err(#Required("email"));
            };
            
            if (not containsChar(email, '@') or not containsChar(email, '.')) {
                return #err(#InvalidEmail);
            };
            
            let parts = Text.split(email, #char '@');
            let partsArray = Iter.toArray(parts);
            
            if (partsArray.size() != 2) {
                return #err(#InvalidEmail);
            };
            
            if (Text.size(partsArray[0]) == 0 or Text.size(partsArray[1]) == 0) {
                return #err(#InvalidEmail);
            };
            
            #ok(email)
        };

        // Validar teléfono
        public func validatePhone(phone: Text): ValidationResult<Text> {
            if (Text.size(phone) == 0) {
                return #err(#Required("phone"));
            };
            
            let cleanPhone = Text.replace(Text.replace(Text.replace(phone, #char ' ', ""), #char '-', ""), #char '(', "");
            let finalPhone = Text.replace(cleanPhone, #char ')', "");
            
            if (Text.size(finalPhone) < 10 or Text.size(finalPhone) > 15) {
                return #err(#InvalidPhone);
            };
            
            if (not isNumeric(finalPhone)) {
                return #err(#InvalidPhone);
            };
            
            #ok(phone)
        };

        // Validar contraseña
        public func validatePassword(password: Text): ValidationResult<Text> {
            switch (validateLength(password, "password", MIN_PASSWORD_LENGTH, MAX_PASSWORD_LENGTH)) {
                case (#err(error)) { #err(error) };
                case (#ok(_)) {
                    if (not hasUppercase(password) or 
                        not hasLowercase(password) or 
                        not hasNumber(password)) {
                        #err(#WeakPassword)
                    } else {
                        #ok(password)
                    }
                };
            }
        };

        // Validar precio
        public func validatePrice(price: Float): ValidationResult<Float> {
            if (price <= 0.0) {
                return #err(#InvalidPrice);
            };
            validateRange(price, "price", MIN_PRICE, MAX_PRICE)
        };

        // Validar porcentaje
        public func validatePercentage(percentage: Float): ValidationResult<Float> {
            validateRange(percentage, "percentage", 0.0, 100.0)
        };

        // Validar coordenadas
        public func validateCoordinates(lat: Float, lng: Float): ValidationResult<(Float, Float)> {
            switch (validateRange(lat, "latitude", -90.0, 90.0)) {
                case (#err(error)) { #err(error) };
                case (#ok(_)) {
                    switch (validateRange(lng, "longitude", -180.0, 180.0)) {
                        case (#err(error)) { #err(error) };
                        case (#ok(_)) { #ok((lat, lng)) };
                    }
                };
            }
        };

        // Validar URL
        public func validateURL(url: Text): ValidationResult<Text> {
            if (Text.size(url) == 0) {
                return #err(#Required("url"));
            };
            
            if (not Text.startsWith(url, #text "http://") and 
                not Text.startsWith(url, #text "https://")) {
                return #err(#InvalidURL);
            };
            
            #ok(url)
        };

        // ========== VALIDACIONES DE NEGOCIO ==========

        // Validar datos de propiedad
        public func validatePropertyData(data: Types.PropertyData): ValidationResult<Types.PropertyData> {
            // Validar nombre
            switch (validateRequired(?data.name, "name")) {
                case (#err(error)) { return #err(error) };
                case (#ok(name)) {
                    switch (validateLength(name, "name", MIN_NAME_LENGTH, MAX_NAME_LENGTH)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            // Validar descripción
            switch (validateRequired(?data.description, "description")) {
                case (#err(error)) { return #err(error) };
                case (#ok(description)) {
                    switch (validateLength(description, "description", 10, MAX_DESCRIPTION_LENGTH)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            // Validar dirección
            switch (validateRequired(?data.location.address, "address")) {
                case (#err(error)) { return #err(error) };
                case (#ok(address)) {
                    switch (validateLength(address, "address", 10, MAX_ADDRESS_LENGTH)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            // Validar coordenadas
            switch (validateCoordinates(data.location.coordinates.lat, data.location.coordinates.lng)) {
                case (#err(error)) { return #err(error) };
                case (#ok(_)) {};
            };

            // Validar precio total
            switch (validatePrice(data.totalValue)) {
                case (#err(error)) { return #err(error) };
                case (#ok(_)) {};
            };

            // Validar precio por token
            switch (validatePrice(data.pricePerToken)) {
                case (#err(error)) { return #err(error) };
                case (#ok(_)) {};
            };

            // Validar rentabilidad esperada
            switch (validatePercentage(data.expectedAnnualReturn)) {
                case (#err(error)) { return #err(error) };
                case (#ok(_)) {};
            };

            // Validar que el precio total sea consistente
            let calculatedTotal = data.pricePerToken * Float.fromInt(data.totalTokens);
            if (Float.abs(data.totalValue - calculatedTotal) > 0.01) {
                return #err(#CustomError("Price per token doesn't match total value"));
            };

            // Validar profanidad
            switch (checkProfanity(data.name # " " # data.description)) {
                case (#err(error)) { return #err(error) };
                case (#ok(_)) {};
            };

            #ok(data)
        };

        // Validar datos de usuario
        public func validateUserRegistration(userData: Types.UserRegistrationData): ValidationResult<Types.UserRegistrationData> {
            // Validar nombre
            switch (validateRequired(?userData.firstName, "firstName")) {
                case (#err(error)) { return #err(error) };
                case (#ok(firstName)) {
                    switch (validateLength(firstName, "firstName", MIN_NAME_LENGTH, MAX_NAME_LENGTH)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            // Validar apellido
            switch (validateRequired(?userData.lastName, "lastName")) {
                case (#err(error)) { return #err(error) };
                case (#ok(lastName)) {
                    switch (validateLength(lastName, "lastName", MIN_NAME_LENGTH, MAX_NAME_LENGTH)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            // Validar email
            switch (validateEmail(userData.email)) {
                case (#err(error)) { return #err(error) };
                case (#ok(_)) {};
            };

            // Validar teléfono si está presente
            switch (userData.phone) {
                case (null) {};
                case (?phone) {
                    switch (validatePhone(phone)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            // Validar contraseña si está presente
            switch (userData.password) {
                case (null) {};
                case (?password) {
                    switch (validatePassword(password)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            #ok(userData)
        };

        // Validar transacción
        public func validateTransaction(transaction: Types.TransactionData): ValidationResult<Types.TransactionData> {
            // Validar cantidad
            if (transaction.amount <= 0.0) {
                return #err(#InvalidPrice);
            };

            // Validar cantidad de tokens
            if (transaction.tokenAmount <= 0) {
                return #err(#OutOfRange({ field = "tokenAmount"; min = 1.0; max = 999999.0 }));
            };

            // Validar timestamp
            let now = Time.now();
            if (transaction.timestamp > now) {
                return #err(#InvalidDate);
            };

            // Validar que la cantidad sea consistente con el precio por token
            let expectedAmount = transaction.pricePerToken * Float.fromInt(transaction.tokenAmount);
            if (Float.abs(transaction.amount - expectedAmount) > 0.01) {
                return #err(#CustomError("Transaction amount doesn't match token price"));
            };

            #ok(transaction)
        };

        // Validar documento KYC
        public func validateKYCDocument(document: Types.KYCDocument): ValidationResult<Types.KYCDocument> {
            // Validar tipo de documento
            let validTypes = ["passport", "nationalId", "driverLicense"];
            if (not arrayContains(validTypes, document.documentType)) {
                return #err(#InvalidEnum({ 
                    field = "documentType"; 
                    validValues = validTypes 
                }));
            };

            // Validar número de documento
            switch (validateRequired(?document.documentNumber, "documentNumber")) {
                case (#err(error)) { return #err(error) };
                case (#ok(docNum)) {
                    switch (validateLength(docNum, "documentNumber", 5, 50)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            // Validar fecha de emisión
            if (document.issueDate > Time.now()) {
                return #err(#InvalidDate);
            };

            // Validar fecha de expiración
            if (document.expiryDate <= Time.now()) {
                return #err(#CustomError("Document is expired"));
            };

            // Validar país
            switch (validateRequired(?document.country, "country")) {
                case (#err(error)) { return #err(error) };
                case (#ok(country)) {
                    switch (validateLength(country, "country", 2, 50)) {
                        case (#err(error)) { return #err(error) };
                        case (#ok(_)) {};
                    };
                };
            };

            #ok(document)
        };

        // ========== FUNCIONES AUXILIARES ==========

        // Verificar si contiene un carácter
        private func containsChar(text: Text, char: Char): Bool {
            for (c in text.chars()) {
                if (c == char) return true;
            };
            false
        };

        // Verificar si es numérico
        private func isNumeric(text: Text): Bool {
            for (c in text.chars()) {
                if (not Char.isDigit(c) and c != '+') {
                    return false;
                };
            };
            true
        };

        // Verificar mayúsculas
        private func hasUppercase(text: Text): Bool {
            for (c in text.chars()) {
                if (Char.isUppercase(c)) return true;
            };
            false
        };

        // Verificar minúsculas
        private func hasLowercase(text: Text): Bool {
            for (c in text.chars()) {
                if (Char.isLowercase(c)) return true;
            };
            false
        };

        // Verificar números
        private func hasNumber(text: Text): Bool {
            for (c in text.chars()) {
                if (Char.isDigit(c)) return true;
            };
            false
        };

        // Verificar profanidad
        private func checkProfanity(text: Text): ValidationResult<Text> {
            let lowerText = Text.toLowercase(text);
            for (word in PROFANITY_WORDS.vals()) {
                if (Text.contains(lowerText, #text word)) {
                    return #err(#ProfanityDetected(word));
                };
            };
            #ok(text)
        };

        // Verificar si array contiene elemento
        private func arrayContains(arr: [Text], element: Text): Bool {
            for (item in arr.vals()) {
                if (item == element) return true;
            };
            false
        };

        // ========== VALIDACIONES COMPUESTAS ==========

        // Validar múltiples campos a la vez
        public func validateMultiple<T>(validations: [(Text, ValidationResult<T>)]): ValidationResult<()> {
            for ((fieldName, result) in validations.vals()) {
                switch (result) {
                    case (#err(error)) { return #err(error) };
                    case (#ok(_)) {};
                };
            };
            #ok(())
        };

        // Función auxiliar para unir valores de array
        private func joinArray(arr: [Text], separator: Text): Text {
            if (arr.size() == 0) {
                return "";
            };
            if (arr.size() == 1) {
                return arr[0];
            };
            
            var result = arr[0];
            var i = 1;
            while (i < arr.size()) {
                result := result # separator # arr[i];
                i += 1;
            };
            result
        };

        // Formatear error para mostrar al usuario
        public func formatError(error: ValidationError): Text {
            switch (error) {
                case (#InvalidFormat(msg)) { "Invalid format: " # msg };
                case (#TooShort({ field; minLength })) { 
                    field # " must be at least " # Nat.toText(minLength) # " characters" 
                };
                case (#TooLong({ field; maxLength })) { 
                    field # " must be at most " # Nat.toText(maxLength) # " characters" 
                };
                case (#OutOfRange({ field; min; max })) { 
                    field # " must be between " # Float.toText(min) # " and " # Float.toText(max) 
                };
                case (#Required(field)) { field # " is required" };
                case (#InvalidEmail) { "Invalid email format" };
                case (#InvalidPhone) { "Invalid phone number format" };
                case (#InvalidDate) { "Invalid date" };
                case (#InvalidPrice) { "Invalid price" };
                case (#InvalidPercentage) { "Percentage must be between 0 and 100" };
                case (#InvalidAddress) { "Invalid address format" };
                case (#InvalidCoordinates) { "Invalid coordinates" };
                case (#WeakPassword) { "Password must contain uppercase, lowercase, and numbers" };
                case (#ProfanityDetected(word)) { "Inappropriate content detected" };
                case (#InvalidFileFormat) { "Invalid file format" };
                case (#FileTooLarge) { "File is too large" };
                case (#InvalidURL) { "Invalid URL format" };
                case (#InvalidKYCDocument) { "Invalid KYC document" };
                case (#DuplicateValue(field)) { field # " already exists" };
                case (#InvalidEnum({ field; validValues })) { 
                    let validValuesText = joinArray(validValues, ", ");
                    field # " must be one of: " # validValuesText
                };
                case (#CustomError(msg)) { msg };
            }
        };

        // ========== UTILIDADES ADICIONALES ==========

      // Función sanitizeText simplificada
        public func sanitizeText(text: Text): Text {
            text // devuelve el texto sin modificar por ahora
        };

        //// Función truncateText simplificada
        public func truncateText(text: Text, maxLength: Nat): Text {
            text  // devuelve el texto sin modificar por ahora
        };

    }; // <- Esta llave cierra la clase ValidationManager
} // <- Esta llave cierra el módulo