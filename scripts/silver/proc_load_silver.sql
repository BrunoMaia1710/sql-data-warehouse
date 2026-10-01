/*
=============================================================
Procedure: silver.load_silver (PostgreSQL)
=============================================================
Lê a Bronze, limpa os dados e grava na Silver.
Tabelas já tratadas: crm_cust_info, crm_prd_info.

Limpezas em crm_cust_info:
  1. Remove linhas sem cst_id.
  2. Duplicados: mantém só o registro mais recente de cada cliente
     (ROW_NUMBER ordenado por cst_create_date decrescente).
  3. TRIM: tira espaços extras dos nomes.
  4. Padroniza códigos: S/M -> Single/Married, F/M -> Female/Male,
     qualquer outro valor -> 'n/a'.

Limpezas em crm_prd_info:
  1. Separa prd_key em cat_id (categoria, com '_' para casar com o ERP)
     e prd_key (código do produto, para casar com as vendas).
  2. Custo nulo -> 0.
  3. Padroniza linha: M/R/S/T -> Mountain/Road/Other Sales/Touring.
  4. Converte datas para DATE.
  5. Recalcula a data de fim: dia anterior ao início da próxima
     versão do mesmo produto (LEAD). Versão atual fica com fim NULL.

Como usar:
    CALL silver.load_silver();
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
               ROW_NUMBER() OVER (
                   PARTITION BY cst_id
                   ORDER BY cst_create_date DESC
               ) AS flag_ultimo
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
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTRING(prd_key, 7)                       AS prd_key,
        prd_nm,
        COALESCE(prd_cost, 0)                       AS prd_cost,
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END                                         AS prd_line,
        prd_start_dt::DATE                          AS prd_start_dt,
        (LEAD(prd_start_dt) OVER (
            PARTITION BY prd_key
            ORDER BY prd_start_dt
        ) - INTERVAL '1 day')::DATE                 AS prd_end_dt
    FROM bronze.crm_prd_info;

    RAISE NOTICE 'crm_prd_info carregada em % s',
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