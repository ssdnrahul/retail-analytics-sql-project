-- =====================================
-- 🛒 RETAIL ANALYTICS SQL PROJECT
-- =====================================
-- Author: Rahul Chhabra
-- =====================================
-- 1. DATABASE SETUP & INITIAL EXPLORATION
-- =====================================

USE retail_analytics;

SHOW TABLES;

DESCRIBE sales_transaction;
DESCRIBE product_inventory;
DESCRIBE customer_profiles;

-- Preview datasets
SELECT * FROM customer_profiles;
SELECT * FROM product_inventory;
SELECT * FROM sales_transaction;

-- =====================================
-- 2. DATA CLEANING & PREPARATION
-- =====================================

-- Fix column name encoding issues (BOM characters)

ALTER TABLE customer_profiles
RENAME COLUMN ï»¿CustomerID TO CustomerID;

ALTER TABLE product_inventory
RENAME COLUMN ï»¿ProductID TO ProductID;

ALTER TABLE sales_transaction
RENAME COLUMN ï»¿TransactionID TO TransactionID;

-- Check total records

SELECT COUNT(*) FROM customer_profiles;   -- Records: 1000
SELECT COUNT(*) FROM product_inventory;   -- Records: 200
SELECT COUNT(*) FROM sales_transaction;   -- Records: 5002

-- =====================================
-- 3. DATA VALIDATION & CLEANING
-- =====================================

-- Check missing/blank locations

SELECT COUNT(*)
FROM customer_profiles
WHERE Location IS NULL OR Location = '';

-- Replace missing values with 'Unknown'

UPDATE customer_profiles
SET Location = 'Unknown'
WHERE Location IS NULL OR Location = '';

-- Validate incorrect values

SELECT *
FROM sales_transaction
WHERE QuantityPurchased <= 0;

SELECT *
FROM sales_transaction
WHERE Price <= 0;

-- =====================================
-- 4. DUPLICATE HANDLING
-- =====================================

-- Identify duplicate transactions using TransactionID

SELECT TransactionID, COUNT(*)
FROM sales_transaction
GROUP BY TransactionID
HAVING COUNT(*) > 1;

-- Backup original table before modification

CREATE TABLE sales_transaction_backup AS
SELECT * FROM sales_transaction;

-- Remove duplicates as per case study requirement

CREATE TABLE sales_transaction_new AS
SELECT DISTINCT *
FROM sales_transaction;

-- Replace original table

-- Dropping table as per case study requirement
DROP TABLE sales_transaction;

ALTER TABLE sales_transaction_new
RENAME TO sales_transaction;

-- Validate record count after cleanup

SELECT COUNT(*) FROM sales_transaction;   -- Records: 5000

-- =====================================
-- 5. PRICE CONSISTENCY CHECK
-- =====================================

-- Identify price discrepancies between tables

SELECT s.TransactionID,
       s.Price AS TransactionPrice,
       p.Price AS InventoryPrice
FROM sales_transaction s
JOIN product_inventory p
ON s.ProductID = p.ProductID
WHERE s.Price <> p.Price;

-- Update mismatched prices

SET SQL_SAFE_UPDATES = 0;

UPDATE sales_transaction s
JOIN product_inventory p
ON s.ProductID = p.ProductID
SET s.Price = p.Price
WHERE s.Price <> p.Price;

-- =====================================
-- 6. DATE FORMAT STANDARDIZATION
-- =====================================

-- Convert TEXT date into DATE format

CREATE TABLE sales_transaction_new AS
SELECT *,
STR_TO_DATE(TransactionDate, '%d/%m/%y') AS TransactionDate_updated
FROM sales_transaction;

-- Replace original table

-- Dropping table as per case study requirement
DROP TABLE sales_transaction;

ALTER TABLE sales_transaction_new
RENAME TO sales_transaction;

-- Validate conversion

SELECT TransactionDate, TransactionDate_updated
FROM sales_transaction;

-- =====================================
-- 7. BUSINESS ANALYSIS
-- =====================================

-- Q1: Total sales and quantity per product
-- Insight: Identifies top-performing products

SELECT ProductID,
       SUM(QuantityPurchased) AS TotalUnitsSold,
       ROUND(SUM(QuantityPurchased * Price), 2) AS TotalSales
FROM sales_transaction
GROUP BY ProductID
ORDER BY TotalSales DESC;

-- Q2: Number of transactions per customer
-- Insight: Measures purchase frequency

SELECT CustomerID,
       COUNT(*) AS NumberOfTransactions
