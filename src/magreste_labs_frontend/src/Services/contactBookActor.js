import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory, canisterId } from "../../../declarations/magreste_labs_backend"; // Ruta corregida

const agent = new HttpAgent();
const contactBookActor = Actor.createActor(idlFactory, {
  agent,
  canisterId,
});

export default contactBookActor;