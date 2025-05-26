import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory, canisterId } from "../../declarations/magreste_token";

// Conectar con el agente ICP
const agent = new HttpAgent();

const magresteTokenActor = Actor.createActor(idlFactory, {
  agent,
  canisterId,
});

export default magresteTokenActor;