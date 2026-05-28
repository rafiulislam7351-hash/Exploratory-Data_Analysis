# Exploratory Data Analysis & Analytics Views

This repository contains data warehousing views built on top of a relational sales schema (`gold`). The primary objective of this project is to implement optimized, single-pass analytical scripts that eliminate performance bottlenecks (like row-by-row data explosions and sorting overheads) while generating multi-dimensional business insights.

## ⚖️ License
This project is licensed under the **MIT License** - see below for details.

MIT License

Copyright (c) 2026 Rafiul Islam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## 🛠️ Performance Architecture Pattern
A critical component of this project is query performance tuning. Both analytical modules implement an **"Aggregate First, Join Second"** design pattern.

* **The Problem:** Joining a high-volume fact table directly to dimension tables before aggregation triggers heavy row-by-row evaluations of string formatting (`CONCAT`), date arithmetic (`DATEDIFF`), and memory-intensive uniqueness filters (`COUNT DISTINCT`). This creates massive intermediate datasets that can easily cause system timeouts in production environments.
* **The Solution:** The logic uses Common Table Expressions (CTEs) to pre-aggregate metrics at the granular key level *first*. The database engine performs calculations over a tightly reduced array of unique rows, bypassing traditional table scans and TempDB memory blocks.

---

## 📊 Analytical Views Included

### 1. Customer 360-Degree Analytics (`gold.view_customer_analytics`)
This view isolates consumer behaviors, lifetime spending trajectories, and demographic profiles into actionable CRM subsets.

| Field Name | Data Type | Business Description |
| :--- | :--- | :--- |
| `customer_key` | INT | Primary surrogate identifier for unique customers. |
| `customer_name` | VARCHAR | Concatenated full identity profile name string. |
| `customer_situation` | VARCHAR | Segment conditional mapping (`Not Adult`, `Middle Age`, `Old`, `Senior`). |
| `avg_num_of_order` | DECIMAL | Average Order Value (AOV) featuring division-by-zero protection. |
| `avg_monthly_spending` | DECIMAL | Total financial footprint divided by active client lifespan months. |
| `recency` | INT | Elapsed duration in months since the user's latest transaction row. |
| `customer_segment` | VARCHAR | RFM loyalty routing based on time tenure and gross revenue (`VIP`, `Regular`, `New`). |

### 2. Product Performance Analytics (`gold.view_product_analytics`)
This script isolates product performance velocity metrics, operational costs, and inventory demand cycles.

| Field Name | Data Type | Business Description |
| :--- | :--- | :--- |
| `product_key` | INT | Primary surrogate identifier for distinct items. |
| `product_category` | VARCHAR | High-level operational categorization category name. |
| `total_orders` | INT | Total frequency of unique historical invoice receipts. |
| `average_order_revenue` | DECIMAL | Aggregated earnings divided against gross ticket volume. |
| `lifespan` | INT | Duration in months that an active item generates sales demand. |
| `product_performance_segment` | VARCHAR | Revenue tier assignment mapping (`High-Performer`, `Mid-Range`, `Low-Performer`). |

---

🚀 How to Run and Initialize
Open your SQL Server Management Studio (SSMS) or favorite database IDE.

Ensure you have targeted the database hosting your target enterprise dataset schemas (gold.fact_sales, gold.dim_customer_info, and gold.dim_products).

Run the scripts sequentially to compile the data view items within your local environment.

Execute validation audits using standard query selection patterns:
SELECT TOP 100 * FROM gold.view_customer_analytics ORDER BY total_sales_amount DESC;
SELECT TOP 100 * FROM gold.view_product_analytics ORDER BY total_sales DESC;
