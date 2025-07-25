// src/components/PropertyCard.js
import React from 'react';
import { MapPin, Bed, Bath, Square, ShoppingCart, Send } from 'lucide-react';

const PropertyCard = ({ property, userTokens, onBuyClick, onTransferClick }) => {
  const getStatusColor = (status) => {
    switch (status) {
      case 'disponible': return 'text-green-600 bg-green-100';
      case 'en_construccion': 
      case 'en construcción': return 'text-orange-600 bg-orange-100';
      case 'agotado': return 'text-red-600 bg-red-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  const formatStatus = (status) => {
    if (status === 'en_construccion') return 'en construcción';
    return status;
  };

  return (
    <div className="bg-white rounded-xl shadow-lg overflow-hidden hover:shadow-xl transition-shadow duration-300">
      {/* Property Image */}
      <div className="relative">
        <img 
          src={property.image} 
          alt={property.title}
          className="w-full h-48 object-cover"
        />
        <div className="absolute top-3 left-3">
          <span className={`px-3 py-1 rounded-full text-xs font-semibold capitalize ${getStatusColor(property.status)}`}>
            {formatStatus(property.status)}
          </span>
        </div>
        <div className="absolute top-3 right-3 bg-black bg-opacity-50 text-white px-2 py-1 rounded text-sm">
          ${property.price.toLocaleString()}
        </div>
      </div>

      {/* Property Details */}
      <div className="p-6">
        <h3 className="text-xl font-bold text-gray-900 mb-2">{property.title}</h3>
        <div className="flex items-center gap-1 text-gray-600 mb-3">
          <MapPin className="w-4 h-4" />
          <span className="text-sm">{property.location}</span>
        </div>

        <p className="text-gray-600 text-sm mb-4 line-clamp-2">{property.description}</p>

        {/* Property Features */}
        <div className="flex items-center gap-4 mb-4 text-sm text-gray-600">
          {property.bedrooms > 0 && (
            <div className="flex items-center gap-1">
              <Bed className="w-4 h-4" />
              <span>{property.bedrooms}</span>
            </div>
          )}
          <div className="flex items-center gap-1">
            <Bath className="w-4 h-4" />
            <span>{property.bathrooms}</span>
          </div>
          <div className="flex items-center gap-1">
            <Square className="w-4 h-4" />
            <span>{property.area}m²</span>
          </div>
        </div>

        {/* Token Info */}
        <div className="bg-gray-50 rounded-lg p-4 mb-4">
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm font-medium text-gray-700">Precio por Token</span>
            <span className="font-bold text-blue-600">${property.tokenPrice}</span>
          </div>
          <div className="flex justify-between items-center mb-2">
            <span className="text-sm text-gray-600">Tokens Disponibles</span>
            <span className="font-semibold">{property.availableTokens.toLocaleString()}</span>
          </div>
          <div className="flex justify-between items-center">
            <span className="text-sm text-gray-600">Tokens Vendidos</span>
            <span className="font-semibold text-green-600">{property.soldTokens.toLocaleString()}</span>
          </div>
          
          {/* Progress Bar */}
          <div className="mt-3">
            <div className="flex justify-between text-xs text-gray-600 mb-1">
              <span>Progreso de venta</span>
              <span>{Math.round((property.soldTokens / property.totalTokens) * 100)}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-blue-500 h-2 rounded-full transition-all duration-300"
                style={{ width: `${(property.soldTokens / property.totalTokens) * 100}%` }}
              ></div>
            </div>
          </div>
        </div>

        {/* User Tokens */}
        {userTokens > 0 && (
          <div className="bg-blue-50 rounded-lg p-3 mb-4">
            <div className="flex justify-between items-center">
              <span className="text-sm font-medium text-blue-800">Mis Tokens</span>
              <div className="flex items-center gap-2">
                <span className="font-bold text-blue-900">{userTokens}</span>
                <button
                  onClick={onTransferClick}
                  className="text-blue-600 hover:text-blue-800 p-1 rounded transition-colors"
                  title="Transferir tokens"
                >
                  <Send className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Buy Button */}
        <button
          onClick={onBuyClick}
          disabled={property.availableTokens === 0}
          className="w-full bg-gradient-to-r from-blue-500 to-indigo-600 text-white font-semibold py-3 px-4 rounded-lg hover:from-blue-600 hover:to-indigo-700 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          <ShoppingCart className="w-5 h-5" />
          {property.availableTokens === 0 ? 'Agotado' : 'Comprar Tokens'}
        </button>
      </div>
    </div>
  );
};

export default PropertyCard;