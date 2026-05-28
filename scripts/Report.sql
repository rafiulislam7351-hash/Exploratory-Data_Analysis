CREATE OR ALTER VIEW gold.view_customer_analytics AS
/*
==================================================================================
Description:   Provides a comprehensive 360-degree analytical view of customer
               purchasing behavior, demographics, and lifetime value segments.
Author:        Rafiul Islam
Date:          May 28, 2026
==================================================================================
*/

-- Step 1: Pre-aggregate the massive fact table by customer_key to prevent data explosion
WITH AggregatedSales AS (
    SELECT 
        customer_key,
        COUNT(DISTINCT product_key) AS total_products,
        COUNT(DISTINCT sales_order_number) AS total_sales,
        SUM(sales_amount) AS total_sales_amount,
        SUM(quantity) AS total_quantity,
        MIN(order_date) AS first_order,
        MAX(order_date) AS latest_order_date
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL -- Skips empty/corrupted transaction dates
    GROUP BY customer_key
),

-- Step 2: Join the pre-aggregated results with static customer profile dimensions
customer_details AS (
    SELECT 
        dci.customer_key,
        dci.customer_number,
        CONCAT(dci.first_name, ' ', dci.last_name) AS customer_name,
        
        -- [WARNING] DATEDIFF(YEAR) only calculates year boundaries (e.g., Dec 31 to Jan 1 is 1 year). 
        -- Consider using FLOOR(DATEDIFF(DAY, birthdate, GETDATE()) / 365.25) if legal precision is required.
        DATEDIFF(YEAR, dci.customer_birthdate, GETDATE()) AS customer_age,
        
        dci.customer_gender,
        agg.total_products,
        agg.total_sales,
        agg.total_sales_amount,
        agg.total_quantity,
        agg.latest_order_date,
        DATEDIFF(MONTH, agg.first_order, agg.latest_order_date) AS lifespan
    FROM AggregatedSales agg
    LEFT JOIN gold.dim_customer_info dci ON agg.customer_key = dci.customer_key
)

-- Step 3: Compute final business KPIs, dynamic segmentations, and metrics
SELECT 
    customer_key,
    customer_number,
    customer_name,
    customer_age,
    
    -- Categorizing customer lifecycle by age brackets
    -- [WARNING] Labeling clients over 70 as 'Dead' might skew analytics if you have active elderly buyers! 
    -- Consider changing to 'Senior' or 'Elderly'.
    CASE
        WHEN customer_age < 18 THEN 'Not Adult'
        WHEN customer_age BETWEEN 18 AND 40 THEN 'Middle Age'
        WHEN customer_age BETWEEN 41 AND 70 THEN 'Old'
        ELSE 'Dead' 
    END AS customer_situation,
    
    customer_gender,
    total_products,
    total_sales,
    total_sales_amount,
    total_quantity,
    
    -- [CRITICAL FIX] Prevents Division-by-Zero errors if total_sales is 0
    CASE
        WHEN total_sales = 0 THEN 0
        ELSE total_sales_amount / total_sales
    END AS avg_num_of_order, -- Acts as Average Order Value (AOV)
    
    -- Prevents Division-by-Zero errors for single-day purchasers (lifespan = 0)
    CASE 
        WHEN lifespan = 0 THEN total_sales_amount
        ELSE total_sales_amount / lifespan
    END AS avg_monthly_spending,
    
    latest_order_date,
    
    -- Recency calculation: Months elapsed since the customer's last purchase
    DATEDIFF(MONTH, latest_order_date, GETDATE()) AS recency,
    
    lifespan,
    
    -- RFM-based Customer Loyalty Segmentation
    -- [WARNING] 'total_sales' is a count of orders here, not monetary value. 
    -- If >5000 was meant to target money spent, swap 'total_sales' with 'total_sales_amount'.
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment

FROM customer_details;
GO