################Find each country and number of stores################

select country, count(store_id) as Total_Stores
from wipro_hackathon_2026.sr20379878_di20381174.stores
Group by country
order by Total_Stores desc;

################What is the total number of units sold by each store################

select 
st.store_id,
st.store_name,
sum(product_quantity_sold) as total_units
from wipro_hackathon_2026.sr20379878_di20381174.sales sl inner join wipro_hackathon_2026.sr20379878_di20381174.stores st
on st.store_id = sl.store_id
Group by st.store_id,st.store_name
order by total_units Desc;

################How many stores have never had a warranty claim filed against any of their products################

select count(*) as total_stores_not_claimed_warranty from wipro_hackathon_2026.sr20379878_di20381174.stores
where store_id NOT IN(
 						select 
 						distinct(store_id)
 						--store_id
 						from wipro_hackathon_2026.sr20379878_di20381174.warranty w left join wipro_hackathon_2026.sr20379878_di20381174.sales s
 						on w.sale_id = s.sale_id);
						

################What percentage of warranty claims are marked as "Completed"?################
select 
ROUND
(count(claim_id)/
				(select count(*) from wipro_hackathon_2026.sr20379878_di20381174.warranty):: numeric * 100,2)
as warranty_void_percentage
from wipro_hackathon_2026.sr20379878_di20381174.warranty
where repair_status = 'Completed';

################Which store had the highest total units sold in the last year?################

select 
store_id,
sum(product_quantity_sold) as Total_units_sold
from wipro_hackathon_2026.sr20379878_di20381174.sales
where sale_date > (CURRENT_DATE - INTERVAL '1 Year')
Group By store_id
order By Total_units_sold desc
limit 1

################Count the number of unique products sold in the year 2024?################

SELECT
  COUNT(DISTINCT product_id) AS unique_products_2024
FROM wipro_hackathon_2026.sr20379878_di20381174.sales
WHERE sale_date >= '2024-01-01' 
  AND sale_date < '2025-01-01';
  
################What is the average price of products in each category?################
  SELECT
  c.Product_category_id,
  c.Product_category_name,
  ROUND(AVG(p.price), 2) AS average_price
FROM wipro_hackathon_2026.sr20379878_di20381174.products AS p 
JOIN wipro_hackathon_2026.sr20379878_di20381174.products_category AS c
  ON p.Product_Category_ID = c.Product_category_id
GROUP BY c.Product_category_id, c.Product_category_name  -- Added missing column
ORDER BY average_price DESC;

################How many warranty claims were filed in 2024?################
select 
count(claim_id) as warranty_claims
from wipro_hackathon_2026.sr20379878_di20381174.warranty
where extract(year from claim_date) = 2024; 


################Identify each store and best-selling day based on highest product quantity sold################
select * 
from
(select
store_id,
sale_date,
sum(product_quantity_sold) as total_unit_sold,
RANK() over(partition by store_id order by sum(product_quantity_sold)desc) as rank 
from wipro_hackathon_2026.sr20379878_di20381174.sales
group by store_id,sale_date
) as t1
where rank =1


################Identify least selling product of each country for each year based on total unit sold################
WITH product_rank AS (
    SELECT
        st.country,
        p.product_name,
        EXTRACT(YEAR FROM sl.sale_date) AS year,
        SUM(sl.product_quantity_sold) AS total_quantity_sold,
        RANK() OVER(PARTITION BY st.country, EXTRACT(YEAR FROM sl.sale_date) ORDER BY SUM(sl.product_quantity_sold) DESC) AS rank
    FROM
        wipro_hackathon_2026.sr20379878_di20381174.stores st
    JOIN
        wipro_hackathon_2026.sr20379878_di20381174.sales sl ON st.store_id = sl.store_id
    JOIN
        wipro_hackathon_2026.sr20379878_di20381174.products p ON p.product_id = sl.product_id
    GROUP BY
        st.country, p.product_name, EXTRACT(YEAR FROM sl.sale_date)
)
SELECT *
FROM product_rank
WHERE rank = 1;

################How many warranty claims were filed within 180 days of a product sale?################

SELECT COUNT(*) AS warranty_claims_180_days
FROM wipro_hackathon_2026.sr20379878_di20381174.warranty w 
LEFT JOIN wipro_hackathon_2026.sr20379878_di20381174.sales s
  ON s.sale_id = w.sale_id
WHERE DATEDIFF(w.claim_date, s.sale_date) <= 180;

################sales_forecast_2025################


WITH base_revenue AS (
  SELECT 
    SUM(CASE WHEN s.sale_year = 2024 THEN s.product_quantity_sold * p.price ELSE 0 END) AS revenue_2024,
    (SUM(CASE WHEN s.sale_year = 2024 THEN s.product_quantity_sold * p.price ELSE 0 END) -
     SUM(CASE WHEN s.sale_year = 2023 THEN s.product_quantity_sold * p.price ELSE 0 END)) * 100.0 /
     NULLIF(SUM(CASE WHEN s.sale_year = 2023 THEN s.product_quantity_sold * p.price ELSE 0 END), 0) AS yoy_growth_pct
  FROM wipro_hackathon_2026.sr20379878_di20381174.sales s
  INNER JOIN wipro_hackathon_2026.sr20379878_di20381174.products p ON s.product_id = p.product_id
  -- NO GROUP BY NEEDED for global aggregation
),
future_years AS (
  SELECT explode(sequence(2024, 2028)) AS predicted_year
)
SELECT 
  fy.predicted_year,
  br.revenue_2024 * POW((1 + br.yoy_growth_pct/100), fy.predicted_year - 2024) AS predicted_revenue,
  br.yoy_growth_pct AS growth_rate_pct
