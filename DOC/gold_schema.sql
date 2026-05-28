

/*=================================================================================
SCRIPT DOCUMENTATION
===================================================================================
Script Name : Gold Layer Schema View Creation
Database    : Data_Ware_House
Layers      : Silver (Source) -> Gold (Target)
Author      : Rafiul islam

-----------------------------------------------------------------------------------
1. PURPOSE
-----------------------------------------------------------------------------------
This script automates the creation and refreshment of the Gold Layer business views.
It transforms cleansed staging data from the Silver layer into a structured, 
analytics-ready Star Schema consisting of:
  - [gold].[dim_customer_info] : Master customer profiles with integrated demographics.
  - [gold].[dim_product_info]  : Active product catalogs with business categories.
  - [gold].[fact_sales]         : Central sales transactions linked via surrogate keys.

-----------------------------------------------------------------------------------
2. KEY FEATURES
-----------------------------------------------------------------------------------
  - Idempotency      : Uses 'CREATE OR ALTER VIEW' inside dynamic SQL execution 
                       blocks, allowing safe, repeated executions without dropping schemas.
  - Performance Logs : Dynamically captures individual view compile speeds alongside 
                       the cumulative script execution runtime in milliseconds (ms).
  - Exception Control: Enclosed entirely within a T-SQL BEGIN TRY...CATCH block 
                       to trap runtime failures instantly and output full error metadata 
                       without crashing the session batch.

-----------------------------------------------------------------------------------
3. PREREQUISITES / DEPENDENCIES
-----------------------------------------------------------------------------------
Before running this script, ensure the following database states are met:
  - Target database 'Data_Ware_House' and schema 'gold' must exist.
  - Silver tables must be fully populated and up to date:
      * silver.crm_cust_info, silver.erp_cust_az12, silver.erp_loc_a101
      * silver.crm_prd_info, silver.erp_px_cat_g1v1
      * silver.crm_sales_details

-----------------------------------------------------------------------------------
4. WARNINGS & DESIGN CONSIDERATIONS
-----------------------------------------------------------------------------------
  ⚠️ Dynamic SQL Scope: 
     The views are wrapped inside EXEC() strings. Any syntax adjustments inside the 
     nested queries require doubled single-quotes (e.g., ''Unknown'') to parse correctly.
  
  ⚠️ Object Dependency Chain:
     The view [gold].[fact_sales] directly references the dimension views created 
     earlier in this script. Do not reorder the creation sequence, or compilation 
     will fail due to missing dependencies.

  ⚠️ Row-Number Surrogate Keys:
     The surrogate keys are generated dynamically using ROW_NUMBER(). If source data 
     in the Silver layer shifts drastically or undergoes historic updates, these values 
     can shift upon view regeneration. For persistent historical tracking, consider 
     migrating these to physicalized tables with identity columns or hashing routines.
===================================================================================*/



USE Data_Ware_House;
GO

-- Declare variables for time tracking and exceptions
DECLARE @ProcessStartTime DATETIME, @ProcessEndTime DATETIME, @TotalDuration INT;
DECLARE @StartTime DATETIME, @EndTime DATETIME, @Duration INT;

SET @ProcessStartTime = GETDATE();

PRINT '============================================================';
PRINT 'STARTING GOLD LAYER VIEW CREATION PROCESS';
PRINT '============================================================';

