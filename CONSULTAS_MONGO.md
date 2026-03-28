# Guía de Consultas MongoDB - KN Store (Calzado)

Consultas organizadas por nivel de complejidad, adaptadas al esquema actual de la tienda de calzado. Todos los ejemplos operan sobre las colecciones reales: `products`, `categories`, `users` y `orders`.

> **Nota sobre tipos:** Los campos `price`, `stock`, `quantity` y `total` están almacenados como `String` en la BD actual. Las consultas numéricas que los involucran usan `$toDouble`/`$toInt` para convertirlos dentro del pipeline cuando es necesario.

---

## 1. Consultas Básicas de Catálogo (READ)

### Todos los productos de una marca específica
```javascript
db.products.find({ brand: "Nike" });
```

### Filtrar por múltiples marcas con `$in`
```javascript
db.products.find(
  { brand: { $in: ["Nike", "Adidas", "Puma"] } },
  { name: 1, brand: 1, price: 1, _id: 0 }
);
```

### Buscar productos por subcategoría (Running = id "1")
```javascript
db.products.find({ subcategory_id: "1" }).sort({ price: 1 });
```

### Productos con bajo stock (menos de 20 unidades)
> `$expr` permite usar operadores de aggregation dentro de `find()`, necesario cuando el campo es String.

```javascript
db.products.find({
  $expr: { $lt: [{ $toInt: "$stock" }, 20] }
}).sort({ stock: 1 });
```

### Buscar por nombre con expresión regular (búsqueda parcial)
> `$regex` con `$options: "i"` hace la búsqueda insensible a mayúsculas.

```javascript
db.products.find({
  name: { $regex: "salomon", $options: "i" }
});
```

### Productos activos dentro de un rango de precio
> Ambas condiciones aplican sobre el mismo campo: `$gte` (>=) y `$lte` (<=).

```javascript
db.products.find({
  active: "1",
  $expr: {
    $and: [
      { $gte: [{ $toDouble: "$price" }, 400000] },
      { $lte: [{ $toDouble: "$price" }, 600000] }
    ]
  }
}, { name: 1, brand: 1, price: 1, _id: 0 });
```

---

## 2. Proyecciones y Transformaciones

### Mostrar solo campos necesarios (excluir `_id` y datos internos)
```javascript
db.products.find(
  { brand: "Adidas" },
  { _id: 0, name: 1, price: 1, size: 1, stock: 1 }
);
```

### Listar subcategorías de una categoría con `$elemMatch`
> Encuentra la categoría y devuelve solo la subcategoría que coincida con el filtro.

```javascript
db.categories.find(
  { name: "Calzado Deportivo" },
  {
    name: 1,
    subcategories: { $elemMatch: { name: "Running" } },
    _id: 0
  }
);
```

### Órdenes que contienen un producto específico en sus items
> `$elemMatch` en arrays de documentos embebidos: busca órdenes donde al menos un item tenga `product_id: "5"` (Air Jordan 1).

```javascript
db.orders.find({
  items: { $elemMatch: { product_id: "5" } }
}, { id: 1, user_id: 1, status: 1, total: 1, _id: 0 });
```

---

## 3. Escritura y Mantenimiento

### Insertar un nuevo producto
```javascript
db.products.insertOne({
  id: "26",
  subcategory_id: "1",
  name: "New Balance Fresh Foam X 1080v13",
  price: "569000.00",
  size: "42",
  stock: "20",
  brand: "New Balance",
  active: "1",
  created_at: new Date(),
  updated_at: new Date()
});
```

### Actualizar precio y stock simultáneamente con `$set` e `$inc`
> `$set` sobreescribe el valor; `$inc` suma al valor actual (funciona en campos numéricos).

```javascript
db.products.updateOne(
  { name: "Nike Air Zoom Pegasus 41" },
  {
    $set: { price: "469000.00", updated_at: new Date() },
    $inc: { stock: 15 }
  }
);
```

### Reabastecer stock a todos los productos de Trail Running (subcategory_id "7")
> `updateMany()` afecta todos los documentos que coincidan.

```javascript
db.products.updateMany(
  { subcategory_id: "7" },
  { $inc: { stock: 10 }, $set: { updated_at: new Date() } }
);
```

