-- ============================================================
-- CONSULTAS DE SISTEMA - KNStore (Basadas en Datos de Prueba)
-- ============================================================

USE kn_store_test;

-- ============================================================
-- 1. GESTIÓN DE INVENTARIO Y CATÁLOGO
-- ============================================================

-- Listado de productos de "Electronica" con stock y marca
SELECT 
    p.name AS Producto, 
    p.brand AS Marca, 
    p.price AS Precio, 
    p.stock AS Disponibilidad,
    s.name AS Subcategoria
FROM product p
JOIN subcategory s ON p.subcategory_id = s.id
JOIN category c ON s.category_id = c.id
WHERE c.name = 'Electronica'
ORDER BY p.stock DESC;

-- Productos con stock bajo (Menos de 25 unidades)
-- Ideal para el MANAGER (Felipe Torres o Andrea Lopez)
SELECT name, brand, stock 
FROM product 
WHERE stock < 25
ORDER BY stock ASC;

-- ============================================================
-- 2. CLIENTES Y LOGÍSTICA
-- ============================================================

-- Ubicación de clientes: ¿Cuántos clientes tenemos por ciudad?
SELECT city, COUNT(*) AS total_clientes
FROM address
WHERE is_default = TRUE
GROUP BY city;

-- Reporte de envíos: Órdenes que aún no han sido entregadas
SELECT 
    o.id AS Orden_ID, 
    u.name AS Cliente, 
    s.shipping_method AS Transportadora, 
    s.status AS Estado_Envio,
    s.tracking_number AS Guia
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN shipment s ON o.id = s.order_id
WHERE s.status != 'DELIVERED';

-- ============================================================
-- 3. ANÁLISIS DE VENTAS (ADMIN / CONTABILIDAD)
-- ============================================================

-- Detalle de la venta más grande (Orden #1 de Juan Perez)
-- Muestra qué compró y cuánto pagó
SELECT 
    o.id AS Factura_Nro,
    p.name AS Articulo,
    oi.quantity AS Cant,
    oi.unit_price AS Precio_Unit,
    oi.subtotal AS Total_Item
FROM order_item oi
JOIN product p ON oi.product_id = p.id
JOIN orders o ON oi.order_id = o.id
WHERE o.id = 1;

-- Ranking de marcas más vendidas (por ingresos)
SELECT 
    p.brand AS Marca, 
    SUM(oi.quantity) AS Unidades_Vendidas,
    SUM(oi.subtotal) AS Total_Ventas_COP
FROM order_item oi
JOIN product p ON oi.product_id = p.id
JOIN orders o ON oi.order_id = o.id
WHERE o.status NOT IN ('CANCELLED', 'CART')
GROUP BY p.brand
ORDER BY Total_Ventas_COP DESC;

-- ============================================================
-- 4. ESTADO FINANCIERO Y PAGOS
-- ============================================================

-- Resumen de métodos de pago más utilizados
SELECT 
    method AS Metodo_Pago, 
    COUNT(*) AS Uso, 
    SUM(amount) AS Total_Recaudado
FROM payment
WHERE status = 'COMPLETED'
GROUP BY method;

-- Órdenes en "Carrito" (Potencial de venta perdida)
-- Muestra quién dejó productos en el carrito
SELECT 
    u.name, 
    u.email, 
    o.total AS Valor_Carrito, 
    o.order_date AS Desde_Cuando
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.status = 'CART';

-- ============================================================
-- 5. AUDITORÍA Y SEGURIDAD
-- ============================================================

-- Verificar qué facturas (Bill) corresponden a qué cliente y ciudad
SELECT 
    b.reference AS Nro_Factura, 
    u.name AS Cliente, 
    a.city AS Ciudad_Destino, 
    b.total AS Valor_Total
FROM bill b
JOIN orders o ON b.order_id = o.id
JOIN users u ON o.user_id = u.id
JOIN address a ON o.address_id = a.id;

-- Listado de personal administrativo (Admin y Managers)
SELECT name, last_name, email, role 
FROM users 
WHERE role IN ('ADMIN', 'MANAGER')
ORDER BY role ASC;