BEGIN TRY
    ---------------------------------------------------------------------------------
    -- 1. Creating First Dimension Table - dim_customer_info
    -- Purpose: Combines CRM data with ERP attributes to build a customer profile.
    ---------------------------------------------------------------------------------
    SET @StartTime = GETDATE();
    PRINT 'Processing: Creating or altering view [gold].[dim_customer_info]...';
    
    EXEC('CREATE OR ALTER VIEW gold.dim_customer_info AS
        SELECT 
            ---Surrogate Key for unique identifier for each customer
            ROW_NUMBER() OVER (ORDER BY cust_info.cust_id) AS customer_key,
            cust_info.cust_id AS customer_id,
            cust_info.cust_key AS customer_number,
            cust_info.cust_first_name AS first_name,
            cust_info.cust_last_name AS last_name,
            cust_loc.cntry AS customer_country,
            --When cust_info.cust_gender is the master source
            CASE
                    WHEN cust_info.cust_gender != ''Unknown'' THEN cust_info.cust_gender
                ELSE COALESCE(ex_info.gen, ''Unknown'')
            END AS customer_gender,
            cust_info.cust_marital_status AS marital_status,
            ex_info.bdate AS customer_birthdate,
            cust_info.cust_create_date AS customer_create_date
        FROM silver.crm_cust_info AS cust_info
        --joining with erp_cust_az12 to enrich the data
        LEFT JOIN silver.erp_cust_az12 AS ex_info
            ON cust_info.cust_key = ex_info.cid
        --joining with erp_loc_a101 to enrich the data
        LEFT JOIN silver.erp_loc_a101 AS cust_loc
            ON cust_info.cust_key = cust_loc.cid;');

    SET @EndTime = GETDATE();
    SET @Duration = DATEDIFF(ms, @StartTime, @EndTime);
    PRINT 'Success: [gold].[dim_customer_info] created successfully.';
    PRINT 'Time Elapsed for [dim_customer_info]: ' + CAST(@Duration AS VARCHAR) + ' ms.';
    PRINT '------------------------------------------------------------';

    ---------------------------------------------------------------------------------
    -- 2. Creating Second Dimension Table - dim_product_info
    -- Purpose: Filters active products and joins categories for clear reporting.
    ---------------------------------------------------------------------------------
    SET @StartTime = GETDATE();
    PRINT 'Processing: Creating or altering view [gold].[dim_product_info]...';
    
    EXEC('CREATE OR ALTER VIEW gold.dim_product_info AS
        SELECT 
            ROW_NUMBER() OVER (ORDER BY product_info.prd_start_dt, product_info.prd_key) AS product_key,
            product_info.prd_id AS product_id,
            product_info.prd_key AS product_number,
            product_info.prd_nm AS product_name,
            product_info.cat_id AS category_id,
            category_info.cat AS category_name,
            category_info.subcat AS subcategory_name,
            category_info.maintenance AS category_maintenance,
            product_info.prd_cost AS product_cost,
            product_info.prd_line AS product_line,
            product_info.prd_start_dt AS product_start_date
        FROM silver.crm_prd_info AS product_info
        LEFT JOIN silver.erp_px_cat_g1v1 AS category_info
            ON product_info.cat_id = category_info.id
        --Filtering to get only active products based on end date
        WHERE product_info.prd_end_dt IS NULL;');

    SET @EndTime = GETDATE();
    SET @Duration = DATEDIFF(ms, @StartTime, @EndTime);
    PRINT 'Success: [gold].[dim_product_info] created successfully.';
    PRINT 'Time Elapsed for [dim_product_info]: ' + CAST(@Duration AS VARCHAR) + ' ms.';
    PRINT '------------------------------------------------------------';

    ---------------------------------------------------------------------------------
    -- 3. Creating Fact Table - fact_sales
    -- Purpose: Centralized transactional fact table referencing product/customer dim keys.
    ---------------------------------------------------------------------------------
    SET @StartTime = GETDATE();
    PRINT 'Processing: Creating or altering view [gold].[fact_sales]...';
    
    EXEC('CREATE OR ALTER VIEW gold.fact_sales AS
        SELECT 
            --All the surrogate Keys are here
            sd.sls_ord_num AS sales_order_number,
            dp.product_key AS product_key,
            ci.customer_key AS customer_key,
            --All The dates are here
            sd.sls_order_dt AS order_date,
            sd.sls_ship_dt AS ship_date,
            sd.sls_due_dt AS due_date,
            --All The measures are here
            sd.sls_sales AS sales_amount,
            sd.sls_quantity AS quantity,
            sd.sls_price AS unit_price
        FROM silver.crm_sales_details AS sd
        LEFT JOIN gold.dim_product_info AS dp
            ON sd.sls_prd_key = dp.product_number
        LEFT JOIN gold.dim_customer_info AS ci
            ON sd.sls_cust_id = ci.customer_id;');

    SET @EndTime = GETDATE();
    SET @Duration = DATEDIFF(ms, @StartTime, @EndTime);
    PRINT 'Success: [gold].[fact_sales] created successfully.';
    PRINT 'Time Elapsed for [fact_sales]: ' + CAST(@Duration AS VARCHAR) + ' ms.';
    
END TRY
BEGIN CATCH
    -- Nice and informative exception block
    PRINT '============================================================';
    PRINT 'ERROR DETECTED: Gold Layer View Creation Aborted.';
    PRINT '============================================================';
    PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR);
    PRINT 'Error Message: ' + ERROR_MESSAGE();
    PRINT 'Error Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR);
    PRINT 'Error State: ' + CAST(ERROR_STATE() AS VARCHAR);
END CATCH

-- Total execution summary calculation
SET @ProcessEndTime = GETDATE();
SET @TotalDuration = DATEDIFF(ms, @ProcessStartTime, @ProcessEndTime);

PRINT '============================================================';
PRINT 'GOLD LAYER PROCESS COMPLETED.';
PRINT 'Total Script Execution Time: ' + CAST(@TotalDuration AS VARCHAR) + ' ms.';
PRINT '============================================================';
GO
