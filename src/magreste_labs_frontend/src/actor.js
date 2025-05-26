import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory, canisterId } from "../declarations/tu_canister/tu_canister.did.js";

// Crea el agente
const agent = new HttpAgent();

// (Opcional, solo en desarrollo local) Valida el certificado del replica local
if (process.env.DFX_NETWORK !== "ic") {
  agent.fetchRootKey().catch((err) => {
    console.warn("No se pudo obtener la root key. ¿Está corriendo el replica local?");
    console.error(err);
  });
}

// Crea el actor usando la interfaz Candid y el agente
const actor = Actor.createActor(idlFactory, {
  agent,
  canisterId,
});

export default actor;