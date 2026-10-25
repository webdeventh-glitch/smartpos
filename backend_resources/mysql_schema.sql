-- ============================================================
-- Smart POS System - MySQL Production Database Schema
-- Designed for Laravel / Next.js / React Web Cloud Backend
-- Engine: InnoDB | Charset: utf8mb4 | Collation: utf8mb4_unicode_ci
-- ============================================================

CREATE DATABASE IF NOT EXISTS `smartpos_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `smartpos_db`;

-- 1. Branches / Locations
CREATE TABLE IF NOT EXISTS `business_locations` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `location_id` VARCHAR(50) NOT NULL UNIQUE,
  `name` VARCHAR(150) NOT NULL,
  `landmark` VARCHAR(255) NULL,
  `city` VARCHAR(100) NULL,
  `state` VARCHAR(100) NULL,
  `country` VARCHAR(100) DEFAULT 'Pakistan',
  `zip_code` VARCHAR(20) NULL,
  `mobile` VARCHAR(50) NULL,
  `email` VARCHAR(100) NULL,
  `invoice_scheme` VARCHAR(50) DEFAULT 'INV-',
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Business Settings
CREATE TABLE IF NOT EXISTS `business_settings` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `business_name` VARCHAR(200) NOT NULL DEFAULT 'Smart POS System',
  `branch_name` VARCHAR(200) NOT NULL DEFAULT 'Main Branch HQ',
  `currency_symbol` VARCHAR(10) NOT NULL DEFAULT 'Rs',
  `currency_code` VARCHAR(10) NOT NULL DEFAULT 'PKR',
  `default_tax_rate` DECIMAL(5,2) DEFAULT 5.00,
  `phone` VARCHAR(50) NULL,
  `email` VARCHAR(100) NULL,
  `address` TEXT NULL,
  `invoice_prefix` VARCHAR(20) DEFAULT 'INV-',
  `receipt_footer` TEXT NULL,
  `purchase_key` VARCHAR(100) NULL,
  `business_type` VARCHAR(50) DEFAULT 'pharmacy',
  `sync_mode` VARCHAR(20) DEFAULT 'hybrid',
  `enabled_modules` TEXT NULL,
  `time_zone` VARCHAR(50) DEFAULT 'Asia/Karachi',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. Categories
CREATE TABLE IF NOT EXISTS `categories` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(150) NOT NULL UNIQUE,
  `code` VARCHAR(50) NOT NULL,
  `description` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 4. Brands
CREATE TABLE IF NOT EXISTS `brands` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(150) NOT NULL UNIQUE,
  `description` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 5. Products Catalog
CREATE TABLE IF NOT EXISTS `products` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `branch_id` INT UNSIGNED DEFAULT 1,
  `sku` VARCHAR(100) NOT NULL UNIQUE,
  `barcode` VARCHAR(100) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `category_name` VARCHAR(150) NULL,
  `brand_name` VARCHAR(150) NULL,
  `unit` VARCHAR(50) DEFAULT 'Pc',
  `purchase_price` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `selling_price` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `stock_quantity` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `alert_quantity` DECIMAL(12,2) DEFAULT 5.00,
  `batch_number` VARCHAR(100) DEFAULT '',
  `expiry_date` VARCHAR(50) DEFAULT '',
  `pack_size` DECIMAL(10,2) DEFAULT 1.00,
  `bonus_qty` DECIMAL(10,2) DEFAULT 0.00,
  `is_synced` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_prod_barcode` (`barcode`),
  INDEX `idx_prod_name` (`name`)
) ENGINE=InnoDB;

-- 6. Contacts (Customers & Suppliers)
CREATE TABLE IF NOT EXISTS `contacts` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `type` ENUM('customer', 'supplier', 'both') NOT NULL DEFAULT 'customer',
  `name` VARCHAR(200) NOT NULL,
  `business_name` VARCHAR(200) NULL,
  `phone` VARCHAR(50) NULL,
  `email` VARCHAR(100) NULL,
  `address` TEXT NULL,
  `balance` DECIMAL(12,2) DEFAULT 0.00,
  `credit_limit` DECIMAL(12,2) DEFAULT 50000.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_contact_type` (`type`),
  INDEX `idx_contact_phone` (`phone`)
) ENGINE=InnoDB;

-- 7. Sales Header
CREATE TABLE IF NOT EXISTS `sales` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `branch_id` INT UNSIGNED DEFAULT 1,
  `invoice_no` VARCHAR(100) NOT NULL UNIQUE,
  `customer_id` INT UNSIGNED NULL,
  `customer_name` VARCHAR(200) NOT NULL DEFAULT 'Walk-in Customer',
  `subtotal` DECIMAL(12,2) NOT NULL,
  `discount` DECIMAL(12,2) DEFAULT 0.00,
  `tax_amount` DECIMAL(12,2) DEFAULT 0.00,
  `tax_rate` DECIMAL(5,2) DEFAULT 0.00,
  `shipping` DECIMAL(12,2) DEFAULT 0.00,
  `total_amount` DECIMAL(12,2) NOT NULL,
  `paid_amount` DECIMAL(12,2) NOT NULL,
  `payment_method` VARCHAR(50) DEFAULT 'cash',
  `payment_status` VARCHAR(50) DEFAULT 'paid',
  `sale_status` VARCHAR(50) DEFAULT 'final',
  `note` TEXT NULL,
  `synced_from_device` VARCHAR(100) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_sales_inv` (`invoice_no`),
  INDEX `idx_sales_created` (`created_at`)
) ENGINE=InnoDB;

-- 8. Sale Items
CREATE TABLE IF NOT EXISTS `sale_items` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `sale_id` INT UNSIGNED NOT NULL,
  `product_id` INT UNSIGNED NULL,
  `product_name` VARCHAR(255) NOT NULL,
  `sku` VARCHAR(100) NULL,
  `batch_number` VARCHAR(100) NULL,
  `quantity` DECIMAL(10,2) NOT NULL,
  `unit_price` DECIMAL(12,2) NOT NULL,
  `subtotal` DECIMAL(12,2) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`sale_id`) REFERENCES `sales`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 9. Sync Audit Log
CREATE TABLE IF NOT EXISTS `sync_logs` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `branch_id` INT UNSIGNED DEFAULT 1,
  `direction` ENUM('push', 'pull') NOT NULL,
  `entity_type` VARCHAR(50) NOT NULL,
  `entity_id` VARCHAR(100) NOT NULL,
  `action` VARCHAR(50) NOT NULL,
  `status` ENUM('success', 'failed') NOT NULL,
  `payload` JSON NULL,
  `error_message` TEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Initial Seed Data
INSERT INTO `business_settings` (`id`, `business_name`, `business_type`, `sync_mode`)
VALUES (1, 'Smart POS System', 'pharmacy', 'hybrid')
ON DUPLICATE KEY UPDATE `updated_at` = NOW();
