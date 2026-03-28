# Guía Esencial de Consultas MongoDB - KN Store

Este documento contiene las consultas equivalentes a las operaciones que realizabas en SQL, adaptadas a la sintaxis y comandos nativos de MongoDB. Está diseñado para que puedas entender fácilmente cómo manipular los datos de la tienda.

---

## 1. Inventario y Catálogo (Lectura)

### 📌 Productos con bajo stock
Lista productos con stock menor a 25 unidades y los ordena de menor a mayor cantidad.
> Utiliza el operador `$lt` (less than) para filtrar y `.sort()` para ordenar ascendente (`1`).

```javascript
db.products.find({ stock: { $lt: 25 } }).sort({ stock: 1 });
```

### 📌 Filtrar por múltiples marcas
Busca todos los productos que pertenezcan a las marcas 'Apple' o 'Samsung'.
> El operador `$in` permite buscar documentos donde el valor de un campo coincida con cualquiera de los elementos listados en el array.

```javascript
db.products.find({ brand: { $in: ['Apple', 'Samsung'] } });
```

---

## 2. Inserción y Mantenimiento de Datos (Escritura)

### 📌 Crear un nuevo producto
Agrega un nuevo producto a la colección estableciendo sus tipos de datos nativos de BSON, como `Date`.

```javascript
db.products.insertOne({
  name: 'MacBook Pro M3',
  brand: 'Apple',
  price: 12000000,
  stock: 15,
  active: true,
  created_at: new Date()
});
```

### 📌 Actualizar precio y reabastecer stock (Simultáneamente)
Actualiza el precio de un producto específico e incrementa su stock actual en 10 unidades.
> - `$set`: Sobreescribe el valor actual.
> - `$inc`: Suma una cantidad matemática al valor actual del campo numérico.

```javascript
db.products.updateOne(
  { name: 'Galaxy S24 Ultra' },
  { $set: { price: 4800000 }, $inc: { stock: 10 } }
);
```

### 📌 Eliminar productos descontinuados
Elimina todos los productos que ya no estén activos en una sola instrucción.

```javascript
db.products.deleteMany({ active: false });
```

---

## 3. Clientes y Órdenes

### 📌 Buscar carritos abandonados
Busca aquellas órdenes que se han quedado estancadas en estado 'CART'. Útil para estrategias de recuperación y marketing.

```javascript
db.orders.find({ status: 'CART' });
```

### 📌 Desactivar usuarios incompletos (Actualización Múltiple)
Marca como inactivos a los usuarios que no tienen un rol asignado en del sistema.
> `updateMany()` afecta a todos los documentos de la colección que coincidan con la primera condición.

```javascript
db.users.updateMany(
  { role: { $exists: false } },
  { $set: { active: false } }
);
```

---

## 4. Agrupaciones y Reportes Avanzados (Aggregation Framework)

El framework de agregación (`aggregate`) simula operaciones avanzadas de SQL como `GROUP BY` y `JOIN`, procesando los datos por etapas (Pipeline). 

### 📌 Reporte estadístico por Ciudad
Cuenta cuántos clientes están registrados, agrupándolos según su ciudad de residencia.
> 1. `$match`: Filtra primero los que son solo clientes (WHERE).
> 2. `$group`: Agrupa y cuenta usando el acumulador `$sum` (GROUP BY / COUNT).
> 3. `$sort`: Los ordena de mayor a menor cantidad de clientes.

```javascript
db.users.aggregate([
  { $match: { role: 'CUSTOMER' } },
  { $group: { _id: '$city', total_clientes: { $sum: 1 } } },
  { $sort: { total_clientes: -1 } }
]);
```

### 📌 Ranking de Marcas más Vendidas (Simulación de JOIN)
Suma los ingresos totales por cada marca, cruzando los ítems de las ventas con el catálogo de productos.
> 1. `$lookup`: Simula un `JOIN` conectando el `product_id` en las ventas con el `_id` de los productos.
> 2. `$unwind`: Desacopla el array que genera el "Join" en objetos individuales.
> 3. `$group`: Agrupa todos los ítems por el nombre de la marca e incrementa sumando los valores del `subtotal`.

```javascript
db.order_items.aggregate([
  { 
    $lookup: { 
      from: 'products', 
      localField: 'product_id', 
      foreignField: '_id', 
      as: 'product_info' 
    } 
  },
  { $unwind: '$product_info' },
  { 
    $group: { 
      _id: '$product_info.brand', 
      Total_Ventas: { $sum: '$subtotal' } 
    } 
  },
  { $sort: { Total_Ventas: -1 } }
]);
```
