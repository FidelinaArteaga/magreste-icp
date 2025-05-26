import React, { useState } from "react";

function Contact() {
  const [form, setForm] = useState({
    nombre: "",
    apellido: "",
    telefono: "",
    correo: "",
    asunto: "",
  });

  const handleChange = e => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = e => {
    e.preventDefault();
    // Aquí podrías usar EmailJS, Formspree, o tu propio backend para enviar los datos a fidearte@gmail.com
    alert("Formulario enviado");
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="nombre" placeholder="Nombre" onChange={handleChange} />
      <input name="apellido" placeholder="Apellido" onChange={handleChange} />
      <input name="telefono" placeholder="Teléfono" onChange={handleChange} />
      <input name="correo" placeholder="Correo electrónico" onChange={handleChange} />
      <input name="asunto" placeholder="Asunto" onChange={handleChange} />
      <button type="submit">Enviar</button>
    </form>
  );
}

export default Contact;