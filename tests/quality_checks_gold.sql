-- quantidade de linhas em cada view da gold
SELECT 'dim_customers' AS view, COUNT(*) FROM gold.dim_customers
UNION ALL SELECT 'dim_products', COUNT(*) FROM gold.dim_products
UNION ALL SELECT 'fact_sales', COUNT(*) FROM gold.fact_sales;

-- vendas sem cliente ou produto correspondente (tem que vir vazio)
SELECT * FROM gold.fact_sales
WHERE customer_key IS NULL OR product_key IS NULL;

-- exemplo de analise: vendas por pais
SELECT c.country, SUM(f.sales_amount) AS total_vendas
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_vendas DESC;