// src/components/Header.js
import React from 'react';
import { Home, Coins, LogOut } from 'lucide-react';

const Header = ({ principal, totalTokens, onDisconnect }) => {
  return (
    <header className="bg-white shadow-sm border-b">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-indigo-600 rounded-lg flex items-center justify-center">
              <Home className="w-5 h-5 text-white" />
            </div>
            <h1 className="text-xl font-bold text-gray-900">RealToken ICP</h1>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2 bg-blue-50 px-4 py-2 rounded-lg">
              <Coins className="w-5 h-5 text-blue-600" />
              <span className="font-semibold text-blue-900">{totalTokens} Tokens</span>
            </div>
            
            <div className="text-sm text-gray-600">
              Principal: {principal ? principal.slice(0, 8) + '...' : ''}
            </div>
            
            <button
              onClick={onDisconnect}
              className="text-gray-500 hover:text-gray-700 p-2 rounded-lg hover:bg-gray-100 transition-colors"
              title="Desconectar"
            >
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;