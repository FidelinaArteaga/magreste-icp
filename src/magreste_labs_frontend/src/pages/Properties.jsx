import React from "react";
import PropertyCard from "../components/PropertyCard";
import prop2 from "../assets/prop2.jpg"; // Ruta corregida

// Ejemplo de datos de propiedades (puedes cargarlos desde un archivo o API)
const properties = [
  {
    id: 1,
    image: "/assets/prop2.jpg",
    priceBTC: 0.5,
    tokens: 1000,
    usdt: 50000,
    features: "studio apartment",
  },
  // ...más propiedades
];


function Properties() {
  return (
    <div>
      <h2>Propertys</h2>
      <div className="properties-grid">
        {properties.map((property) => (
          <PropertyCard key={property.id} {...property} />
        ))}
      </div>
    </div>
  );
}

export default Properties;