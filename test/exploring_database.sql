USE Data_Ware_House;
GO

--===================================================================================================
--1. Exploring the Database
--===================================================================================================

--Exploring All the objects in the database
SELECT * FROM INFORMATION_SCHEMA.TABLES;

--Exploring All The Columns in the database
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME='dim_customer_info';

--===================================================================================================
--2. Exploring The fact table
--===================================================================================================

--Ex-ploring The Dimensions Using Distinct
SELECT DISTINCT customer_country FROM gold.dim_customer_info;	--Exploring The countries.

SELECT DISTINCT 
    category_name,
    subcategory_name,		--Getting the Big picture about the products.
    product_name
FROM gold.dim_product_info
ORDER BY 1,2,3;	

--===================================================================================================
--3. Exploring Date Columns
--===================================================================================================

--Finding The first & last Date of order
--Finding Temporal difference between the first and last order
SELECT
	MIN(order_date) AS First_Order_Date,
	MAX(order_date) AS Last_Order_Date,
	DATEDIFF(YEAR,MIN(order_date),MAX(order_date)) AS Total_Years_Between_First_And_Last_Order
FROM gold.fact_sales;

--Finding The youngest and oldest customer
SELECT
	MIN(customer_birthdate) AS oldest_Customer_Birthdate,
	DATEDIFF(YEAR,MIN(customer_birthdate),GETDATE()) AS Age_Of_Oldest_Customer,
	MAX(customer_birthdate) AS youngest_Customer_Birthdate,
	DATEDIFF(YEAR,MAX(customer_birthdate),GETDATE()) AS Age_Of_Youngest_Customer,
	DATEDIFF(YEAR,MIN(customer_birthdate),MAX(customer_birthdate)) AS Age_Diff_Between_Youngest_And_Oldest_Customer
FROM gold.dim_customer_info;

--===================================================================================================
--Exploring The Measures
--===================================================================================================
SELECT 
    'Total Sales Amount' AS measure_name, 
    CAST(SUM(sales_amount) AS NUMERIC(18,2)) AS measure_value 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Quantity Sold', 
    CAST(SUM(quantity) AS NUMERIC(18,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Average Unit Price', 
    CAST(AVG(unit_price) AS NUMERIC(18,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Number Of Orders', 
    CAST(COUNT(DISTINCT sales_order_number) AS NUMERIC(18,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Number Products Sold', 
    CAST(COUNT(DISTINCT product_key) AS NUMERIC(18,2)) 
FROM gold.fact_sales

UNION ALL

SELECT 
    'Total Number Of Customers (With Orders)', 
    CAST(COUNT(DISTINCT customer_key) AS NUMERIC(18,2)) 
FROM gold.fact_sales

UNION ALL

-- Total Number of Products Sold in the database
SELECT 
    'Total Number Of Products In Database', 
    CAST(COUNT(DISTINCT product_key) AS NUMERIC(18,2)) 
FROM gold.dim_product_info

UNION ALL

-- Total Number of Customers in the database
SELECT 
    'Total Number Of Customers In Database', 
    CAST(COUNT(DISTINCT customer_key) AS NUMERIC(18,2)) 
FROM gold.dim_customer_info;

--===================================================================================================
--Exploring The Magnitude of the Measures
--===================================================================================================
--Total Number of Customers per Country
SELECT
	customer_country,
	COUNT(customer_key) AS Total_Customers_per_country	
FROM gold.dim_customer_info
GROUP BY customer_country
ORDER BY Total_Customers_per_country DESC;

--Total Number of Customers per Gender
SELECT
	customer_gender,
	COUNT(customer_key) AS Total_Customers_per_gender	
FROM gold.dim_customer_info
GROUP BY customer_gender
ORDER BY Total_Customers_per_gender DESC;

--Total Number of Products per Category
SELECT
	category_name,
	COUNT(product_key) AS Total_Products_per_category	
FROM gold.dim_product_info
GROUP BY category_name
ORDER BY Total_Products_per_category DESC;

--Average Product Cost per Category
SELECT
	category_name,
	AVG(product_cost) AS Average_Product_Cost_per_Category
FROM gold.dim_product_info
GROUP BY category_name
ORDER BY Average_Product_Cost_per_Category DESC;

--Total Revenue per Category
SELECT 
	dpi.category_name,
	SUM(fs.sales_amount) AS Total_revenue_per_Category
FROM gold.fact_sales fs
LEFT JOIN gold.dim_product_info dpi
	ON fs.product_key = dpi.product_key
	GROUP BY dpi.category_name
ORDER BY Total_revenue_per_Category DESC;

--Total Revenue per Customer
SELECT 
	dci.customer_key,
	dci.first_name,
	dci.last_name,
	SUM(fs.sales_amount) AS Total_revenue_per_Customer
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customer_info dci
	ON fs.customer_key = dci.customer_key
GROUP BY 
	dci.customer_key,
	dci.first_name,
	dci.last_name
ORDER BY Total_revenue_per_Customer DESC;

--Total Products Sold per Country
SELECT 
	dci.customer_country,
	COUNT(fs.quantity) AS Total_Products_Sold_per_Country
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customer_info dci
	ON fs.customer_key = dci.customer_key
GROUP BY 
	dci.customer_country
ORDER BY Total_Products_Sold_per_Country DESC;

--===================================================================================================
--ranking Based on their measures
--===================================================================================================
--Top 5 products based on their total revenue
SELECT TOP 5 
	dpi.product_name,
	SUM(fs.sales_amount) AS Total_revenue_per_Product	
FROM gold.fact_sales fs
LEFT JOIN gold.dim_product_info dpi
	ON fs.product_key = dpi.product_key
	GROUP BY dpi.product_name
ORDER BY Total_revenue_per_Product DESC;

--Worst 5 products based on their total revenue
SELECT TOP 5 
	dpi.product_name,
	SUM(fs.sales_amount) AS Total_revenue_per_Product	
FROM gold.fact_sales fs
LEFT JOIN gold.dim_product_info dpi
	ON fs.product_key = dpi.product_key
	GROUP BY dpi.product_name
ORDER BY Total_revenue_per_Product ASC;
