export async function connectWallet() {
    if (!window.ic || !window.ic.plug) {
      alert("Por favor instala Plug Wallet en tu navegador.");
      return null;
    }
    // Solicitar conexión a Plug
    const connected = await window.ic.plug.requestConnect();
    if (connected) {
      const principal = await window.ic.plug.getPrincipal();
      return principal;
    } else {
      alert("No se pudo conectar la wallet.");
      return null;
    }
  }