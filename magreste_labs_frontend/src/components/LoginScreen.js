// src/components/LoginScreen.js
import React from 'react';
import { Home, User } from 'lucide-react';

const LoginScreen = ({ onConnect, isLoading }) => {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
      <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md w-full mx-4">
        <div className="text-center">
          <div className="w-16 h-16 bg-gradient-to-r from-blue-500 to-indigo-600 rounded-full flex items-center justify-center mx-auto mb-6">
            <Home className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900 mb-2">RealToken ICP</h1>
          <p className="text-gray-600 mb-8">Tokenización de Activos Inmobiliarios</p>
          
          <button
            onClick={onConnect}
            disabled={isLoading}
            className="w-full bg-gradient-to-r from-blue-500 to-indigo-600 text-white font-semibold py-3 px-6 rounded-lg hover:from-blue-600 hover:to-indigo-700 transition-all duration-200 disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {isLoading ? (
              <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <>
                <User className="w-5 h-5" />
                Conectar con Internet Identity
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

export default LoginScreen;