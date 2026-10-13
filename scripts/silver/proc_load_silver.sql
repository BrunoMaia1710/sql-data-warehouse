/*
=============================================================
Procedure: silver.load_silver (PostgreSQL)
=============================================================
Lê a Bronze, limpa os dados e grava na Silver (6 tabelas).

crm_cust_info: remove ids nulos e duplicados (fica o mais recente),
  TRIM nos nomes, S/M -> Single/Married, F/M -> Female/Male.
crm_prd_info: separa prd_key em cat_id e prd_key, custo nulo -> 0,
  linha M/R/S/T por extenso, data de fim recalculada com LEAD.
crm_sales_details: datas inteiras -> DATE (inválidas -> NULL),
  valor recalculado = quantidade x preço quando errado,
  preço calculado = valor / quantidade quando inválido.
erp_cust_az12: remove prefixo 'NAS' do id, nascimento no futuro -> NULL,
  gênero padronizado.
erp_loc_a101: remove '-' do id, países padronizados (DE -> Germany,
  US/USA -> United States, vazio -> n/a).
erp_px_cat_g1v2: já vem limpa, copiada como está.

Como usar:  CALL silver.load_silver();
=============================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
    v_inicio TIMESTAMP;
BEGIN
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carregando camada Silver';
    RAISE NOTICE '================================================';

    -- ------------------------ crm_cust_info ------------------------
    v_inicio := clock_timestamp();
    TRUNCATE TABLE silver.crm_cust_info;
    INSERT INTO silver.crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname,
        cst_marital_status, cst_gndr, cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname),
        TRIM(cst_lastname),
        CASE UPPER(TRIM(cst_marital_status))
            WHEN 'S' THEN 'Single'
            WHEN 'M' THEN 'Married'
            ELSE 'n/a'
        END,
        CASE UPPER(TRIM(cst_gndr))
            WHEN 'F' THEN 'Female'
            WHEN 'M' THEN 'Male'
            ELSE 'n/a'
        END,
        cst_create_date
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_ultimo
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE flag_ultimo = 1;
    RAISE NOTICE 'crm_cust_info carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    -- ------------------------ crm_prd_info -------------------------
    v_inicio := clock_timestamp();
    TRUNCATE TABLE silver.crm_prd_info;
    INSERT INTO silver.crm_prd_info (
        prd_id, cat_id, prd_key, prd_nm, prd_cost,
        prd_line, prd_start_dt, prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'),
        SUBSTRING(prd_key, 7),
        prd_nm,
        COALESCE(prd_cost, 0),
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END,
        prd_start_dt::DATE,
        (LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)
            - INTERVAL '1 day')::DATE
    FROM bronze.crm_prd_info;
    RAISE NOTICE 'crm_prd_info carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    -- --------------------- crm_sales_details -----------------------
    v_inicio := clock_timestamp();
    TRUNCATE TABLE silver.crm_sales_details;
    INSERT INTO silver.crm_sales_details (
        sls_ord_num, sls_prd_key, sls_cust_id,
        sls_order_dt, sls_ship_dt, sls_due_dt,
        sls_sales, sls_quantity, sls_price
    )
    SELECT
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::text) <> 8 THEN NULL
             ELSE TO_DATE(sls_order_dt::text, 'YYYYMMDD') END,
        CASE WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::text) <> 8 THEN NULL
             ELSE TO_DATE(sls_ship_dt::text, 'YYYYMMDD') END,
        CASE WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::text) <> 8 THEN NULL
             ELSE TO_DATE(sls_due_dt::text, 'YYYYMMDD') END,
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0
                  OR sls_sales <> sls_quantity * ABS(sls_price)
             THEN sls_quantity * ABS(sls_price)
             ELSE sls_sales END,
        sls_quantity,
        CASE WHEN sls_price IS NULL OR sls_price <= 0
             THEN sls_sales / NULLIF(sls_quantity, 0)
             ELSE sls_price END
    FROM bronze.crm_sales_details;
    RAISE NOTICE 'crm_sales_details carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    -- ------------------------ erp_cust_az12 ------------------------
    v_inicio := clock_timestamp();
    TRUNCATE TABLE silver.erp_cust_az12;
    INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
    SELECT
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4) ELSE cid END,
        CASE WHEN bdate > CURRENT_DATE THEN NULL ELSE bdate END,
        CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
             WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
             ELSE 'n/a' END
    FROM bronze.erp_cust_az12;
    RAISE NOTICE 'erp_cust_az12 carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    -- ------------------------ erp_loc_a101 -------------------------
    v_inicio := clock_timestamp();
    TRUNCATE TABLE silver.erp_loc_a101;
    INSERT INTO silver.erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(cid, '-', ''),
        CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
             WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
             WHEN cntry IS NULL OR TRIM(cntry) = '' THEN 'n/a'
             ELSE TRIM(cntry) END
    FROM bronze.erp_loc_a101;
    RAISE NOTICE 'erp_loc_a101 carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    -- ----------------------- erp_px_cat_g1v2 -----------------------
    v_inicio := clock_timestamp();
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT id, cat, subcat, maintenance
    FROM bronze.erp_px_cat_g1v2;
    RAISE NOTICE 'erp_px_cat_g1v2 carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Silver carregada!';
    RAISE NOTICE '================================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERRO durante a carga da Silver: %', SQLERRM;
        RAISE;
END;
$$;