import { Actor, HttpAgent } from '@dfinity/agent';

const agent = new HttpAgent({ host: 'http://localhost:8000' });
const myCanisterId = 'xxxx-xxxx-xxx...'; // ID de tu canister
const myActor = Actor.createActor(idlFactory, {
  agent,
  canisterId: myCanisterId,
});
