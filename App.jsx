// src/App.js - Componente Principal
import React, { useState, useEffect } from 'react';
import { Wallet, Home, ShoppingCart, Send, ArrowRight, MapPin, Bed, Bath, Square, DollarSign, Coins, User, LogOut, CheckCircle, AlertCircle } from 'lucide-react';
import { useIC } from './hooks/useIC';
import Header from './components/Header';
import PropertyCard from './components/PropertyCard';
import PurchaseModal from './components/PurchaseModal';
import TransferModal from './components/TransferModal';
import Notification from './components/Notification';
import LoginScreen from './components/LoginScreen';

const App = () => {
  // Usar el hook personalizado para ICP
  const {
    isConnected,
    principal,
    isLoading: icLoading,
    error: icError,
    login,
    logout,
    buyTokens: buyTokensIC,
    getUserTokens,
    getProperties,
    transferTokens: transferTokensIC,
  } = useIC();

  // Estados locales
  const [properties, setProperties] = useState([]);
  const [userTokens, setUserTokens] = useState({});
  const [selectedProperty, setSelectedProperty] = useState(null);
  const [purchaseAmount, setPurchaseAmount] = useState(1);
  const [isLoading, setIsLoading] = useState(false);
  const [notification, setNotification] = useState(null);
  const [transferAmount, setTransferAmount] = useState(1);
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [transferPropertyId, setTransferPropertyId] = useState(null);
  const [recipientPrincipal, setRecipientPrincipal] = useState('');

  // Cargar datos cuando se conecta
  useEffect(() => {
    if (isConnected) {
      loadProperties();
      loadUserTokens();
    }
  }, [isConnected]);

  // Cargar propiedades desde el backend
  const loadProperties = async () => {
    try {
      setIsLoading(true);
      const propertiesData = await getProperties();
      
      // Convertir datos de Motoko a formato del frontend
      const formattedProperties = propertiesData.map(property => ({
        id: Number(property.id),
        title: property.title,
        location: property.location,
        price: Number(property.price),
        tokenPrice: Number(property.tokenPrice),
        totalTokens: Number(property.totalTokens),
        availableTokens: Number(property.availableTokens),
        soldTokens: Number(property.soldTokens),
        image: property.imageUrl || "/api/placeholder/400/300",
        status: Object.keys(property.status)[0], // Convertir variant a string
        bedrooms: Number(property.bedrooms),
        bathrooms: Number(property.bathrooms),
        area: Number(property.area),
        description: property.description
      }));
      
      setProperties(formattedProperties);
    } catch (error) {
      showNotification('Error al cargar propiedades: ' + error.message, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  // Cargar tokens del usuario
  const loadUserTokens = async () => {
    try {
      const tokensData = await getUserTokens();
      
      const tokensMap = {};
      tokensData.forEach(tokenData => {
        tokensMap[Number(tokenData.propertyId)] = Number(tokenData.amount);
      });
      
      setUserTokens(tokensMap);
    } catch (error) {
      console.error('Error al cargar tokens del usuario:', error);
    }
  };

  // Conectar con Internet Identity
  const connectWithII = async () => {
    try {
      await login();
      showNotification('Conectado exitosamente con Internet Identity', 'success');
    } catch (error) {
      showNotification('Error al conectar: ' + error.message, 'error');
    }
  };

  // Desconectar
  const disconnect = async () => {
    try {
      await logout();
      setProperties([]);
      setUserTokens({});
      showNotification('Desconectado exitosamente', 'success');
    } catch (error) {
      showNotification('Error al desconectar: ' + error.message, 'error');
    }
  };

  // Función para mostrar notificaciones
  const showNotification = (message, type) => {
    setNotification({ message, type });
    setTimeout(() => setNotification(null), 3000);
  };

  // Comprar tokens usando el backend real
  const buyTokens = async (propertyId, amount) => {
    if (!isConnected) {
      showNotification('Debes conectarte primero', 'error');
      return;
    }

    setIsLoading(true);
    try {
      const result = await buyTokensIC(propertyId, amount);
      
      if ('ok' in result) {
        // Actualizar datos locales
        await loadProperties();
        await loadUserTokens();
        
        const property = properties.find(p => p.id === propertyId);
        showNotification(`¡Compra exitosa! ${amount} tokens de ${property?.title}`, 'success');
        setSelectedProperty(null);
      } else {
        showNotification('Error en la compra: ' + result.err, 'error');
      }
    } catch (error) {
      showNotification('Error en la compra: ' + error.message, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  // Transferir tokens usando el backend real
  const transferTokens = async () => {
    if (!isConnected || !recipientPrincipal.trim()) {
      showNotification('Debes proporcionar un Principal válido', 'error');
      return;
    }

    setIsLoading(true);
    try {
      const result = await transferTokensIC(
        transferPropertyId, 
        transferAmount, 
        recipientPrincipal.trim()
      );
      
      if ('ok' in result) {
        // Actualizar tokens del usuario
        await loadUserTokens();
        showNotification(`${transferAmount} tokens transferidos exitosamente`, 'success');
        setShowTransferModal(false);
        setTransferAmount(1);
        setRecipientPrincipal('');
      } else {
        showNotification('Error en la transferencia: ' + result.err, 'error');
      }
    } catch (error) {
      showNotification('Error en la transferencia: ' + error.message, 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const getTotalUserTokens = () => {
    return Object.values(userTokens).reduce((sum, tokens) => sum + tokens, 0);
  };

  const handleTransferClick = (propertyId) => {
    setTransferPropertyId(propertyId);
    setShowTransferModal(true);
  };

  if (!isConnected) {
    return (
      <LoginScreen 
        onConnect={connectWithII} 
        isLoading={icLoading} 
      />
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Header 
        principal={principal}
        totalTokens={getTotalUserTokens()}
        onDisconnect={disconnect}
      />

      <Notification notification={notification} />

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <h2 className="text-3xl font-bold text-gray-900 mb-2">Marketplace de Inmuebles</h2>
          <p className="text-gray-600">Invierte en propiedades tokenizadas del mundo real</p>
        </div>

        {/* Properties Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {properties.length === 0 && !isLoading ? (
            <div className="col-span-full text-center py-12">
              <Home className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500 text-lg">No hay propiedades disponibles</p>
              <p className="text-gray-400 text-sm">Las propiedades se cargarán automáticamente</p>
            </div>
          ) : (
            properties.map((property) => (
              <PropertyCard
                key={property.id}
                property={property}
                userTokens={userTokens[property.id] || 0}
                onBuyClick={() => setSelectedProperty(property)}
                onTransferClick={() => handleTransferClick(property.id)}
              />
            ))
          )}
        </div>
      </main>

      {/* Purchase Modal */}
      {selectedProperty && (
        <PurchaseModal
          property={selectedProperty}
          purchaseAmount={purchaseAmount}
          setPurchaseAmount={setPurchaseAmount}
          onConfirm={() => buyTokens(selectedProperty.id, purchaseAmount)}
          onCancel={() => setSelectedProperty(null)}
          isLoading={isLoading}
        />
      )}

      {/* Transfer Modal */}
      {showTransferModal && (
        <TransferModal
          transferAmount={transferAmount}
          setTransferAmount={setTransferAmount}
          recipientPrincipal={recipientPrincipal}
          setRecipientPrincipal={setRecipientPrincipal}
          maxTokens={userTokens[transferPropertyId] || 0}
          onConfirm={transferTokens}
          onCancel={() => {
            setShowTransferModal(false);
            setTransferAmount(1);
            setRecipientPrincipal('');
          }}
          isLoading={isLoading}
        />
      )}
    </div>
  );
};

export default App;