### Añadir una nueva dirección a un usuario existente con `$push`
```javascript
db.users.updateOne(
  { id: "5" },
  {
    $push: {
      addresses: {
        id: "9",
        street: "Calle 72",
        number: "10-34",
        city: "Bogota",
        postal_code: "110221",
        is_default: "0",
        created_at: new Date()
      }
    }
  }
);
```

### Desactivar productos sin stock con `$expr` y `updateMany`
```javascript
db.products.updateMany(
  { $expr: { $lte: [{ $toInt: "$stock" }, 0] } },
  { $set: { active: "0", updated_at: new Date() } }
);
```

---

## 4. Aggregation Pipeline — Nivel Intermedio

El **Aggregation Framework** procesa los datos en etapas (pipeline). Cada etapa recibe los documentos de la anterior y los transforma.

### Total de órdenes agrupadas por estado
> `$group` con `_id` define el campo de agrupación; `$sum: 1` cuenta documentos.

```javascript
db.orders.aggregate([
  {
    $group: {
      _id: "$status",
      cantidad: { $sum: 1 },
      ingresos_total: { $sum: { $toDouble: "$total" } }
    }
  },
  { $sort: { ingresos_total: -1 } }
]);
```

### Promedio de precio por subcategoría
```javascript
db.products.aggregate([
  {
    $group: {
      _id: "$subcategory_id",
      promedio_precio: { $avg: { $toDouble: "$price" } },
      total_productos: { $sum: 1 },
      stock_total: { $sum: { $toInt: "$stock" } }
    }
  },
  { $sort: { promedio_precio: -1 } }
]);
```

### Clientes distribuidos por ciudad (desde documentos embebidos)
> `$unwind` descompone el array `addresses` en documentos individuales para poder agrupar.

```javascript
db.users.aggregate([
  { $match: { role: "CLIENT" } },
  { $unwind: "$addresses" },
  {
    $group: {
      _id: "$addresses.city",
      clientes: { $sum: 1 },
      nombres: { $push: { $concat: ["$name", " ", "$last_name"] } }
    }
  },
  { $sort: { clientes: -1 } }
]);
```

### Ranking de productos más pedidos (desde items embebidos en orders)
> `$unwind` sobre `items` crea un documento por cada línea de pedido, permitiendo agrupar por producto.

```javascript
db.orders.aggregate([
  { $match: { status: { $nin: ["CART", "CANCELLED"] } } },
  { $unwind: "$items" },
  {
    $group: {
      _id: "$items.product_id",
      veces_pedido: { $sum: 1 },
      unidades_vendidas: { $sum: { $toInt: "$items.quantity" } },
      ingreso_generado: {
        $sum: {
          $multiply: [
            { $toDouble: "$items.unit_price" },
            { $toInt: "$items.quantity" }
          ]
        }
      }
    }
  },
  { $sort: { unidades_vendidas: -1 } }
]);
```

---

## 5. Aggregation Pipeline — Nivel Avanzado

### `$lookup`: Cruzar órdenes con datos de producto
> Simula un `JOIN`. Une los `items` de cada orden con la colección `products` usando el `product_id`.

```javascript
db.orders.aggregate([
  { $match: { status: "DELIVERED" } },
  { $unwind: "$items" },
  {
    $lookup: {
      from: "products",
      localField: "items.product_id",
      foreignField: "id",
      as: "detalle_producto"
    }
  },
  { $unwind: "$detalle_producto" },
  {
    $project: {
      _id: 0,
      orden_id: "$id",
      usuario_id: "$user_id",
      producto: "$detalle_producto.name",
      marca: "$detalle_producto.brand",
      cantidad: "$items.quantity",
      precio_unitario: "$items.unit_price"
    }
  }
]);
```

### `$lookup` doble: Órdenes → Productos → Usuarios
> Encadena dos `$lookup` para obtener nombre del cliente y detalle del producto en una sola consulta.