FROM base_revenue br
CROSS JOIN future_years fy
ORDER BY fy.predicted_year;

################monthly_sales_trends################


WITH monthly_sales AS (
  SELECT 
    sale_year, sale_month,
    SUM(product_quantity_sold) as units_sold,
    SUM(product_quantity_sold * p.price) as revenue
  FROM wipro_hackathon_2026.sr20379878_di20381174.sales s
  JOIN wipro_hackathon_2026.sr20379878_di20381174.products p 
    ON s.product_id = p.Product_ID
  GROUP BY sale_year, sale_month
)
SELECT 
  sale_year, sale_month, units_sold, revenue,
  LAG(units_sold, 1) OVER (ORDER BY sale_year, sale_month) as prev_month,
  ROUND(
    (units_sold - LAG(units_sold, 1) OVER (ORDER BY sale_year, sale_month)) 
    * 100.0 / NULLIF(LAG(units_sold, 1) OVER (ORDER BY sale_year, sale_month), 0), 2
  ) as mom_growth_pct
FROM monthly_sales
ORDER BY sale_year DESC, sale_month DESC;


################Give me year on year YOY revenue growth for 2023 and 2024?################


SELECT 
  (SUM(CASE WHEN s.sale_year = 2024 THEN s.product_quantity_sold * p.price ELSE 0 END) -
   SUM(CASE WHEN s.sale_year = 2023 THEN s.product_quantity_sold * p.price ELSE 0 END)) * 100.0 /
   NULLIF(SUM(CASE WHEN s.sale_year = 2023 THEN s.product_quantity_sold * p.price ELSE 0 END), 0) AS yoy_growth_pct
FROM wipro_hackathon_2026.sr20379878_di20381174.sales s
INNER JOIN wipro_hackathon_2026.sr20379878_di20381174.products p ON s.product_id = p.product_id
INNER JOIN wipro_hackathon_2026.sr20379878_di20381174.products_category pc ON p.product_category_id = pc.product_category_id
INNER JOIN wipro_hackathon_2026.sr20379878_di20381174.stores st ON s.store_id = st.store_id
LEFT JOIN wipro_hackathon_2026.sr20379878_di20381174.warranty w ON s.sale_id = w.sale_id

################What will be the revenue if we increase the price by 10%?################

SELECT 
  CONCAT('Price +', CAST(10 AS STRING), '%') as scenario_name,
  ROUND(SUM(Product_Revenue * (1 + 10/100)), 0) as projected_revenue,
  ROUND(SUM(Product_Revenue), 0) as current_revenue,
  ROUND(10, 1) as price_change_pct
FROM wipro_hackathon_2026.sr20379878_di20381174.golddatastore
WHERE sale_year = 2024;

################REVENUE DIFFERENCE CURRENT vs PREVIOUS YEAR################

SELECT 
  SUM(CASE WHEN sale_year = 2024 THEN Product_Revenue ELSE 0 END) as revenue_2024,
  SUM(CASE WHEN sale_year = 2023 THEN  Product_Revenue  ELSE 0 END) as revenue_2023,
  SUM(CASE WHEN sale_year = 2024 THEN  Product_Revenue  ELSE 0 END) -
  SUM(CASE WHEN sale_year = 2023 THEN  Product_Revenue ELSE 0 END) as revenue_difference,
  ROUND(
    (SUM(CASE WHEN sale_year = 2024 THEN  Product_Revenue ELSE 0 END) -
     SUM(CASE WHEN sale_year = 2023 THEN  Product_Revenue  ELSE 0 END)) * 100.0 /
    NULLIF(SUM(CASE WHEN sale_year = 2023 THEN  Product_Revenue  ELSE 0 END), 0), 2
  ) as yoy_growth_pct
FROM wipro_hackathon_2026.sr20379878_di20381174.golddatastore
WHERE sale_year IN (2023, 2024);


################Is the GROWTH POSITIVE/NEGATIVE compared to previous year?################

SELECT 
  CASE 
    WHEN revenue_2024 > revenue_2023 THEN 'POSITIVE GROWTH'
    WHEN revenue_2024 < revenue_2023 THEN 'NEGATIVE GROWTH' 
    ELSE 'NO GROWTH'
  END as growth_status,
  ROUND(yoy_growth_pct, 2) as growth_percentage
FROM (
  SELECT 
    SUM(CASE WHEN sale_year = 2024 THEN Product_Revenue ELSE 0 END) as revenue_2024,
    SUM(CASE WHEN sale_year = 2023 THEN Product_Revenue ELSE 0 END) as revenue_2023,
    (SUM(CASE WHEN sale_year = 2024 THEN Product_Revenue ELSE 0 END) -
     SUM(CASE WHEN sale_year = 2023 THEN Product_Revenue ELSE 0 END)) * 100.0 /
    NULLIF(SUM(CASE WHEN sale_year = 2023 THEN Product_Revenue ELSE 0 END), 0) as yoy_growth_pct
  FROM wipro_hackathon_2026.sr20379878_di20381174.golddatastore
  WHERE sale_year IN (2023, 2024)
) t;

################Top Product selling store for year################

SELECT 
  Store_Name,
  Region,
  SUM(product_quantity_sold) as total_units_sold,
  RANK() OVER (ORDER BY SUM(product_quantity_sold) DESC) as store_rank
FROM wipro_hackathon_2026.sr20379878_di20381174.golddatastore
WHERE sale_year = 2024
GROUP BY Store_Name, Region
ORDER BY total_units_sold DESC
LIMIT 1;