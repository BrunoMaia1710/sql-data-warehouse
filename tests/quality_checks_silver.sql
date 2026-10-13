-- clientes duplicados ou sem id (tem que vir vazio)
SELECT cst_id, COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- nomes com espaco sobrando (tem que vir vazio)
SELECT cst_id, cst_firstname, cst_lastname
FROM silver.crm_cust_info
WHERE cst_firstname <> TRIM(cst_firstname)
   OR cst_lastname <> TRIM(cst_lastname);

-- valores padronizados de genero e estado civil
SELECT DISTINCT cst_gndr, cst_marital_status FROM silver.crm_cust_info;

-- produtos com data de fim antes do inicio ou custo negativo (tem que vir vazio)
SELECT * FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt OR prd_cost < 0;

-- vendas com valor diferente de quantidade x preco (tem que vir vazio)
SELECT * FROM silver.crm_sales_details
WHERE sls_sales <> sls_quantity * sls_price
   OR sls_sales <= 0 OR sls_price <= 0;

-- valores padronizados de genero no erp
SELECT DISTINCT gen FROM silver.erp_cust_az12;

-- paises padronizados
SELECT DISTINCT cntry FROM silver.erp_loc_a101 ORDER BY cntry;

-- linhas na bronze x silver
SELECT 'crm_cust_info' AS tabela,
       (SELECT COUNT(*) FROM bronze.crm_cust_info) AS bronze,
       (SELECT COUNT(*) FROM silver.crm_cust_info) AS silver
UNION ALL SELECT 'crm_prd_info',
       (SELECT COUNT(*) FROM bronze.crm_prd_info),
       (SELECT COUNT(*) FROM silver.crm_prd_info)
UNION ALL SELECT 'crm_sales_details',
       (SELECT COUNT(*) FROM bronze.crm_sales_details),
       (SELECT COUNT(*) FROM silver.crm_sales_details)
UNION ALL SELECT 'erp_cust_az12',
       (SELECT COUNT(*) FROM bronze.erp_cust_az12),
       (SELECT COUNT(*) FROM silver.erp_cust_az12)
UNION ALL SELECT 'erp_loc_a101',
       (SELECT COUNT(*) FROM bronze.erp_loc_a101),
       (SELECT COUNT(*) FROM silver.erp_loc_a101)
UNION ALL SELECT 'erp_px_cat_g1v2',
       (SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2),
       (SELECT COUNT(*) FROM silver.erp_px_cat_g1v2);