```javascript
db.orders.aggregate([
  { $match: { status: { $in: ["DELIVERED", "SHIPPED"] } } },
  {
    $lookup: {
      from: "users",
      localField: "user_id",
      foreignField: "id",
      as: "cliente"
    }
  },
  { $unwind: "$cliente" },
  { $unwind: "$items" },
  {
    $lookup: {
      from: "products",
      localField: "items.product_id",
      foreignField: "id",
      as: "producto"
    }
  },
  { $unwind: "$producto" },
  {
    $project: {
      _id: 0,
      orden: "$id",
      cliente: { $concat: ["$cliente.name", " ", "$cliente.last_name"] },
      ciudad: { $arrayElemAt: ["$cliente.addresses.city", 0] },
      producto: "$producto.name",
      marca: "$producto.brand",
      subtotal: {
        $multiply: [
          { $toDouble: "$items.unit_price" },
          { $toInt: "$items.quantity" }
        ]
      }
    }
  },
  { $sort: { subtotal: -1 } }
]);
```

### `$bucket`: Distribución de productos por rango de precio
> Clasifica automáticamente los productos en rangos de precio definidos manualmente.

```javascript
db.products.aggregate([
  {
    $bucket: {
      groupBy: { $toDouble: "$price" },
      boundaries: [0, 300000, 450000, 600000, 800000],
      default: "800000+",
      output: {
        cantidad: { $sum: 1 },
        marcas: { $addToSet: "$brand" },
        productos: { $push: "$name" }
      }
    }
  }
]);
```

### `$facet`: Múltiples agrupaciones en un solo pipeline
> Ejecuta varias sub-pipelines en paralelo sobre el mismo conjunto de documentos. Ideal para dashboards.

```javascript
db.products.aggregate([
  { $match: { active: "1" } },
  {
    $facet: {
      por_marca: [
        { $group: { _id: "$brand", total: { $sum: 1 }, stock: { $sum: { $toInt: "$stock" } } } },
        { $sort: { total: -1 } }
      ],
      por_subcategoria: [
        { $group: { _id: "$subcategory_id", productos: { $sum: 1 }, precio_promedio: { $avg: { $toDouble: "$price" } } } },
        { $sort: { _id: 1 } }
      ],
      resumen_general: [
        {
          $group: {
            _id: null,
            total_productos: { $sum: 1 },
            precio_minimo: { $min: { $toDouble: "$price" } },
            precio_maximo: { $max: { $toDouble: "$price" } },
            precio_promedio: { $avg: { $toDouble: "$price" } },
            stock_total: { $sum: { $toInt: "$stock" } }
          }
        }
      ]
    }
  }
]);
```

### `$addFields` + `$cond`: Clasificar productos por nivel de precio
> Agrega un campo calculado que etiqueta cada producto según su rango de precio con lógica condicional anidada.

```javascript
db.products.aggregate([
  {
    $addFields: {
      rango_precio: {
        $switch: {
          branches: [
            { case: { $lt:  [{ $toDouble: "$price" }, 350000] }, then: "Economico"   },
            { case: { $lt:  [{ $toDouble: "$price" }, 500000] }, then: "Estandar"    },
            { case: { $lt:  [{ $toDouble: "$price" }, 650000] }, then: "Premium"     }
          ],
          default: "Top Premium"
        }
      },
      stock_status: {
        $cond: {
          if:   { $lte: [{ $toInt: "$stock" }, 15] },
          then: "Stock Critico",
          else: {
            $cond: {
              if:   { $lte: [{ $toInt: "$stock" }, 25] },
              then: "Stock Bajo",
              else: "Stock OK"
            }
          }
        }
      }
    }
  },
  { $project: { _id: 0, name: 1, brand: 1, price: 1, stock: 1, rango_precio: 1, stock_status: 1 } },
  { $sort: { rango_precio: 1, brand: 1 } }
]);
```

### `$setWindowFields`: Ranking de precio por subcategoría
> Asigna un número de ranking dentro de cada grupo (ventana) sin colapsar los documentos como haría `$group`.

```javascript
db.products.aggregate([
  {
    $setWindowFields: {
      partitionBy: "$subcategory_id",
      sortBy: { price: -1 },
      output: {
        ranking_precio: {
          $rank: {}
        }
      }
    }
  },
  { $project: { _id: 0, subcategory_id: 1, name: 1, brand: 1, price: 1, ranking_precio: 1 } },
  { $sort: { subcategory_id: 1, ranking_precio: 1 } }
]);
```

