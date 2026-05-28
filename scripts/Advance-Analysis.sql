USE Data_Ware_House;
GO
--=================================================================================================================================================================================================================================================================
-- This query retrieves the total sales, total quantity, and total number of orders grouped by year and month from the gold.fact_sales table. It filters out any records where the order_date is NULL and orders the results by year and month in descending order.
--==================================================================================================================================================================================================================================================================
SELECT 
	YEAR(order_date) AS order_year,
	FORMAT(order_date, 'MMM') AS order_month,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT sales_order_number) AS total_units_solds
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), FORMAT(order_date, 'MMM')
ORDER BY YEAR(order_date) DESC;

--=============================================================================================================================================================================================================================================================================================
-- The following query performs advanced analytics on the monthly sales data. It calculates cumulative total sales, a 3-month rolling average of sales, the weighted average price per month, average order value (AOV), and month-over-month (MoM) and year-over-year (YoY) growth percentages.
--=============================================================================================================================================================================================================================================================================================
WITH monthly_savings AS (
    SELECT
        DATETRUNC(month, order_date) AS order_month,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity, -- Added to calculate true weighted average price
        COUNT(DISTINCT sales_order_number) AS total_units_solds -- Added for average order value (AOV)
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month, order_date)
),
advanced_analytics AS (
    SELECT 
        order_month,
        total_sales,
        total_units_solds,
        -- 1. Cumulative Total (Running Total)
        SUM(total_sales) OVER(
            ORDER BY order_month 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_total_sales,
        
        -- 2. True 3-Month Rolling Average Sales (Smoothes out seasonality)
        AVG(total_sales) OVER(
            ORDER BY order_month 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_month_avg_sales,
        
        -- 3.  Weighted Average Price per Month
        (total_sales / NULLIF(total_quantity, 0)) AS monthly_avg_price,
        
        -- 4. Month-over-Month (MoM) Sales Performance
        LAG(total_sales, 1) OVER(ORDER BY order_month) AS previous_month_sales,
        
        -- 5. Year-over-Year (YoY) Sales Performance 
        LAG(total_sales, 12) OVER(ORDER BY order_month) AS previous_year_month_sales
    FROM monthly_savings
)
SELECT
    order_month,
    total_sales,
    cumulative_total_sales,
    rolling_3_month_avg_sales,
    ROUND(monthly_avg_price, 2) AS monthly_avg_price,
    
    -- Average Order Value (AOV)
    ROUND(total_sales / NULLIF(total_units_solds, 0), 2) AS average_order_value,
    
    -- MoM Growth %
    ROUND(((total_sales - previous_month_sales) / NULLIF(previous_month_sales, 0)) * 100, 2) AS mom_growth_pct,
    
    -- YoY Growth %
    ROUND(((total_sales - previous_year_month_sales) / NULLIF(previous_year_month_sales, 0)) * 100, 2) AS yoy_growth_pct
FROM advanced_analytics
ORDER BY order_month;


--=============================================================================================================================================================================================================================================================================================================================
-- The following query analyzes sales trends for each product by year. It calculates the current year's sales, compares it to the previous year's sales to determine if the trend is increasing, decreasing, or stable, and evaluates the performance of current year sales against the average sales per year for that product.
--=============================================================================================================================================================================================================================================================================================================================
WITH product_sales AS(
    SELECT 
        dp.product_name,
        SUM(fs.sales_amount) AS current_year_sales,
        YEAR(fs.order_date) AS order_year
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_product_info AS dp ON fs.product_key = dp.product_key
        WHERE fs.order_date IS NOT NULL
    GROUP BY dp.product_name, YEAR(fs.order_date))
   
SELECT 
    product_name,
    order_year,
    current_year_sales,
    LAG(current_year_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS previous_year_sales,
    CASE 
        WHEN LAG(current_year_sales) OVER(PARTITION BY product_name ORDER BY order_year) > current_year_sales THEN 'Increasing'
        WHEN LAG(current_year_sales) OVER(PARTITION BY product_name ORDER BY order_year) < current_year_sales THEN 'Decreasing'
        ELSE 'Stable'
    END AS sales_trend,
    AVG(current_year_sales) OVER(PARTITION BY product_name) AS avg_sales_per_year,
    CASE   
        WHEN current_year_sales > AVG(current_year_sales) OVER(PARTITION BY product_name) THEN 'Above Average'
        WHEN current_year_sales < AVG(current_year_sales) OVER(PARTITION BY product_name) THEN 'Below Average'
        ELSE 'Average'
    END AS sales_performance
FROM product_sales
ORDER BY product_name,order_year;

--==================================================================================================================================================================================================================================================================================
-- The following query provides a comprehensive analysis of sales performance by product category. It calculates total sales, quantity, cost, and profit for each category, and then computes the percentage contribution of each category to the overall totals for these measures.
--==================================================================================================================================================================================================================================================================================
WITH category_sales AS (
    SELECT 
        dp.category_name AS category_name,
        SUM(fs.sales_amount) AS total_sales,
        SUM(fs.quantity) AS total_quantity,        -- Standard measure for units sold
        SUM(dp.product_cost) AS total_product_cost,          -- Standard measure for product cost
        SUM(fs.sales_amount) - SUM(dp.product_cost) AS total_profit -- Derived profitability measure
    FROM gold.fact_sales AS fs
    LEFT JOIN gold.dim_product_info AS dp 
        ON fs.product_key = dp.product_key
    WHERE fs.order_date IS NOT NULL                 -- Filter out empty/invalid order dates
    GROUP BY dp.category_name
)
SELECT
    category_name,
    
    -- =========================================================================
    -- 1. QUANTITY / UNITS MEASURES
    -- =========================================================================
    total_quantity,
    SUM(total_quantity) OVER() AS overall_total_quantity,
    CONCAT(ROUND((CAST(total_quantity AS DECIMAL(10,2)) / NULLIF(SUM(total_quantity) OVER(), 0) * 100), 2), '%') AS category_quantity_percentage,
    
    -- =========================================================================
    -- 2. SALES AMOUNT MEASURES
    -- =========================================================================
    total_sales,
    SUM(total_sales) OVER() AS overall_total_sales,
    CONCAT(ROUND((CAST(total_sales AS DECIMAL(10,2)) / NULLIF(SUM(total_sales) OVER(), 0) * 100), 2), '%') AS category_sales_percentage,
    
    -- =========================================================================
    -- 3. COST MEASURES
    -- =========================================================================
    total_product_cost,
    SUM(total_product_cost) OVER() AS overall_total_product_cost,
    CONCAT(ROUND((CAST(total_product_cost AS DECIMAL(10,2)) / NULLIF(SUM(total_product_cost) OVER(), 0) * 100), 2), '%') AS category_product_cost_percentage   ,
    
    -- =========================================================================
    -- 4. PROFIT MEASURES
    -- =========================================================================
    total_profit,
    SUM(total_profit) OVER() AS overall_total_profit,
    CONCAT(ROUND((CAST(total_profit AS DECIMAL(10,2)) / NULLIF(SUM(total_profit) OVER(), 0) * 100), 2), '%') AS category_profit_percentage

FROM category_sales
ORDER BY total_sales DESC;

--=======================================================================================================================================================================================================================================
-- The following query categorizes products based on their cost into three categories: Low Cost (under 200), Medium Cost (between 200 and 1000), and High Cost (above 1000). It then counts the number of products in each cost category.
--=======================================================================================================================================================================================================================================
WITH product_cost_analysis AS (
SELECT 
    product_key,
    product_name,
    product_cost,
CASE    
    WHEN product_cost < 200 THEN 'Low Cost Under 200'
    WHEN product_cost BETWEEN 200 AND 1000 THEN 'Medium Cost Between 200 and 1000'
    ELSE 'High Cost Above 1000'
   END AS cost_category
FROM gold.dim_product_info)

SELECT 
    cost_category,
    COUNT(product_key) AS product_count
FROM product_cost_analysis
GROUP BY cost_category;

--==========================================================================================================================================================================================================================================================================================================================
-- The following query analyzes customer lifetime value by calculating total sales, first and last order dates, and customer lifetime in months. It then segments customers into three categories: High Value Long-Term Customers, Low Value Long-Term Customers, and New Customers based on their lifetime and total sales.
--==========================================================================================================================================================================================================================================================================================================================
WITH customer_lifetime AS (
SELECT 
    dc.customer_key AS customer_key,
    SUM(fs.sales_amount) AS total_sales,
    MIN(fs.order_date) AS first_order_date,
    MAX(fs.order_date) AS last_order_date,
    DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) AS customer_lifetime_months
FROM gold.fact_sales AS fs
LEFT JOIN gold.dim_customer_info AS dc ON fs.customer_key = dc.customer_key
    WHERE fs.order_date IS NOT NULL
GROUP BY dc.customer_key),

customer_segments AS (
SELECT 
    customer_key,
    total_sales,
    CASE 
        WHEN customer_lifetime_months>=12 AND total_sales > 5000 THEN 'High Value Long-Term Customer'
        WHEN customer_lifetime_months>=12 AND total_sales <= 5000 THEN 'Low Value Long-Term Customer'
        ELSE 'New Customer'
    END AS customer_segment
    FROM customer_lifetime)

SELECT
    COUNT(customer_key) AS customer_count,
    customer_segment
FROM customer_segments
GROUP BY customer_segment;