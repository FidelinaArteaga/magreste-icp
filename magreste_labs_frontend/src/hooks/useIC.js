// src/hooks/useIC.js - Hook personalizado para React
import { useState, useEffect, useCallback } from 'react';
import { icAgent } from '../utils/ic-agent';

export const useIC = () => {
  const [isConnected, setIsConnected] = useState(false);
  const [principal, setPrincipal] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    const initIC = async () => {
      try {
        await icAgent.init();
        const authenticated = await icAgent.isAuthenticated();
        setIsConnected(authenticated);
        if (authenticated) {
          setPrincipal(icAgent.getPrincipal());
        }
      } catch (err) {
        setError(err.message);
      }
    };

    initIC();
  }, []);

  const login = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const principalId = await icAgent.login();
      setIsConnected(true);
      setPrincipal(principalId);
      return principalId;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const logout = useCallback(async () => {
    setIsLoading(true);
    try {
      await icAgent.logout();
      setIsConnected(false);
      setPrincipal('');
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const buyTokens = useCallback(async (propertyId, amount) => {
    setIsLoading(true);
    setError(null);
    try {
      const result = await icAgent.buyTokens(propertyId, amount);
      return result;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const getUserTokens = useCallback(async () => {
    try {
      return await icAgent.getUserTokens();
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  const getProperties = useCallback(async () => {
    try {
      return await icAgent.getProperties();
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  const transferTokens = useCallback(async (propertyId, amount, recipient) => {
    setIsLoading(true);
    setError(null);
    try {
      const result = await icAgent.transferTokens(propertyId, amount, recipient);
      return result;
    } catch (err) {
      setError(err.message);
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const getUserBalance = useCallback(async () => {
    try {
      return await icAgent.getUserBalance();
    } catch (err) {
      setError(err.message);
      throw err;
    }
  }, []);

  return {
    isConnected,
    principal,
    isLoading,
    error,
    login,
    logout,
    buyTokens,
    getUserTokens,
    getProperties,
    transferTokens,
    getUserBalance,
  };
};