---

## 6. Consultas de Análisis de Negocio

### Top clientes por gasto total (excluyendo cancelados y carritos)
```javascript
db.orders.aggregate([
  { $match: { status: { $nin: ["CART", "CANCELLED"] } } },
  {
    $group: {
      _id: "$user_id",
      total_gastado:  { $sum: { $toDouble: "$total" } },
      total_ordenes:  { $sum: 1 },
      ultima_compra:  { $max: "$order_date" }
    }
  },
  {
    $lookup: {
      from: "users",
      localField: "_id",
      foreignField: "id",
      as: "cliente"
    }
  },
  { $unwind: "$cliente" },
  {
    $project: {
      _id: 0,
      nombre: { $concat: ["$cliente.name", " ", "$cliente.last_name"] },
      email: "$cliente.email",
      total_gastado: 1,
      total_ordenes: 1,
      ultima_compra: 1
    }
  },
  { $sort: { total_gastado: -1 } }
]);
```

### Carritos abandonados con detalle del cliente y productos
```javascript
db.orders.aggregate([
  { $match: { status: "CART" } },
  {
    $lookup: {
      from: "users",
      localField: "user_id",
      foreignField: "id",
      as: "cliente"
    }
  },
  { $unwind: "$cliente" },
  { $unwind: "$items" },
  {
    $lookup: {
      from: "products",
      localField: "items.product_id",
      foreignField: "id",
      as: "producto"
    }
  },
  { $unwind: "$producto" },
  {
    $group: {
      _id: "$id",
      cliente:       { $first: { $concat: ["$cliente.name", " ", "$cliente.last_name"] } },
      email:         { $first: "$cliente.email" },
      fecha:         { $first: "$order_date" },
      valor_carrito: { $first: { $toDouble: "$total" } },
      productos_en_carrito: {
        $push: {
          nombre:   "$producto.name",
          marca:    "$producto.brand",
          cantidad: "$items.quantity",
          precio:   "$items.unit_price"
        }
      }
    }
  },
  { $sort: { valor_carrito: -1 } }
]);
```

### Productos sin ninguna orden registrada
> Usa `$lookup` con un array vacío como condición de "no coincidencia" (equivale a `LEFT JOIN ... WHERE b.id IS NULL`).

```javascript
db.products.aggregate([
  {
    $lookup: {
      from: "orders",
      let: { pid: "$id" },
      pipeline: [
        { $unwind: "$items" },
        { $match: { $expr: { $eq: ["$items.product_id", "$$pid"] } } }
      ],
      as: "ordenes_relacionadas"
    }
  },
  { $match: { ordenes_relacionadas: { $size: 0 } } },
  { $project: { _id: 0, id: 1, name: 1, brand: 1, subcategory_id: 1, stock: 1 } }
]);
```

### Reporte de ingresos por método de pago
```javascript
db.orders.aggregate([
  { $match: { "payment.status": "COMPLETED" } },
  {
    $group: {
      _id: "$payment.method",
      total_recaudado: { $sum: { $toDouble: "$payment.amount" } },
      num_transacciones: { $sum: 1 },
      promedio_por_venta: { $avg: { $toDouble: "$payment.amount" } }
    }
  },
  { $sort: { total_recaudado: -1 } }
]);
```

### Análisis de marcas: ingresos + stock + diversidad de modelos
```javascript
db.products.aggregate([
  { $match: { active: "1" } },
  {
    $group: {
      _id: "$brand",
      modelos:           { $sum: 1 },
      stock_total:       { $sum: { $toInt: "$stock" } },
      precio_promedio:   { $avg: { $toDouble: "$price" } },
      precio_mas_alto:   { $max: { $toDouble: "$price" } },
      precio_mas_bajo:   { $min: { $toDouble: "$price" } },
      subcategorias:     { $addToSet: "$subcategory_id" }
    }
  },
  {
    $addFields: {
      amplitud_catalogo: { $size: "$subcategorias" }
    }
  },
  { $project: { subcategorias: 0 } },
  { $sort: { modelos: -1 } }
]);
```