FROM sales_transaction
GROUP BY CustomerID
ORDER BY NumberOfTransactions DESC;

-- Q3: Category-wise performance
-- Insight: Helps identify categories to prioritize

SELECT p.Category,
       SUM(s.QuantityPurchased) AS TotalUnitsSold,
       ROUND(SUM(s.QuantityPurchased * s.Price), 2) AS TotalSales
FROM sales_transaction s
JOIN product_inventory p
ON s.ProductID = p.ProductID
GROUP BY p.Category
ORDER BY TotalSales DESC;

-- Q4: Top 10 products by revenue

SELECT ProductID,
       ROUND(SUM(QuantityPurchased * Price), 2) AS TotalRevenue
FROM sales_transaction
GROUP BY ProductID
ORDER BY TotalRevenue DESC
LIMIT 10;

-- Q5: Lowest selling products

SELECT ProductID,
       SUM(QuantityPurchased) AS TotalUnitsSold
FROM sales_transaction
GROUP BY ProductID
HAVING TotalUnitsSold > 0
ORDER BY TotalUnitsSold ASC
LIMIT 10;

-- =====================================
-- 8. SALES TREND ANALYSIS
-- =====================================

-- Daily sales trend

SELECT TransactionDate_updated AS DATETRANS,
       COUNT(TransactionID) AS TransactionCount,
       SUM(QuantityPurchased) AS TotalUnitsSold,
       ROUND(SUM(QuantityPurchased * Price), 2) AS TotalSales
FROM sales_transaction
GROUP BY DATETRANS
ORDER BY DATETRANS DESC;

-- Month-on-Month growth analysis

WITH sales AS (
    SELECT MONTH(TransactionDate_updated) AS Month,
           ROUND(SUM(QuantityPurchased * Price), 2) AS TotalSales
    FROM sales_transaction
    GROUP BY Month
)

SELECT Month,
       TotalSales,
       LAG(TotalSales) OVER (ORDER BY Month) AS PreviousMonthSales,
       ROUND(
           (TotalSales - LAG(TotalSales) OVER (ORDER BY Month)) /
           LAG(TotalSales) OVER (ORDER BY Month) * 100, 2
       ) AS MoM_Growth_Percentage
FROM sales
ORDER BY Month;

-- =====================================
-- 9. CUSTOMER ANALYSIS
-- =====================================

-- High-value customers

SELECT CustomerID,
       COUNT(*) AS NumberOfTransactions,
       ROUND(SUM(QuantityPurchased * Price), 2) AS TotalSpent
FROM sales_transaction
GROUP BY CustomerID
HAVING COUNT(*) > 10 AND TotalSpent > 1000
ORDER BY TotalSpent DESC;

-- Low-frequency customers

SELECT CustomerID,
       COUNT(*) AS NumberOfTransactions,
       ROUND(SUM(QuantityPurchased * Price), 2) AS TotalSpent
FROM sales_transaction
GROUP BY CustomerID
HAVING COUNT(*) <= 2
ORDER BY NumberOfTransactions ASC, TotalSpent DESC;

-- Repeat purchase behavior

SELECT CustomerID,
       ProductID,
       COUNT(*) AS TimesPurchased
FROM sales_transaction
GROUP BY CustomerID, ProductID
HAVING COUNT(*) > 1
ORDER BY TimesPurchased DESC;

-- Customer loyalty (time duration)

SELECT CustomerID,
       MIN(TransactionDate_updated) AS FirstPurchase,
       MAX(TransactionDate_updated) AS LastPurchase,
       DATEDIFF(MAX(TransactionDate_updated), MIN(TransactionDate_updated)) AS DaysBetweenPurchases
FROM sales_transaction
GROUP BY CustomerID
HAVING DaysBetweenPurchases > 0
ORDER BY DaysBetweenPurchases DESC;

-- =====================================
-- 10. CUSTOMER SEGMENTATION
-- =====================================

-- Segment customers based on purchase quantity

CREATE TABLE customer_segment AS
SELECT CustomerID,
       CASE
           WHEN SUM(QuantityPurchased) BETWEEN 1 AND 10 THEN 'Low'
           WHEN SUM(QuantityPurchased) BETWEEN 11 AND 30 THEN 'Medium'
           WHEN SUM(QuantityPurchased) > 30 THEN 'High'
       END AS CustomerSegment
FROM sales_transaction
GROUP BY CustomerID;

-- Count customers in each segment

SELECT CustomerSegment,
       COUNT(*) AS TotalCustomers
FROM customer_segment
GROUP BY CustomerSegment;