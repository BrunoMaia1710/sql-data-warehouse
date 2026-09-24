-- Checagem da Bronze: quantidade de linhas carregadas em cada tabela.
-- Rodar depois de CALL bronze.load_bronze(); todas devem ser > 0.
SELECT 'crm_cust_info' AS tabela, COUNT(*) FROM bronze.crm_cust_info
UNION ALL SELECT 'crm_prd_info', COUNT(*) FROM bronze.crm_prd_info
UNION ALL SELECT 'crm_sales_details', COUNT(*) FROM bronze.crm_sales_details
UNION ALL SELECT 'erp_cust_az12', COUNT(*) FROM bronze.erp_cust_az12
UNION ALL SELECT 'erp_loc_a101', COUNT(*) FROM bronze.erp_loc_a101
UNION ALL SELECT 'erp_px_cat_g1v2', COUNT(*) FROM bronze.erp_px_cat_g1v2;