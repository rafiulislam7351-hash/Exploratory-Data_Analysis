CREATE OR ALTER VIEW gold.view_product_analytics AS
/*
==================================================================================
Product Report
==================================================================================
Purpose:
    - This report consolidates key product metrics and behaviors.

Highlights:
    1. Gathers essential fields such as product name, category, subcategory, and cost.
    2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    3. Aggregates product-level metrics: total orders, total sales, quantity sold, etc.
    4. Calculates valuable KPIs: recency, average order revenue (AOR), and monthly revenue.
==================================================================================
*/

-- Step 1: Pre-aggregate heavy transactional data by product_key
WITH AggregatedProducts AS (
    SELECT 
        product_key,
        COUNT(DISTINCT sales_order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity_sold,
        COUNT(DISTINCT customer_key) AS total_customers_unique,
        MIN(order_date) AS first_sale_date,
        MAX(order_date) AS latest_sale_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY product_key
),

-- Step 2: Combine aggregate sales metrics with descriptive product details
ProductDetails AS (
    SELECT 
        dp.product_key,
        dp.product_name,
        dp.category_name AS product_category,
        dp.subcategory_name AS product_subcategory,
        dp.product_cost,
        agg.total_orders,
        agg.total_sales,
        agg.total_quantity_sold,
        agg.total_customers_unique,
        agg.latest_sale_date,
        agg.lifespan
    FROM AggregatedProducts agg
    LEFT JOIN gold.dim_product_info dp ON agg.product_key = dp.product_key
)

-- Step 3: Compute final business KPIs and performance segmentations
SELECT 
    product_key,
    product_name,
    product_category,
    product_subcategory,
    product_cost,
    total_orders,
    total_sales,
    total_quantity_sold,
    total_customers_unique,
    lifespan,
    latest_sale_date,

    -- KPI 1: Recency (Months elapsed since the product's last sale)
    DATEDIFF(MONTH, latest_sale_date, GETDATE()) AS recency,

    -- KPI 2: Average Order Revenue (AOR) with division safeguard
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS average_order_revenue,

    -- KPI 3: Average Monthly Revenue with division safeguard for single-month lifespans
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS average_monthly_revenue,

    -- Performance Segmentation based on total sales revenue brackets
    CASE 
        WHEN total_sales >= 50000 THEN 'High-Performer'
        WHEN total_sales BETWEEN 10000 AND 49999 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_performance_segment

FROM ProductDetails;
GO