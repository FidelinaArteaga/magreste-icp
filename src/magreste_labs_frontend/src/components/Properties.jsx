import React, { useState } from "react";
import magresteTokenActor from "../services/magresteTokenActor";
import { connectWallet } from "../services/wallet";

function PropertyCard({ id, image, priceUSDT, tokens, features }) {
  const [wallet, setWallet] = useState(null);

  const handleConnectWallet = async () => {
    const principal = await connectWallet();
    if (principal) setWallet(principal);
  };

  const buyTokens = async () => {
    if (!wallet) {
      alert("Por favor conecta tu wallet primero.");
      return;
    }
    // Llama al canister para transferir MAGRESTE tokens (1 token = 1 USDT)
    try {
      // Ejemplo: transferir tokens al canister que representa la propiedad
      const result = await magresteTokenActor.transfer(/*to=*/id, /*amount=*/BigInt(tokens));
      if (result.Ok) {
        alert("¡Compra realizada!");
      } else {
        alert("Error al comprar: " + JSON.stringify(result));
      }
    } catch (e) {
      alert("Error al interactuar con el canister.");
      console.error(e);
    }
  };

  return (
    <div className="property-card">
      <img src={image} alt="Propiedad" />
      <div>Precio: {priceUSDT} USDT</div>
      <div>Tokens: {tokens} MAGRESTE</div>
      <div>{features}</div>
      {!wallet ? (
        <button onClick={handleConnectWallet}>Conecta tu wallet</button>
      ) : (
        <button onClick={buyTokens}>Comprar tokens</button>
      )}
    </div>
  );
}

export default PropertyCard;