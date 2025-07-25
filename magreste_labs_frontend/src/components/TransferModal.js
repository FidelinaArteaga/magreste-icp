// src/components/TransferModal.js
import React from 'react';
import { Send } from 'lucide-react';

const TransferModal = ({ 
  transferAmount, 
  setTransferAmount, 
  recipientPrincipal, 
  setRecipientPrincipal, 
  maxTokens, 
  onConfirm, 
  onCancel, 
  isLoading 
}) => {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-2xl max-w-md w-full">
        <div className="p-6">
          <h3 className="text-xl font-bold text-gray-900 mb-4">
            Transferir Tokens
          </h3>
          
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Principal de destino
            </label>
            <input
              type="text"
              value={recipientPrincipal}
              onChange={(e) => setRecipientPrincipal(e.target.value)}
              placeholder="rdmx6-jaaaa-aaaah-qcaiq-cai"
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent mb-1"
            />
            <p className="text-xs text-gray-500">
              Ingresa el Principal ID del destinatario
            </p>
          </div>
          
          <div className="mb-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Cantidad a transferir
            </label>
            <input
              type="number"
              min="1"
              max={maxTokens}
              value={transferAmount}
              onChange={(e) => setTransferAmount(Math.max(1, parseInt(e.target.value) || 1))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <p className="text-xs text-gray-500 mt-1">
              Tokens disponibles: {maxTokens}
            </p>
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
              disabled={isLoading || !recipientPrincipal.trim()}
              className="flex-1 bg-gradient-to-r from-green-500 to-green-600 text-white font-semibold py-3 px-4 rounded-lg hover:from-green-600 hover:to-green-700 transition-all duration-200 disabled:opacity-50 flex items-center justify-center gap-2"
            >
              {isLoading ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <Send className="w-5 h-5" />
                  Transferir
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default TransferModal;