-- ############################################################
--  QUERIES DE VALIDACION
-- ############################################################

-- Q1: Resumen de usuarios por rol
SELECT role, COUNT(*) AS total_usuarios
FROM users
GROUP BY role
ORDER BY FIELD(role, 'ADMIN', 'MANAGER', 'CLIENT');

-- Q2: Catalogo completo (Categoria > Subcategoria > Producto)
SELECT
    c.name       AS categoria,
    s.name       AS subcategoria,
    p.name       AS producto,
    p.brand      AS marca,
    FORMAT(p.price, 0) AS precio,
    p.stock      AS stock
FROM product p
JOIN subcategory s ON p.subcategory_id = s.id
JOIN category c    ON s.category_id = c.id
WHERE p.active = TRUE
ORDER BY c.name, s.name, p.name;

-- Q3: Ordenes con detalle (subtotal autocalculado)
SELECT
    o.id                                AS orden,
    CONCAT(u.name, ' ', u.last_name)    AS cliente,
    o.status                            AS estado,
    p.name                              AS producto,
    oi.quantity                         AS cant,
    FORMAT(oi.unit_price, 0)            AS precio_unit,
    FORMAT(oi.subtotal, 0)              AS subtotal
FROM orders o
JOIN users u        ON o.user_id = u.id
JOIN order_item oi  ON oi.order_id = o.id
JOIN product p      ON oi.product_id = p.id
ORDER BY o.id, oi.id;

-- Q4: Validar que el total de la orden coincide con la suma de items
SELECT
    o.id                         AS orden,
    o.status                     AS estado,
    FORMAT(o.total, 0)           AS total_orden,
    FORMAT(SUM(oi.subtotal), 0)  AS suma_items,
    CASE
        WHEN o.total = SUM(oi.subtotal) THEN 'OK'
        ELSE 'DIFERENCIA'
    END AS validacion
FROM orders o
JOIN order_item oi ON oi.order_id = o.id
GROUP BY o.id, o.status, o.total;

-- Q5: Estado de pagos
SELECT
    o.id         AS orden,
    o.status     AS estado_orden,
    py.method    AS metodo_pago,
    py.status    AS estado_pago,
    FORMAT(py.amount, 0) AS monto,
    py.paid_at   AS fecha_pago
FROM orders o
LEFT JOIN payment py ON py.order_id = o.id
ORDER BY o.id;

-- Q6: Tracking de envios
SELECT
    o.id                                        AS orden,
    CONCAT(u.name, ' ', u.last_name)            AS cliente,
    CONCAT(a.street, ' ', a.number, ', ', a.city) AS destino,
    sh.tracking_number                          AS tracking,
    sh.shipping_method                          AS metodo,
    sh.status                                   AS estado,
    sh.shipped_at                               AS enviado,
    sh.delivered_at                              AS entregado
FROM orders o
JOIN users u      ON o.user_id = u.id
JOIN address a    ON o.address_id = a.id
LEFT JOIN shipment sh ON sh.order_id = o.id
WHERE o.status IN ('CONFIRMED', 'SHIPPED', 'DELIVERED')
ORDER BY o.order_date;

-- Q7: Ventas por categoria (excluyendo CART y CANCELLED)
SELECT
    c.name                          AS categoria,
    COUNT(DISTINCT o.id)            AS ordenes,
    SUM(oi.quantity)                AS unidades,
    FORMAT(SUM(oi.subtotal), 0)     AS ingresos
FROM order_item oi
JOIN orders o      ON oi.order_id = o.id
JOIN product p     ON oi.product_id = p.id
JOIN subcategory s ON p.subcategory_id = s.id
JOIN category c    ON s.category_id = c.id
WHERE o.status NOT IN ('CART', 'CANCELLED')
GROUP BY c.name
ORDER BY SUM(oi.subtotal) DESC;

-- Q8: Top 5 productos mas vendidos
SELECT
    p.name                          AS producto,
    p.brand                         AS marca,
    SUM(oi.quantity)                AS unidades,
    FORMAT(SUM(oi.subtotal), 0)     AS ingresos
FROM order_item oi
JOIN orders o  ON oi.order_id = o.id
JOIN product p ON oi.product_id = p.id
WHERE o.status NOT IN ('CART', 'CANCELLED')
GROUP BY p.id, p.name, p.brand
ORDER BY SUM(oi.quantity) DESC
LIMIT 5;

-- Q9: Clientes con mayor gasto
SELECT
    CONCAT(u.name, ' ', u.last_name) AS cliente,
    u.email,
    COUNT(DISTINCT o.id)              AS ordenes,
    FORMAT(SUM(o.total), 0)           AS gasto_total
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.role = 'CLIENT'
  AND o.status NOT IN ('CART', 'CANCELLED')
GROUP BY u.id, u.name, u.last_name, u.email
ORDER BY SUM(o.total) DESC;

-- Q10: Productos con stock bajo (menos de 25 unidades)
SELECT
    p.name   AS producto,
    p.brand  AS marca,
    p.stock  AS stock,
    s.name   AS subcategoria
FROM product p
JOIN subcategory s ON p.subcategory_id = s.id
WHERE p.stock < 25 AND p.active = TRUE
ORDER BY p.stock ASC;