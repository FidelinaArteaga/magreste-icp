// src/utils/ic-agent.js
import { AuthClient } from '@dfinity/auth-client';
import { Actor, HttpAgent } from '@dfinity/agent';
import { idlFactory } from '../declarations/backend/backend.did.js';
import { config } from '../config/env.js';

class ICAgent {
  constructor() {
    this.authClient = null;
    this.actor = null;
    this.identity = null;
  }

  async init() {
    this.authClient = await AuthClient.create();
    
    if (await this.authClient.isAuthenticated()) {
      this.identity = this.authClient.getIdentity();
      await this.createActor();
    }
  }

  async login() {
    return new Promise((resolve, reject) => {
      this.authClient.login({
        identityProvider: config.IDENTITY_PROVIDER,
        onSuccess: async () => {
          this.identity = this.authClient.getIdentity();
          await this.createActor();
          resolve(this.identity.getPrincipal().toString());
        },
        onError: reject,
      });
    });
  }

  async logout() {
    await this.authClient.logout();
    this.identity = null;
    this.actor = null;
  }

  async createActor() {
    const agent = new HttpAgent({
      host: config.IC_HOST,
      identity: this.identity,
    });

    if (process.env.NODE_ENV !== 'production') {
      await agent.fetchRootKey();
    }

    this.actor = Actor.createActor(idlFactory, {
      agent,
      canisterId: config.BACKEND_CANISTER_ID,
    });
  }

  // Métodos para interactuar con el backend
  async getProperties() {
    if (!this.actor) throw new Error('Not authenticated');
    return await this.actor.getProperties();
  }

  async buyTokens(propertyId, amount) {
    if (!this.actor) throw new Error('Not authenticated');
    return await this.actor.buyTokens(propertyId, amount);
  }

  async getUserTokens() {
    if (!this.actor) throw new Error('Not authenticated');
    return await this.actor.getUserTokens();
  }

  async transferTokens(propertyId, amount, recipient) {
    if (!this.actor) throw new Error('Not authenticated');
    return await this.actor.transferTokens(propertyId, amount, recipient);
  }

  async getPropertyDetails(propertyId) {
    if (!this.actor) throw new Error('Not authenticated');
    return await this.actor.getPropertyDetails(propertyId);
  }

  async getUserBalance() {
    if (!this.actor) throw new Error('Not authenticated');
    return await this.actor.getUserBalance();
  }

  async getUserTransactionHistory() {
    if (!this.actor) throw new Error('Not authenticated');
    return await this.actor.getUserTransactionHistory();
  }

  isAuthenticated() {
    return this.authClient?.isAuthenticated() || false;
  }

  getPrincipal() {
    return this.identity?.getPrincipal().toString() || '';
  }
}

// Singleton instance
export const icAgent = new ICAgent();