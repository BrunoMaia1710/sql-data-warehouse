-- demo da apresentacao - data warehouse
-- rodar no banco datawarehouse, selecionando cada bloco e apertando F5


-- ================================================================
-- 1. CARGAS (escolher uma para rodar ao vivo, resultado em Messages)
-- ================================================================

-- bronze: TRUNCATE + COPY dos 6 csvs
CALL bronze.load_bronze();

-- silver: le a bronze, limpa e grava na silver
CALL silver.load_silver();


-- ================================================================
-- 2. BRONZE
-- ================================================================

-- linhas em cada tabela da bronze
SELECT 'crm_cust_info' AS tabela, COUNT(*) AS linhas FROM bronze.crm_cust_info
UNION ALL SELECT 'crm_prd_info', COUNT(*) FROM bronze.crm_prd_info
UNION ALL SELECT 'crm_sales_details', COUNT(*) FROM bronze.crm_sales_details
UNION ALL SELECT 'erp_cust_az12', COUNT(*) FROM bronze.erp_cust_az12
UNION ALL SELECT 'erp_loc_a101', COUNT(*) FROM bronze.erp_loc_a101
UNION ALL SELECT 'erp_px_cat_g1v2', COUNT(*) FROM bronze.erp_px_cat_g1v2;


-- ================================================================
-- 3. SILVER - CLIENTES (crm_cust_info)
-- ================================================================

-- bronze: espacos nos nomes e codigos M/F/S
SELECT cst_id, cst_firstname, cst_lastname, cst_marital_status, cst_gndr
FROM bronze.crm_cust_info
WHERE cst_id IN (11012, 11013);

-- silver: mesmos clientes limpos
SELECT cst_id, cst_firstname, cst_lastname, cst_marital_status, cst_gndr
FROM silver.crm_cust_info
WHERE cst_id IN (11012, 11013);

-- bronze: clientes duplicados ou sem id
SELECT cst_id, COUNT(*) AS vezes
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- silver: mesma consulta, tem que vir vazia
SELECT cst_id, COUNT(*) AS vezes
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;


-- ================================================================
-- 4. SILVER - PRODUTOS (crm_prd_info)
-- ================================================================

-- bronze: chave junta e data de fim antes do inicio
SELECT prd_key, prd_cost, prd_line, prd_start_dt, prd_end_dt
FROM bronze.crm_prd_info
WHERE prd_key LIKE '%HL-U509%'
ORDER BY prd_start_dt;

-- silver: chave separada em cat_id e prd_key, datas corrigidas com LEAD
SELECT cat_id, prd_key, prd_cost, prd_line, prd_start_dt, prd_end_dt
FROM silver.crm_prd_info
WHERE prd_key LIKE '%HL-U509%'
ORDER BY prd_start_dt;

-- produtos com fim antes do inicio: bronze x silver
SELECT
  (SELECT COUNT(*) FROM bronze.crm_prd_info WHERE prd_end_dt < prd_start_dt) AS bronze,
  (SELECT COUNT(*) FROM silver.crm_prd_info WHERE prd_end_dt < prd_start_dt) AS silver;


-- ================================================================
-- 5. SILVER - VENDAS (crm_sales_details)
-- ================================================================

-- datas invalidas na bronze x datas nulas na silver (tem que bater)
SELECT
  (SELECT COUNT(*) FROM bronze.crm_sales_details
    WHERE sls_order_dt = 0 OR LENGTH(sls_order_dt::text) <> 8) AS bronze_invalidas,
  (SELECT COUNT(*) FROM silver.crm_sales_details
    WHERE sls_order_dt IS NULL) AS silver_nulas;

-- vendas com valor ou preco corrigido, lado a lado
SELECT b.sls_ord_num, b.sls_quantity,
       b.sls_price AS preco_bronze, s.sls_price AS preco_silver,
       b.sls_sales AS valor_bronze, s.sls_sales AS valor_silver
FROM bronze.crm_sales_details b
JOIN silver.crm_sales_details s
  ON s.sls_ord_num = b.sls_ord_num AND s.sls_prd_key = b.sls_prd_key
WHERE b.sls_sales IS DISTINCT FROM s.sls_sales
   OR b.sls_price IS DISTINCT FROM s.sls_price
LIMIT 10;

-- silver: valor diferente de quantidade x preco (tem que vir vazio)
SELECT * FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales <= 0 OR sls_price <= 0;


-- ================================================================
-- 6. SILVER - TABELAS DO ERP
-- ================================================================

-- erp_cust_az12: id com prefixo NAS e nascimento no futuro, bronze x silver
SELECT
  (SELECT COUNT(*) FROM bronze.erp_cust_az12 WHERE cid LIKE 'NAS%') AS bronze_com_nas,
  (SELECT COUNT(*) FROM silver.erp_cust_az12 WHERE cid LIKE 'NAS%') AS silver_com_nas,
  (SELECT COUNT(*) FROM bronze.erp_cust_az12 WHERE bdate > CURRENT_DATE) AS bronze_nasc_futuro,
  (SELECT COUNT(*) FROM silver.erp_cust_az12 WHERE bdate > CURRENT_DATE) AS silver_nasc_futuro;

-- genero no erp: bronze x silver
SELECT 'bronze' AS camada, gen, COUNT(*) AS qtd FROM bronze.erp_cust_az12 GROUP BY gen
UNION ALL
SELECT 'silver', gen, COUNT(*) FROM silver.erp_cust_az12 GROUP BY gen
ORDER BY camada, gen;

-- paises: bronze x silver
SELECT 'bronze' AS camada, cntry, COUNT(*) AS qtd FROM bronze.erp_loc_a101 GROUP BY cntry
UNION ALL
SELECT 'silver', cntry, COUNT(*) FROM silver.erp_loc_a101 GROUP BY cntry
ORDER BY camada, cntry;


-- ================================================================
-- 7. GOLD - MODELO ESTRELA
-- ================================================================

-- linhas em cada view
SELECT 'dim_customers' AS view, COUNT(*) FROM gold.dim_customers
UNION ALL SELECT 'dim_products', COUNT(*) FROM gold.dim_products
UNION ALL SELECT 'fact_sales', COUNT(*) FROM gold.fact_sales;

-- dimensao clientes (crm + erp juntos)
SELECT * FROM gold.dim_customers LIMIT 5;

-- genero: quando o crm nao tem (n/a), o erp completa
SELECT ci.cst_id, ci.cst_gndr AS genero_crm, dc.gender AS genero_gold
FROM silver.crm_cust_info ci
JOIN gold.dim_customers dc ON dc.customer_id = ci.cst_id
WHERE ci.cst_gndr = 'n/a'
LIMIT 10;

-- dimensao produtos (so os atuais, com categoria do erp)
SELECT * FROM gold.dim_products LIMIT 5;

-- fato vendas (medidas + chaves das dimensoes)
SELECT * FROM gold.fact_sales LIMIT 5;

-- vendas sem cliente ou produto (tem que vir vazio)
SELECT * FROM gold.fact_sales
WHERE customer_key IS NULL OR product_key IS NULL;


-- ================================================================
-- 8. GOLD - ANALISES
-- ================================================================

-- vendas por pais
SELECT c.country, SUM(f.sales_amount) AS total_vendas
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_vendas DESC;

-- vendas por categoria
SELECT p.category, SUM(f.sales_amount) AS total_vendas
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_vendas DESC;

-- top 5 produtos mais vendidos
SELECT p.product_name, SUM(f.sales_amount) AS total_vendas
FROM