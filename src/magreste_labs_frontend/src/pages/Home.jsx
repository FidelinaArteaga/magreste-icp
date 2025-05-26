import React, { useEffect, useState } from 'react';
import { Actor, HttpAgent } from "@dfinity/agent";
import { idlFactory, canisterId } from "../../../declarations/magreste_labs_backend"; // Ruta corregida
import Navbar from '../components/Navbar';
import Footer from "../components/Footer";

import house from "../assets/house.jpg"; // Ruta corregida

const Home = () => {
  return <h1>Bienvenido a la página principal</h1>;
};

export default Home;