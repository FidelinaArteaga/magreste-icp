import React from 'react';
import ReactDOM from 'react-dom/client';
import './Propieter.css';

// Componente principal temporal
function App() {
  return (
    <div>
      <h1>Magreste Labs</h1>
      <p>Plataforma de Tokenización de Bienes Raíces</p>
    </div>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
