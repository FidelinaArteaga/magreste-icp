import React from "react";
import { Link } from "react-router-dom";

function Navbar() {
  return (
    <nav>
      <div className="logo">LOGO</div>
      <div className="btc-price">BTC: {/* Aquí puedes poner el precio */} </div>
      <Link to="/properties">Properties</Link>
      <Link to="/contact">Contacto</Link>
      <Link to="/register">Registro</Link>
      <button>Conecta tu wallet</button>
    </nav>
  );
}

export default Navbar;