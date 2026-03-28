# Guía de Consultas MongoDB — KN Store (Calzado)

Referencia de CRUD básico para pruebas en `mongosh`.

**Colecciones:** `categories`, `orders`, `products`, `users`

> **Nota:** Los campos `price`, `stock`, `quantity` y `total` están almacenados como `String`.

---

## Estructura rápida

```
db.<colección>.<operación>( <filtro>, <opciones> )
```

| SQL        | MongoDB                         |
|------------|---------------------------------|
| `INSERT`   | `insertOne()` / `insertMany()`  |
| `SELECT`   | `find()`                        |
| `UPDATE`   | `updateOne()` / `updateMany()`  |
| `DELETE`   | `deleteOne()` / `deleteMany()`  |

---

## categories

### CREATE
```javascript
db.categories.insertOne({
  id: "4",
  name: "Calzado Casual",
  subcategories: [
    { id: "10", name: "Sneakers" },
    { id: "11", name: "Mocasines" }
  ],
  created_at: [],
  updated_at: []
});
```

### READ
```javascript
db.categories.find({ name: "Calzado Casual" });
```

### UPDATE
```javascript
db.categories.updateOne(
  { id: "4" },
  { $set: { name: "Calzado Casual Urbano", updated_at: [] } }
);
```

### DELETE
```javascript
db.categories.deleteOne({ id: "4" });
```

---

## orders

### CREATE
```javascript
db.orders.insertOne({
  id: "21",
  user_id: "3",
  status: "PENDING",
  total: "469000.00",
  order_date: [],
  items: [
    {
      product_id: "5",
      quantity: "1",
      unit_price: "469000.00"
    }
  ],
  payment: {
    method: "CREDIT_CARD",
    status: "PENDING",
    amount: "469000.00"
  },
  created_at: [],
  updated_at: []
});
```

### READ
```javascript
db.orders.find({ user_id: "3" });
```

### UPDATE
```javascript
db.orders.updateOne(
  { id: "21" },
  { $set: { status: "DELIVERED", updated_at: [] } }
);
```

### DELETE
```javascript
db.orders.deleteOne({ id: "21" });
```

---

## products

### CREATE
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
  created_at: [],
  updated_at: []
});
```

### READ
```javascript
db.products.find({ brand: "New Balance" });
```

### UPDATE
```javascript
db.products.updateOne(
  { id: "26" },
  { $set: { price: "549000.00", updated_at: [] } }
);
```

### DELETE
```javascript
db.products.deleteOne({ id: "26" });
```

---

## users

### CREATE
```javascript
db.users.insertOne({
  id: "9",
  name: "Laura",
  last_name: "Mendoza",
  email: "laura.mendoza@email.com",
  password: "hashed_password",
  role: "CLIENT",
  addresses: [
    {
      id: "1",
      street: "Calle 45",
      number: "12-30",
      city: "Bogota",
      postal_code: "110111",
      is_default: "1"
    }
  ],
  created_at: [],
  updated_at: []
});
```

### READ
```javascript
db.users.find({ email: "laura.mendoza@email.com" });
```

### UPDATE
```javascript
db.users.updateOne(
  { id: "9" },
  { $set: { email: "l.mendoza@email.com", updated_at: [] } }
);
```

### DELETE
```javascript
db.users.deleteOne({ id: "9" });
```
