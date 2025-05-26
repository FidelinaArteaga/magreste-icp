import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory, canisterId } from "../../declarations/contact_book";

const agent = new HttpAgent();

const contactBookActor = Actor.createActor(idlFactory, {
  agent,
  canisterId,
});

export default contactBookActor;