import React from "react";
import contactBookActor from "../Services/contactBookActor";

function PropertyCard({ id, image, priceBTC, tokens, usdt, features }) {
  const buyTokens = async () => {
    try {
      // Aquí realizas la llamada al backend Motoko
      // Asegúrate de que exista el método buyTokens en tu canister Motoko
      await contactBookActor.buyTokens(id, tokens);
      alert("¡Compra realizada con éxito!");
    } catch (error) {
      alert("Ocurrió un error al comprar los tokens.");
      console.error(error);
    }
  };

  return (
    <div className="property-card">
      <img src={image} alt="Propiedad" />
      <div className="info">
        <div>Precio: {priceBTC} BTC</div>
        <div>Tokens: {tokens} ({usdt} USDT)</div>
        <div>{features}</div>
        <button onClick={buyTokens}>Comprar tokens</button>
      </div>
    </div>
  );
}

export default PropertyCard;