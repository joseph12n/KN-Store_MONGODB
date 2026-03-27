-- ============================================================
-- KNStore - Schema refactorizado
-- Roles: ADMIN, MANAGER, CLIENT
-- ============================================================

DROP DATABASE IF EXISTS knstore;
CREATE DATABASE knstore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE knstore;

-- ============================================================
-- 1. USUARIOS
-- ============================================================
CREATE TABLE users (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    email       VARCHAR(150) NOT NULL UNIQUE,
    password    VARCHAR(255) NOT NULL,
    name        VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    role        ENUM('ADMIN', 'MANAGER', 'CLIENT') NOT NULL DEFAULT 'CLIENT',
    active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- 2. DIRECCIONES
-- ============================================================
CREATE TABLE address (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    street      VARCHAR(200) NOT NULL,
    number      VARCHAR(20)  NOT NULL,
    city        VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20),
    is_default  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_address_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_address_user ON address(user_id);

-- ============================================================
-- 3. CATEGORIAS
-- ============================================================
CREATE TABLE category (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255),
    active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- 4. SUBCATEGORIAS
-- ============================================================
CREATE TABLE subcategory (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    name        VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_subcategory_category
        FOREIGN KEY (category_id) REFERENCES category(id)
        ON DELETE CASCADE,

    UNIQUE KEY uk_subcategory_name (category_id, name)
) ENGINE=InnoDB;

CREATE INDEX idx_subcategory_category ON subcategory(category_id);

-- ============================================================
-- 5. PRODUCTOS
-- ============================================================
CREATE TABLE product (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    subcategory_id  INT NOT NULL,
    name            VARCHAR(150) NOT NULL,
    price           DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    size            VARCHAR(50),
    stock           INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    brand           VARCHAR(100),
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_product_subcategory
        FOREIGN KEY (subcategory_id) REFERENCES subcategory(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_product_subcategory ON product(subcategory_id);
CREATE INDEX idx_product_brand       ON product(brand);

-- ============================================================
-- 6. ORDENES
-- ============================================================
CREATE TABLE orders (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT NOT NULL,
    address_id  INT NOT NULL,
    order_date  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status      ENUM('CART', 'PENDING', 'CONFIRMED', 'SHIPPED', 'DELIVERED', 'CANCELLED')
                    NOT NULL DEFAULT 'CART',
    total       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_order_user
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_address
        FOREIGN KEY (address_id) REFERENCES address(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_order_user   ON orders(user_id);
CREATE INDEX idx_order_status ON orders(status);

-- ============================================================
-- 7. ITEMS DE ORDEN
-- ============================================================
CREATE TABLE order_item (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    order_id    INT NOT NULL,
    product_id  INT NOT NULL,
    quantity    INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price  DECIMAL(10,2) NOT NULL,
    subtotal    DECIMAL(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,

    CONSTRAINT fk_item_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_item_product
        FOREIGN KEY (product_id) REFERENCES product(id)
        ON DELETE RESTRICT,

    UNIQUE KEY uk_order_product (order_id, product_id)
) ENGINE=InnoDB;

CREATE INDEX idx_item_order   ON order_item(order_id);
CREATE INDEX idx_item_product ON order_item(product_id);

-- ============================================================
-- 8. PAGOS
-- ============================================================
CREATE TABLE payment (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    order_id    INT NOT NULL,
    amount      DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    method      VARCHAR(50) NOT NULL,
    status      ENUM('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')
                    NOT NULL DEFAULT 'PENDING',
    paid_at     TIMESTAMP NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_payment_order ON payment(order_id);

-- ============================================================
-- 9. ENVIOS
-- ============================================================
CREATE TABLE shipment (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    order_id        INT NOT NULL,
    tracking_number VARCHAR(100),
    shipping_method VARCHAR(50) NOT NULL,
    status          ENUM('PENDING', 'SHIPPED', 'IN_TRANSIT', 'DELIVERED', 'RETURNED')
                        NOT NULL DEFAULT 'PENDING',
    shipped_at      TIMESTAMP NULL,
    delivered_at    TIMESTAMP NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_shipment_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_shipment_order ON shipment(order_id);

-- ============================================================
-- 10. FACTURAS
-- ============================================================
CREATE TABLE bill (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    order_id    INT NOT NULL,
    reference   VARCHAR(50) NOT NULL UNIQUE,
    total       DECIMAL(12,2) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_bill_order
        FOREIGN KEY (order_id) REFERENCES orders(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE INDEX idx_bill_order ON bill(order_id);


-- ############################################################
--  DATOS DE PRUEBA
-- ############################################################

-- USUARIOS (1 admin, 2 managers, 5 clientes)
INSERT INTO users (email, password, name, last_name, role) VALUES
    ('admin@knstore.com',       SHA2('Admin@2026',    256), 'Carlos',    'Ramirez',    'ADMIN'),
    ('mgr.lopez@knstore.com',   SHA2('Manager@01',    256), 'Andrea',    'Lopez',      'MANAGER'),
    ('mgr.torres@knstore.com',  SHA2('Manager@02',    256), 'Felipe',    'Torres',     'MANAGER'),
    ('juan.perez@gmail.com',    SHA2('Cliente@01',    256), 'Juan',      'Perez',      'CLIENT'),
    ('maria.gomez@gmail.com',   SHA2('Cliente@02',    256), 'Maria',     'Gomez',      'CLIENT'),
    ('pedro.diaz@hotmail.com',  SHA2('Cliente@03',    256), 'Pedro',     'Diaz',       'CLIENT'),
    ('lucia.santos@yahoo.com',  SHA2('Cliente@04',    256), 'Lucia',     'Santos',     'CLIENT'),
    ('andres.ruiz@gmail.com',   SHA2('Cliente@05',    256), 'Andres',    'Ruiz',       'CLIENT');

-- DIRECCIONES (algunos clientes con 2 direcciones)
INSERT INTO address (user_id, street, number, city, postal_code, is_default) VALUES
    (4, 'Calle 100',          '15-30',   'Bogota',      '110111', TRUE),
    (4, 'Carrera 7',          '45-12',   'Bogota',      '110231', FALSE),
    (5, 'Avenida El Dorado',  '68B-35',  'Bogota',      '110321', TRUE),
    (6, 'Calle 80',           '22-10',   'Medellin',    '050021', TRUE),
    (6, 'Carrera 43A',        '1S-50',   'Medellin',    '050022', FALSE),
    (7, 'Avenida 6N',         '23N-45',  'Cali',        '760001', TRUE),
    (8, 'Calle 19',           '4-88',    'Bucaramanga', '680001', TRUE),
    (8, 'Carrera 33',         '52-10',   'Bucaramanga', '680003', FALSE);

-- CATEGORIAS (4)
INSERT INTO category (name, description) VALUES
    ('Electronica',    'Dispositivos y accesorios electronicos'),
    ('Ropa',           'Prendas de vestir y accesorios de moda'),
    ('Hogar',          'Articulos para el hogar y decoracion'),
    ('Deportes',       'Equipamiento y ropa deportiva');

-- SUBCATEGORIAS (2-3 por categoria = 10)
INSERT INTO subcategory (category_id, name, description) VALUES
    (1, 'Smartphones',          'Telefonos inteligentes'),
    (1, 'Audifonos',            'Audifonos inalambricos y con cable'),
    (1, 'Accesorios Tech',      'Cargadores, cables, fundas, protectores'),
    (2, 'Camisetas',            'Camisetas casuales y formales'),
    (2, 'Pantalones',           'Jeans, chinos, formales'),
    (2, 'Calzado',              'Zapatos, tenis, botas'),
    (3, 'Cocina',               'Utensilios y electrodomesticos de cocina'),
    (3, 'Decoracion',           'Articulos decorativos para el hogar'),
    (4, 'Fitness',              'Pesas, bandas, accesorios de gimnasio'),
    (4, 'Ropa Deportiva',       'Camisetas, shorts, licras deportivas');

-- PRODUCTOS (25 productos, 2-4 por subcategoria)
INSERT INTO product (subcategory_id, name, price, size, stock, brand) VALUES
    (1, 'Galaxy S24 Ultra',         4999000.00, '6.8"',    25,  'Samsung'),
    (1, 'iPhone 15 Pro Max',        5499000.00, '6.7"',    18,  'Apple'),
    (1, 'Pixel 8 Pro',             3299000.00, '6.7"',    30,  'Google'),
    (2, 'AirPods Pro 2',           999000.00,  'Unico',   40,  'Apple'),
    (2, 'WH-1000XM5',             1499000.00, 'Unico',   22,  'Sony'),
    (2, 'Galaxy Buds FE',          349000.00,  'Unico',   55,  'Samsung'),
    (3, 'Cargador USB-C 65W',      189000.00,  'Unico',   100, 'Anker'),
    (3, 'Cable Lightning 2m',       79000.00,  '2m',      200, 'Apple'),
    (3, 'Funda Galaxy S24 Ultra',    89000.00,  'S24U',    80,  'Spigen'),
    (4, 'Camiseta Basica Algodon',   59000.00, 'M',       150, 'Koaj'),
    (4, 'Camiseta Polo Classic',    129000.00, 'L',       90,  'Lacoste'),
    (4, 'Camiseta Oversize Urban',   79000.00, 'XL',      120, 'Pull&Bear'),
    (5, 'Jean Slim Fit',           159000.00,  '32',      70,  'Levis'),
    (5, 'Pantalon Chino Beige',    119000.00,  '30',      85,  'Dockers'),
    (5, 'Jean Mom Fit',            139000.00,  '28',      60,  'Zara'),
    (6, 'Air Force 1 Low',         459000.00,  '42',      35,  'Nike'),
    (6, 'Stan Smith',              389000.00,  '40',      40,  'Adidas'),
    (6, 'Old Skool Classic',       329000.00,  '41',      50,  'Vans'),
    (7, 'Licuadora 700W',         249000.00,  '1.5L',    45,  'Oster'),
    (7, 'Sarten Antiadherente',     89000.00,  '28cm',    60,  'T-Fal'),
    (7, 'Juego Cuchillos x6',     199000.00,  '6pzs',    30,  'Tramontina'),
    (8, 'Lampara LED Mesa',        149000.00,  '35cm',    25,  'Philips'),
    (8, 'Cojin Decorativo',         49000.00,  '45x45',   80,  'Nordic'),
    (9, 'Kit Mancuernas 20kg',     289000.00,  '20kg',    20,  'Bodytone'),
    (9, 'Banda Elastica Set x5',    69000.00,  'Multi',   100, 'TheraBand'),
    (10, 'Camiseta DRI-FIT',       159000.00,  'M',       60,  'Nike'),
    (10, 'Short Running',          119000.00,  'L',       75,  'Adidas');

-- ORDENES (7 ordenes en distintos estados)
INSERT INTO orders (user_id, address_id, order_date, status, total) VALUES
    (4, 1, '2026-01-15 10:30:00', 'DELIVERED',  6187000.00),
    (5, 3, '2026-02-20 14:15:00', 'SHIPPED',    1747000.00),
    (6, 4, '2026-03-01 09:00:00', 'CONFIRMED',   474000.00),
    (7, 6, '2026-03-10 16:45:00', 'PENDING',     848000.00),
    (8, 7, '2026-03-25 20:00:00', 'CART',         378000.00),
    (4, 2, '2026-02-05 11:00:00', 'CANCELLED',   459000.00),
    (6, 5, '2026-01-28 08:30:00', 'DELIVERED',    448000.00);

-- ITEMS DE ORDEN (subtotal se calcula solo)
INSERT INTO order_item (order_id, product_id, quantity, unit_price) VALUES
    (1, 1,  1, 4999000.00),
    (1, 4,  1,  999000.00),
    (1, 7,  1,  189000.00),
    (2, 5,  1, 1499000.00),
    (2, 11, 1,  129000.00),
    (2, 14, 1,  119000.00),
    (3, 10, 3,   59000.00),
    (3, 13, 1,  159000.00),
    (3, 25, 2,   69000.00),
    (4, 16, 1,  459000.00),
    (4, 17, 1,  389000.00),
    (5, 20, 1,   89000.00),
    (5, 24, 1,  289000.00),
    (6, 16, 1,  459000.00),
    (7, 18, 1,  329000.00),
    (7, 27, 1,  119000.00);

-- PAGOS
INSERT INTO payment (order_id, amount, method, status, paid_at) VALUES
    (1, 6187000.00, 'Tarjeta Credito',    'COMPLETED', '2026-01-15 10:35:00'),
    (2, 1747000.00, 'PSE',                'COMPLETED', '2026-02-20 14:20:00'),
    (3,  474000.00, 'Nequi',              'COMPLETED', '2026-03-01 09:10:00'),
    (4,  848000.00, 'Tarjeta Debito',     'PENDING',    NULL),
    (6,  459000.00, 'Tarjeta Credito',    'REFUNDED',  '2026-02-06 09:00:00'),
    (7,  448000.00, 'Contra Entrega',     'COMPLETED', '2026-01-30 14:00:00');

-- ENVIOS
INSERT INTO shipment (order_id, tracking_number, shipping_method, status, shipped_at, delivered_at) VALUES
    (1, 'KN-2026-00001', 'Servientrega',   'DELIVERED',  '2026-01-16 08:00:00', '2026-01-19 14:30:00'),
    (2, 'KN-2026-00002', 'Interrapidisimo', 'SHIPPED',   '2026-02-21 10:00:00',  NULL),
    (3,  NULL,            'Coordinadora',   'PENDING',    NULL,                   NULL),
    (7, 'KN-2026-00003', 'Contra Entrega',  'DELIVERED', '2026-01-29 09:00:00', '2026-01-30 14:00:00');

-- FACTURAS
INSERT INTO bill (order_id, reference, total) VALUES
    (1, 'FAC-2026-00001', 6187000.00),
    (2, 'FAC-2026-00002', 1747000.00),
    (3, 'FAC-2026-00003',  474000.00),
    (7, 'FAC-2026-00004',  448000.00);