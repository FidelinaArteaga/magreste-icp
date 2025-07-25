// src/config/env.js - Variables de entorno
export const config = {
    // Canister IDs - actualizar con tus IDs reales
    BACKEND_CANISTER_ID: process.env.REACT_APP_BACKEND_CANISTER_ID || 'rdmx6-jaaaa-aaaah-qcaiq-cai',
    INTERNET_IDENTITY_CANISTER_ID: process.env.REACT_APP_INTERNET_IDENTITY_CANISTER_ID || 'rdmx6-jaaaa-aaaah-qcaiq-cai',
    
    // Network configuration
    IC_HOST: process.env.NODE_ENV === 'production' 
      ? 'https://ic0.app' 
      : process.env.REACT_APP_IC_HOST || 'http://localhost:4943',
      
    // Identity Provider
    IDENTITY_PROVIDER: process.env.NODE_ENV === 'production'
      ? 'https://identity.ic0.app'
      : process.env.REACT_APP_IDENTITY_PROVIDER || `http://localhost:4943/?canisterId=${process.env.REACT_APP_INTERNET_IDENTITY_CANISTER_ID || 'rdmx6-jaaaa-aaaah-qcaiq-cai'}`,
      
    // DFX Network
    DFX_NETWORK: process.env.REACT_APP_DFX_NETWORK || 'local',
  };