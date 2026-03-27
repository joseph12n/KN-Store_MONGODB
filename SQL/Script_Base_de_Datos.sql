-- ============================================================
-- KNStore - Schema refactorizado
-- Roles: ADMIN, MANAGER, CLIENT
-- ============================================================

DROP DATABASE IF EXISTS knstore;
CREATE DATABASE knstore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE knstore;

-- ============================================================
-- 1. USUARIOS (unificado con rol)
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
-- 2. DIRECCIONES (un usuario puede tener varias)
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
-- 3. CATEGORÍAS
-- ============================================================
CREATE TABLE category (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255),
    active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- 4. SUBCATEGORÍAS
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
-- 6. ÓRDENES
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
-- 7. ITEMS DE ORDEN (reemplaza Shopping_Cart + Item_Shopping_Cart)
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
-- 9. ENVÍOS (status como ENUM, no booleanos separados)
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

-- ============================================================
-- DATOS SEMILLA (opcional)
-- ============================================================

-- Admin por defecto
INSERT INTO users (email, password, name, last_name, role)
VALUES ('admin@knstore.com', SHA2('admin123', 256), 'Admin', 'KNStore', 'ADMIN');

-- Categorías de ejemplo
INSERT INTO category (name, description) VALUES
    ('Electrónica',    'Dispositivos y accesorios electrónicos'),
    ('Ropa',           'Prendas de vestir y accesorios'),
    ('Hogar',          'Artículos para el hogar');

-- Subcategorías de ejemplo
INSERT INTO subcategory (category_id, name, description) VALUES
    (1, 'Smartphones',     'Teléfonos inteligentes'),
    (1, 'Accesorios',      'Cargadores, cables, fundas'),
    (2, 'Camisetas',       'Camisetas casuales y formales'),
    (2, 'Pantalones',      'Jeans, chinos, formales'),
    (3, 'Cocina',          'Utensilios y electrodomésticos de cocina'),
    (3, 'Decoración',      'Artículos decorativos');
