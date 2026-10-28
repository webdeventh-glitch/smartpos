-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Oct 26, 2026 at 06:01 AM
-- Server version: 8.0.30
-- PHP Version: 8.1.10

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `smartpos`
--

-- --------------------------------------------------------

--
-- Table structure for table `brands`
--

CREATE TABLE `brands` (
  `id` int UNSIGNED NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `brands`
--

INSERT INTO `brands` (`id`, `name`, `description`, `created_at`, `updated_at`) VALUES
(1, 'GSK', 'GlaxoSmithKline Pharmaceuticals', '2026-10-25 15:56:45', '2026-10-25 15:56:45'),
(2, 'Abbott', 'Abbott Healthcare', '2026-10-25 15:56:45', '2026-10-25 15:56:45'),
(3, 'Getz Pharma', 'Getz Formulations', '2026-10-25 15:56:45', '2026-10-25 15:56:45');

-- --------------------------------------------------------

--
-- Table structure for table `business_locations`
--

CREATE TABLE `business_locations` (
  `id` int UNSIGNED NOT NULL,
  `location_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `landmark` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'Pakistan',
  `zip_code` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `mobile` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `invoice_scheme` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'INV-',
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `business_settings`
--

CREATE TABLE `business_settings` (
  `id` int UNSIGNED NOT NULL,
  `business_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Smart POS Enterprise',
  `branch_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Main Branch HQ',
  `currency_symbol` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Rs',
  `currency_code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'PKR',
  `default_tax_rate` decimal(5,2) DEFAULT '0.00',
  `phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` text COLLATE utf8mb4_unicode_ci,
  `invoice_prefix` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'INV-',
  `receipt_footer` text COLLATE utf8mb4_unicode_ci,
  `purchase_key` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `business_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'general',
  `sync_mode` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'offline',
  `enabled_modules` text COLLATE utf8mb4_unicode_ci,
  `primary_db_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'mysql',
  `db_host` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT 'localhost',
  `db_port` int DEFAULT '3306',
  `db_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'smartpos',
  `db_user` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'root',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `categories`
--

CREATE TABLE `categories` (
  `id` int UNSIGNED NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `categories`
--

INSERT INTO `categories` (`id`, `name`, `code`, `description`, `created_at`, `updated_at`) VALUES
(1, 'Antibiotics & Medications', 'CAT-MED', 'Prescription pharmaceutical drugs', '2026-10-25 15:56:44', '2026-10-25 15:56:44'),
(2, 'OTC Medicines', 'CAT-OTC', 'Over the counter healthcare products', '2026-10-25 15:56:44', '2026-10-25 15:56:44'),
(3, 'General Merchandise', 'CAT-GEN', 'Everyday store goods', '2026-10-25 15:56:44', '2026-10-25 15:56:44');

-- --------------------------------------------------------

--
-- Table structure for table `contacts`
--

CREATE TABLE `contacts` (
  `id` int UNSIGNED NOT NULL,
  `type` enum('customer','supplier','both') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'customer',
  `name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `business_name` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` text COLLATE utf8mb4_unicode_ci,
  `balance` decimal(12,2) DEFAULT '0.00',
  `credit_limit` decimal(12,2) DEFAULT '50000.00',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `contacts`
--

INSERT INTO `contacts` (`id`, `type`, `name`, `business_name`, `phone`, `email`, `address`, `balance`, `credit_limit`, `created_at`, `updated_at`) VALUES
(1, 'customer', 'Walk-in Customer', 'Cash Retail Customer', '+92 300 0000000', 'walkin@smartpos.com', NULL, '0.00', '50000.00', '2026-10-25 15:56:45', '2026-10-25 15:56:45');

-- --------------------------------------------------------

--
-- Table structure for table `payment_transactions`
--

CREATE TABLE `payment_transactions` (
  `id` int UNSIGNED NOT NULL,
  `transaction_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `parent_id` int UNSIGNED DEFAULT NULL,
  `contact_id` int UNSIGNED DEFAULT NULL,
  `contact_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payment_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'cash',
  `amount` decimal(12,2) NOT NULL,
  `account_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'Cash Till',
  `transaction_date` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `created_by` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'Cashier',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `products`
--

CREATE TABLE `products` (
  `id` int UNSIGNED NOT NULL,
  `branch_id` int UNSIGNED DEFAULT '1',
  `sku` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `barcode` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `category_name` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `brand_name` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `unit` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'Pc',
  `purchase_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `selling_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `stock_quantity` decimal(12,2) NOT NULL DEFAULT '0.00',
  `alert_quantity` decimal(12,2) DEFAULT '5.00',
  `batch_number` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT '',
  `expiry_date` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT '',
  `pack_size` decimal(10,2) DEFAULT '1.00',
  `bonus_qty` decimal(10,2) DEFAULT '0.00',
  `is_synced` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `products`
--

INSERT INTO `products` (`id`, `branch_id`, `sku`, `barcode`, `name`, `category_name`, `brand_name`, `unit`, `purchase_price`, `selling_price`, `stock_quantity`, `alert_quantity`, `batch_number`, `expiry_date`, `pack_size`, `bonus_qty`, `is_synced`, `created_at`, `updated_at`) VALUES
(1, 1, 'MED-PAN-500', '896400010011', 'Panadol 500mg Tablets (Box of 200)', 'OTC Medicines', 'GSK', 'Box', '480.00', '600.00', '50.00', '10.00', 'B-9281', '2027-12-31', '1.00', '0.00', 1, '2026-10-25 15:56:45', '2026-10-25 15:56:45'),
(2, 1, 'MED-AUG-625', '896400010022', 'Augmentin 625mg Tablets', 'Antibiotics & Medications', 'GSK', 'Strip', '210.00', '260.00', '80.00', '15.00', 'B-4819', '2028-06-30', '1.00', '0.00', 1, '2026-10-25 15:56:45', '2026-10-25 15:56:45'),
(3, 1, 'MED-DIS-300', '896400010033', 'Disprin Soluble 300mg', 'OTC Medicines', 'Reckitt', 'Strip', '45.00', '60.00', '120.00', '20.00', 'B-7712', '2027-09-30', '1.00', '0.00', 1, '2026-10-25 15:56:45', '2026-10-25 15:56:45'),
(4, 1, 'MED-BRU-400', '896400010044', 'Brufen 400mg Tablets', 'Antibiotics & Medications', 'Abbott', 'Box', '180.00', '230.00', '65.00', '12.00', 'B-3321', '2027-11-30', '1.00', '0.00', 1, '2026-10-25 15:56:45', '2026-10-25 15:56:45'),
(5, 1, 'ANA-3771', 'PRD-8251', 'Deispren', 'Analgesics & Pain Relief', 'Proctable', 'Pieces (Pc)', '100.00', '125.00', '50.00', '5.00', 'ac980', '12-2026', '1.00', '0.00', 1, '2026-10-25 15:58:48', '2026-10-25 15:58:48');

-- --------------------------------------------------------

--
-- Table structure for table `purchases`
--

CREATE TABLE `purchases` (
  `id` int UNSIGNED NOT NULL,
  `branch_id` int UNSIGNED DEFAULT '1',
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `supplier_id` int UNSIGNED DEFAULT NULL,
  `supplier_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Supplier',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'received',
  `payment_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'paid',
  `total_amount` decimal(12,2) NOT NULL,
  `paid_amount` decimal(12,2) NOT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sales`
--

CREATE TABLE `sales` (
  `id` int UNSIGNED NOT NULL,
  `branch_id` int UNSIGNED DEFAULT '1',
  `invoice_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `customer_id` int UNSIGNED DEFAULT NULL,
  `customer_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Walk-in Customer',
  `subtotal` decimal(12,2) NOT NULL,
  `discount` decimal(12,2) DEFAULT '0.00',
  `tax_amount` decimal(12,2) DEFAULT '0.00',
  `tax_rate` decimal(5,2) DEFAULT '0.00',
  `shipping` decimal(12,2) DEFAULT '0.00',
  `total_amount` decimal(12,2) NOT NULL,
  `paid_amount` decimal(12,2) NOT NULL,
  `payment_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'cash',
  `payment_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'paid',
  `sale_status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'final',
  `note` text COLLATE utf8mb4_unicode_ci,
  `synced_from_device` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sales`
--

INSERT INTO `sales` (`id`, `branch_id`, `invoice_no`, `customer_id`, `customer_name`, `subtotal`, `discount`, `tax_amount`, `tax_rate`, `shipping`, `total_amount`, `paid_amount`, `payment_method`, `payment_status`, `sale_status`, `note`, `synced_from_device`, `created_at`, `updated_at`) VALUES
(1, 1, 'INV-1001', NULL, 'Walk-in Customer', '220.00', '0.00', '0.00', '0.00', '0.00', '220.00', '220.00', 'cash', 'paid', 'final', '', NULL, '2026-10-25 16:00:19', '2026-10-25 16:00:19');

-- --------------------------------------------------------

--
-- Table structure for table `sale_items`
--

CREATE TABLE `sale_items` (
  `id` int UNSIGNED NOT NULL,
  `sale_id` int UNSIGNED NOT NULL,
  `product_id` int UNSIGNED DEFAULT NULL,
  `product_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sku` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `batch_number` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` decimal(10,2) NOT NULL,
  `unit_price` decimal(12,2) NOT NULL,
  `subtotal` decimal(12,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sale_items`
--

INSERT INTO `sale_items` (`id`, `sale_id`, `product_id`, `product_name`, `sku`, `batch_number`, `quantity`, `unit_price`, `subtotal`, `created_at`) VALUES
(1, 1, NULL, 'Disprin 300mg Soluble Tab', 'MED-006', 'DSP-1029', '1.00', '220.00', '220.00', '2026-10-25 16:00:19');

-- --------------------------------------------------------

--
-- Table structure for table `sync_logs`
--

CREATE TABLE `sync_logs` (
  `id` int UNSIGNED NOT NULL,
  `branch_id` int UNSIGNED DEFAULT '1',
  `direction` enum('push','pull') COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('success','failed') COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` json DEFAULT NULL,
  `error_message` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `sync_queue`
--

CREATE TABLE `sync_queue` (
  `id` int UNSIGNED NOT NULL,
  `entity_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload_json` longtext COLLATE utf8mb4_unicode_ci,
  `status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `retry_count` int DEFAULT '0',
  `last_error` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `synced_at` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `units`
--

CREATE TABLE `units` (
  `id` int UNSIGNED NOT NULL,
  `actual_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `short_name` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `allow_decimal` tinyint(1) DEFAULT '0',
  `base_unit_id` int UNSIGNED DEFAULT NULL,
  `base_unit_multiplier` decimal(10,2) DEFAULT '1.00',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `units`
--

INSERT INTO `units` (`id`, `actual_name`, `short_name`, `allow_decimal`, `base_unit_id`, `base_unit_multiplier`, `created_at`) VALUES
(1, 'Piece', 'Pc', 0, NULL, '1.00', '2026-10-25 15:56:45'),
(2, 'Box', 'Box', 0, NULL, '10.00', '2026-10-25 15:56:45'),
(3, 'Strip', 'Strip', 0, NULL, '1.00', '2026-10-25 15:56:45');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int UNSIGNED NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `username` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'cashier',
  `status` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `branch_id` int UNSIGNED DEFAULT '1',
  `branch_name` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT 'Main Branch HQ',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `username`, `password`, `email`, `phone`, `role`, `status`, `branch_id`, `branch_name`, `created_at`, `updated_at`) VALUES
(1, 'Irfan Khan', 'webdeventh', 'sha256$5da7ba0bdc614704fa0ba241778c6fca33c939cb025489530a74d9bf954581c4', 'admin@smartpos.com', '+92 300 1234567', 'superadmin', 'active', 1, 'Main Branch HQ', '2026-10-25 15:56:44', '2026-10-25 15:56:44');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `brands`
--
ALTER TABLE `brands`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `business_locations`
--
ALTER TABLE `business_locations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `location_id` (`location_id`);

--
-- Indexes for table `business_settings`
--
ALTER TABLE `business_settings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `categories`
--
ALTER TABLE `categories`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`);

--
-- Indexes for table `contacts`
--
ALTER TABLE `contacts`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_contact_type` (`type`),
  ADD KEY `idx_contact_phone` (`phone`);

--
-- Indexes for table `payment_transactions`
--
ALTER TABLE `payment_transactions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `products`
--
ALTER TABLE `products`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `sku` (`sku`),
  ADD KEY `idx_prod_barcode` (`barcode`),
  ADD KEY `idx_prod_name` (`name`);

--
-- Indexes for table `purchases`
--
ALTER TABLE `purchases`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `ref_no` (`ref_no`);

--
-- Indexes for table `sales`
--
ALTER TABLE `sales`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `invoice_no` (`invoice_no`),
  ADD KEY `idx_sales_inv` (`invoice_no`),
  ADD KEY `idx_sales_created` (`created_at`);

--
-- Indexes for table `sale_items`
--
ALTER TABLE `sale_items`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_sale_item_sale` (`sale_id`);

--
-- Indexes for table `sync_logs`
--
ALTER TABLE `sync_logs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sync_queue`
--
ALTER TABLE `sync_queue`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `units`
--
ALTER TABLE `units`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `brands`
--
ALTER TABLE `brands`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `business_locations`
--
ALTER TABLE `business_locations`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `business_settings`
--
ALTER TABLE `business_settings`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `categories`
--
ALTER TABLE `categories`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `contacts`
--
ALTER TABLE `contacts`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `payment_transactions`
--
ALTER TABLE `payment_transactions`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `products`
--
ALTER TABLE `products`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `purchases`
--
ALTER TABLE `purchases`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sales`
--
ALTER TABLE `sales`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `sale_items`
--
ALTER TABLE `sale_items`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `sync_logs`
--
ALTER TABLE `sync_logs`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `sync_queue`
--
ALTER TABLE `sync_queue`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `units`
--
ALTER TABLE `units`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

-- --------------------------------------------------------
-- Phase: Enterprise Expansion Tables (Matching SmartPOS Desktop Suite)
-- --------------------------------------------------------

--
-- Table structure for table `tax_rates`
--
CREATE TABLE IF NOT EXISTS `tax_rates` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(5,2) NOT NULL DEFAULT '0.00',
  `is_tax_group` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `tax_rates` (`id`, `name`, `amount`, `is_tax_group`) VALUES
(1, 'No Tax (0%)', '0.00', 0),
(2, 'Standard VAT (5%)', '5.00', 0),
(3, 'GST / Sales Tax (15%)', '15.00', 0)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

--
-- Table structure for table `invoice_schemes`
--
CREATE TABLE IF NOT EXISTS `invoice_schemes` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `scheme_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'blank',
  `prefix` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'INV-',
  `start_number` int DEFAULT '1001',
  `invoice_count` int DEFAULT '0',
  `total_digits` int DEFAULT '4',
  `is_default` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `invoice_schemes` (`id`, `name`, `scheme_type`, `prefix`, `start_number`, `invoice_count`, `total_digits`, `is_default`) VALUES
(1, 'Default Format (INV-XXXX)', 'blank', 'INV-', 1001, 1, 4, 1),
(2, 'Yearly Format (INV-YYYY-XXXX)', 'year', 'INV-', 1, 0, 4, 0)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

--
-- Table structure for table `selling_price_groups`
--
CREATE TABLE IF NOT EXISTS `selling_price_groups` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `selling_price_groups` (`id`, `name`, `description`, `is_active`) VALUES
(1, 'Retail Price', 'Standard Walk-in customer price', 1),
(2, 'Wholesale Price', 'Bulk purchase price with volume margin', 1),
(3, 'Special VIP Price', 'Preferred loyal customer tier', 1)
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

--
-- Table structure for table `warranties`
--
CREATE TABLE IF NOT EXISTS `warranties` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `duration` int NOT NULL DEFAULT '0',
  `duration_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'months',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `warranties` (`id`, `name`, `description`, `duration`, `duration_type`) VALUES
(1, '1 Year Standard Warranty', 'Full replacement & parts warranty', 12, 'months'),
(2, '6 Months Limited Warranty', 'Hardware warranty only', 6, 'months'),
(3, 'No Warranty', 'Consumables & fresh food', 0, 'days')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

--
-- Table structure for table `variation_templates`
--
CREATE TABLE IF NOT EXISTS `variation_templates` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `values_json` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `variation_templates` (`id`, `name`, `values_json`) VALUES
(1, 'Size', '["S","M","L","XL","XXL"]'),
(2, 'Color', '["Black","White","Navy Blue","Crimson Red","Olive Green"]'),
(3, 'Storage Capacity', '["64GB","128GB","256GB","512GB"]')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

--
-- Table structure for table `variations`
--
CREATE TABLE IF NOT EXISTS `variations` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `product_id` int UNSIGNED NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sub_sku` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `purchase_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `selling_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `stock_quantity` decimal(12,2) DEFAULT '0.00',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_var_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `expenses`
--
CREATE TABLE IF NOT EXISTS `expenses` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `category` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `cash_registers`
--
CREATE TABLE IF NOT EXISTS `cash_registers` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `cashier_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `opening_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `closing_amount` decimal(12,2) DEFAULT '0.00',
  `total_sales_cash` decimal(12,2) DEFAULT '0.00',
  `total_sales_card` decimal(12,2) DEFAULT '0.00',
  `total_sales_other` decimal(12,2) DEFAULT '0.00',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'open',
  `opened_at` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `closed_at` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `parked_sales`
--
CREATE TABLE IF NOT EXISTS `parked_sales` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `customer_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `total` decimal(12,2) NOT NULL,
  `created_at` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `items_json` longtext COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `stock_transfers`
--
CREATE TABLE IF NOT EXISTS `stock_transfers` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL UNIQUE,
  `from_location_id` int UNSIGNED NOT NULL,
  `from_location_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `to_location_id` int UNSIGNED NOT NULL,
  `to_location_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'completed',
  `shipping_charges` decimal(12,2) DEFAULT '0.00',
  `final_total` decimal(12,2) DEFAULT '0.00',
  `date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `items_json` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `stock_adjustments`
--
CREATE TABLE IF NOT EXISTS `stock_adjustments` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL UNIQUE,
  `location_id` int UNSIGNED NOT NULL,
  `location_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `adjustment_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'normal',
  `total_amount` decimal(12,2) DEFAULT '0.00',
  `recovered_amount` decimal(12,2) DEFAULT '0.00',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `items_json` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `contact_payments`
--
CREATE TABLE IF NOT EXISTS `contact_payments` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `contact_id` int UNSIGNED NOT NULL,
  `contact_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payment_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `payment_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'cash',
  `date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `payment_accounts`
--
CREATE TABLE IF NOT EXISTS `payment_accounts` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `account_number` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `account_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'bank',
  `opening_balance` decimal(12,2) DEFAULT '0.00',
  `current_balance` decimal(12,2) DEFAULT '0.00',
  `note` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `payment_accounts` (`id`, `name`, `account_number`, `account_type`, `opening_balance`, `current_balance`, `note`) VALUES
(1, 'Main Store Cash Drawer', 'CASH-001', 'cash', '0.00', '0.00', 'Default Till / Front Counter Drawer'),
(2, 'Primary Bank Account', 'BANK-001', 'bank', '0.00', '0.00', 'Main business bank account')
ON DUPLICATE KEY UPDATE `name` = VALUES(`name`);

--
-- Table structure for table `account_transfers`
--
CREATE TABLE IF NOT EXISTS `account_transfers` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `from_account_id` int UNSIGNED NOT NULL,
  `from_account_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `to_account_id` int UNSIGNED NOT NULL,
  `to_account_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `sale_returns`
--
CREATE TABLE IF NOT EXISTS `sale_returns` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL UNIQUE,
  `sale_id` int UNSIGNED NOT NULL,
  `invoice_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `customer_id` int UNSIGNED DEFAULT NULL,
  `customer_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_amount` decimal(12,2) NOT NULL,
  `refund_amount` decimal(12,2) NOT NULL,
  `refund_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'cash',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'completed',
  `date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `items_json` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `sale_return_items`
--
CREATE TABLE IF NOT EXISTS `sale_return_items` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `return_id` int UNSIGNED NOT NULL,
  `product_id` int UNSIGNED NOT NULL,
  `product_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sku` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `batch_number` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` decimal(10,2) NOT NULL,
  `unit_price` decimal(12,2) NOT NULL,
  `subtotal` decimal(12,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_sret_ret` (`return_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `purchase_returns`
--
CREATE TABLE IF NOT EXISTS `purchase_returns` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `ref_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL UNIQUE,
  `purchase_id` int UNSIGNED NOT NULL,
  `purchase_ref` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `supplier_id` int UNSIGNED DEFAULT NULL,
  `supplier_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_amount` decimal(12,2) NOT NULL,
  `refund_amount` decimal(12,2) NOT NULL,
  `refund_method` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'cash',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'completed',
  `date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `items_json` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `purchase_return_items`
--
CREATE TABLE IF NOT EXISTS `purchase_return_items` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `return_id` int UNSIGNED NOT NULL,
  `product_id` int UNSIGNED NOT NULL,
  `product_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sku` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `batch_number` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` decimal(10,2) NOT NULL,
  `unit_price` decimal(12,2) NOT NULL,
  `subtotal` decimal(12,2) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_pret_ret` (`return_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `financial_years`
--
CREATE TABLE IF NOT EXISTS `financial_years` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `year_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `start_date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `end_date` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `closed_at` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `closed_by` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_sales` decimal(14,2) DEFAULT '0.00',
  `total_purchases` decimal(14,2) DEFAULT '0.00',
  `total_expenses` decimal(14,2) DEFAULT '0.00',
  `net_profit` decimal(14,2) DEFAULT '0.00',
  `closing_stock_value` decimal(14,2) DEFAULT '0.00',
  `carried_forward_balance` decimal(14,2) DEFAULT '0.00',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'closed',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `restaurant_tables`
--
CREATE TABLE IF NOT EXISTS `restaurant_tables` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `section` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'Main Dining',
  `capacity` int DEFAULT '4',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'vacant',
  `order_total` decimal(12,2) DEFAULT '0.00',
  `kot_time` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `guests` int DEFAULT '0',
  `current_order_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `waiter_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `waiter_id` int UNSIGNED DEFAULT NULL,
  `current_sale_id` int UNSIGNED DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `restaurant_kot_orders`
--
CREATE TABLE IF NOT EXISTS `restaurant_kot_orders` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `kot_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `table_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `order_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'Dine-In',
  `items` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'Cooking',
  `time` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `server_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT 'Captain',
  `items_json` longtext COLLATE utf8mb4_unicode_ci,
  `special_notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `gym_members`
--
CREATE TABLE IF NOT EXISTS `gym_members` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `member_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `plan` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fee` decimal(12,2) DEFAULT '0.00',
  `locker` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `trainer` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expiry_date` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `days_left` int DEFAULT '30',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'Active',
  `created_at` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `hotel_rooms`
--
CREATE TABLE IF NOT EXISTS `hotel_rooms` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `room` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `floor` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rate` decimal(12,2) DEFAULT '0.00',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'available',
  `guest` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nights` int DEFAULT '0',
  `check_in` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `room_service` decimal(12,2) DEFAULT '0.00',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `repair_jobs`
--
CREATE TABLE IF NOT EXISTS `repair_jobs` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `job_no` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `customer` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `device` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `imei` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `fault` text COLLATE utf8mb4_unicode_ci,
  `technician` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `est_cost` decimal(12,2) DEFAULT '0.00',
  `advance` decimal(12,2) DEFAULT '0.00',
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'Diagnosing',
  `date` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `product_serials_batches`
--
CREATE TABLE IF NOT EXISTS `product_serials_batches` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `product_id` int UNSIGNED NOT NULL,
  `product_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sku` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `serial_number_1` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `serial_number_2` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `batch_number` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `manufacturing_date` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expiry_date` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `warranty_months` int DEFAULT '0',
  `warranty_expiry_date` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'in_stock',
  `purchase_id` int UNSIGNED DEFAULT NULL,
  `sale_id` int UNSIGNED DEFAULT NULL,
  `location_id` int UNSIGNED DEFAULT '1',
  `purchase_price` decimal(12,2) DEFAULT '0.00',
  `selling_price` decimal(12,2) DEFAULT '0.00',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_serial_prod` (`product_id`),
  INDEX `idx_serial_batch` (`batch_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `product_bundles`
--
CREATE TABLE IF NOT EXISTS `product_bundles` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `parent_product_id` int UNSIGNED NOT NULL,
  `sub_product_id` int UNSIGNED NOT NULL,
  `sub_product_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sub_sku` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` decimal(10,2) NOT NULL DEFAULT '1.00',
  `unit_price` decimal(12,2) NOT NULL DEFAULT '0.00',
  `is_optional` tinyint(1) DEFAULT '0',
  `sort_order` int DEFAULT '0',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_bundle_parent` (`parent_product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Table structure for table `audit_logs`
--
CREATE TABLE IF NOT EXISTS `audit_logs` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `entity_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_id` int UNSIGNED DEFAULT NULL,
  `user_name` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `details` text COLLATE utf8mb4_unicode_ci,
  `old_values` longtext COLLATE utf8mb4_unicode_ci,
  `new_values` longtext COLLATE utf8mb4_unicode_ci,
  `ip_address` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `timestamp` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_audit_entity` (`entity_type`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `customer_groups`
--
CREATE TABLE IF NOT EXISTS `customer_groups` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(10,2) NOT NULL DEFAULT '0.00',
  `price_calculation_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'percentage',
  `selling_price_group_id` int UNSIGNED DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `customer_groups` (`id`, `name`, `amount`, `price_calculation_type`) VALUES
(1, 'Retail Customers (Walk-In)', '0.00', 'percentage'),
(2, 'Wholesale Clients (10% Tier)', '10.00', 'percentage'),
(3, 'VIP Club Members (5% Tier)', '5.00', 'percentage');

-- --------------------------------------------------------

--
-- Table structure for table `cash_denominations`
--
CREATE TABLE IF NOT EXISTS `cash_denominations` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `cash_register_id` int UNSIGNED DEFAULT NULL,
  `d5000` int DEFAULT '0',
  `d1000` int DEFAULT '0',
  `d500` int DEFAULT '0',
  `d100` int DEFAULT '0',
  `d50` int DEFAULT '0',
  `d20` int DEFAULT '0',
  `d10` int DEFAULT '0',
  `d5` int DEFAULT '0',
  `d2` int DEFAULT '0',
  `d1` int DEFAULT '0',
  `total_amount` decimal(12,2) DEFAULT '0.00',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `product_racks`
--
CREATE TABLE IF NOT EXISTS `product_racks` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `business_location_id` int UNSIGNED DEFAULT '1',
  `product_id` int UNSIGNED NOT NULL,
  `rack` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `row` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_rack_prod` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `types_of_services`
--
CREATE TABLE IF NOT EXISTS `types_of_services` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `location_id` int UNSIGNED DEFAULT '1',
  `packing_charge_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'fixed',
  `packing_charge` decimal(10,2) DEFAULT '0.00',
  `enable_custom_fields` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `types_of_services` (`id`, `name`, `description`, `packing_charge`) VALUES
(1, 'Dine-In', 'Counter / Dining Table Service', '0.00'),
(2, 'Takeaway / Parcel', 'Customer Parcel Pickup', '20.00'),
(3, 'Home Delivery', 'Rider / Courier Delivery', '150.00');

-- --------------------------------------------------------

--
-- Table structure for table `invoice_layouts`
--
CREATE TABLE IF NOT EXISTS `invoice_layouts` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `header_text` text COLLATE utf8mb4_unicode_ci,
  `footer_text` text COLLATE utf8mb4_unicode_ci,
  `show_logo` tinyint(1) DEFAULT '1',
  `show_tax` tinyint(1) DEFAULT '1',
  `show_customer` tinyint(1) DEFAULT '1',
  `show_barcode` tinyint(1) DEFAULT '1',
  `paper_width` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT '80mm',
  `is_default` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `invoice_layouts` (`id`, `name`, `header_text`, `footer_text`, `show_logo`, `show_tax`, `show_customer`, `paper_width`, `is_default`) VALUES
(1, 'Standard Thermal 80mm Layout', 'Welcome to our store!', 'Thank you for your business! Goods once sold cannot be returned without receipt.', 1, 1, 1, '80mm', 1);

-- --------------------------------------------------------

--
-- Table structure for table `discounts`
--
CREATE TABLE IF NOT EXISTS `discounts` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `discount_type` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT 'percentage',
  `discount_amount` decimal(10,2) DEFAULT '0.00',
  `starts_at` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ends_at` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `brand_id` int UNSIGNED DEFAULT NULL,
  `category_id` int UNSIGNED DEFAULT NULL,
  `location_id` int UNSIGNED DEFAULT NULL,
  `priority` int DEFAULT '1',
  `is_active` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `document_and_notes`
--
CREATE TABLE IF NOT EXISTS `document_and_notes` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `notable_id` int UNSIGNED NOT NULL,
  `notable_type` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `heading` varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `media_path` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_note_parent` (`notable_type`, `notable_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


COMMIT;


/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
