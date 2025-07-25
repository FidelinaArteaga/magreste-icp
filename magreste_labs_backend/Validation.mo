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
            i