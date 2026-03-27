# Guía de Migración: SQL vs MongoDB (NoSQL)

## 1. Introducción: De Relacional a Documentos

En bases de datos relacionales (como MySQL o PostgreSQL), la información se divide rígidamente en **tablas**, y se relaciona a través de **Llaves Foráneas** (Foreign Keys). Para armar información completa (por ejemplo, una orden con sus productos, el pago y la dirección de envío), el backend debe usar uniones (`JOIN`) que consumen más recursos.

Por el contrario, en **MongoDB** (base de datos NoSQL orientada a documentos), la filosofía recomendada de diseño es: *"Lo que se consulta junto, se almacena junto"*. A esto se le llama **Desnormalización** mediante el uso de **Documentos Embebidos (Embedded Documents)**.

---

## 2. Comparativa del Esquema: SQL vs Mongo

El archivo JSON original (`kn_store_test.json`) estaba fragmentado en **10 Tablas**. Gracias al script de refactorización unificado, agrupamos esos datos según cómo operan naturalmente, reduciendo todo a **4 Colecciones** principales.

| Entidad Lógica | Tablas SQL Originales | Colecciones MongoDB (Nuevas) | Estrategia de Refactorización |
| :--- | :--- | :--- | :--- |
| **Usuarios** | `users`<br>`address` | `users` | Las direcciones se incrustan como un arreglo `addresses: []` *adentro* de la información de cada usuario. |
| **Catálogo** | `category`<br>`subcategory` | `categories` | Las subcategorías se vuelven un arreglo de datos anidados en su categoría madre. |
| **Órdenes** | `orders`<br>`order_item`<br>`payment`<br>`bill`<br>`shipment` | `orders` | Los detalles de ítems comprados, el pago, el recibo y el envìo dejan de estar tirados y pasan a ser sub-objetos *dentro* del documento de la orden matriz. |
| **Productos** | `product` | `products` | Se mantiene intacto como colección única debido a que los productos cambian mucho en stock y precios constantemente (lectura/escritura frecuente es separada). |

---

## 3. ¿Cómo funcionan los Datos Embebidos?

Embeber información consiste en colocar objetos tipo JSON anidados directamente dentro de la jerarquía de un objeto (documento madre), eliminando la necesidad de buscar en otros "archivos" o colecciones de la base de datos.

### Ejemplo 1: Colección `users` (Relación 1 a Muchos)
En SQL guardábamos el ID de usuario y debíamos escanear otra tabla enorme para encontrar sus direcciones.  
En MongoDB, agregamos las direcciones directamente.

**Estructura Mongo:**
```json
{
  "id": "4",
  "name": "Juan",
  "email": "juan.perez@gmail.com",
  "addresses": [
    {
      "id": "1",
      "street": "Calle 100",
      "city": "Bogota",
      "is_default": "1"
    },
    {
      "id": "2",
      "street": "Carrera 7",
      "city": "Bogota",
      "is_default": "0"
    }
  ]
}
```
*Ventaja Operativa:* Al pedir al usuario Juan en el modelo `User.findById(id)`, nuestro backend de KN-Store inmediatamente tiene lista sus direcciones de entrega para el frontend; sin consultas extra a DB.

### Ejemplo 2: Colección `orders` (El Macro-Documento "Snapshot")
Las órdenes de compra se benefician inmensamente de los documentos embebidos para mejorar el rendimiento. En lugar de interrogar a 5 tablas cada vez que el usuario abre sus compras anteriores...

**Estructura Mongo Anidada:**
```json
{
  "id": "1",
  "user_id": "4",
  "order_date": "2026-01-15 10:30:00",
  "status": "DELIVERED",
  "total": "6187000.00",
  "shipping_address": {
    "street": "Calle 100",
    "city": "Bogota"
  },
  "items": [
    { "product_id": "1", "quantity": "1", "unit_price": "4999000.00" },
    { "product_id": "4", "quantity": "1", "unit_price": "999000.00" }
  ],
  "payment": {
    "method": "Tarjeta Credito",
    "status": "COMPLETED",
    "paid_at": "2026-01-15 10:35:00"
  },
  "shipment": {
    "tracking_number": "KN-2026-00001",
    "shipping_method": "Servientrega"
  }
}
```
*Ventaja Clave:* 
1. **Lectura Ultrarrápida:** Cargar una orden toma 1 milisegundo, ya que absolutamente todos los datos de la factura, pago y rastreo de envío vienen envueltos en la misma carga útil.
2. **Consistencia en el Tiempo (Efecto Snapshot):** Si el día de mañana el usuario borra o cambia su dirección de residencia en su perfil, **esta orden no se daña ni se altera**. La dirección a la que se envió (`shipping_address`) y el precio que se pagó (`unit_price`) quedaron inmóviles e incrustados el día exacto de la compra. En SQL esto causaría muchos dolores de cabeza o la necesidad de no poder borrar direcciones nunca.
