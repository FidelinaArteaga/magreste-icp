// src/components/PurchaseModal.js
import React from 'react';
import { ShoppingCart } from 'lucide-react';

const PurchaseModal = ({ 
  property, 
  purchaseAmount, 
  setPurchaseAmount, 
  onConfirm, 
  onCancel, 
  isLoading 
}) => {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-2xl max-w-md w-full">
        <div className="p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-4">
            Comprar Tokens - {property.title}
          </h3>
          
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Cantidad de Tokens
            </label>
            <input
              type="number"
              min="1"
              max={property.availableTokens}
              value={purchaseAmount}
              onChange={(e) => setPurchaseAmount(Math.max(1, parseInt(e.target.value) || 1))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <p className="text-xs text-gray-500 mt-1">
              Máximo disponible: {property.availableTokens.toLocaleString()}
            </p>
          </div>

          <div className="bg-gray-50 rounded-lg p-4 mb-6">
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600">Precio por token</span>
              <span className="font-semibold">${property.tokenPrice}</span>
            </div>
            <div className="flex justify-between items-center mb-2">
              <span className="text-sm text-gray-600">Cantidad</span>
              <span className="font-semibold">{purchaseAmount}</span>
            </div>
            <div className="border-t pt-2">
              <div className="flex justify-between items-center">
                <span className="font-medium">Total</span>
                <span className="font-bold text-lg text-blue-600">
                  ${(property.tokenPrice * purchaseAmount).toLocaleString()}
                </span>
              </div>
            </div>
          </div>

          <div className="flex gap-3">
            <button
              onClick={onCancel}
              disabled={isLoading}
              className="flex-1 border border-gray-300 text-gray-700 font-semibold py-3 px-4 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50"
            >
              Cancelar
            </button>
            <button
              onClick={onConfirm}
              disabled={isLoading}
              className="flex-1 bg-gradient-to-r from-blue-500 to-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:from-blue-600 hover:to-indigo-700 transition-all duration-200 disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {isLoading ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <ShoppingCart className="w-5 h-5" />
                  Comprar
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default PurchaseModal;