/*
=============================================================
Procedure: silver.load_silver (PostgreSQL)
=============================================================
Lê a Bronze, limpa os dados e grava na Silver.
Por enquanto: crm_cust_info. As outras tabelas serão adicionadas.

Limpezas em crm_cust_info:
  1. Remove linhas sem cst_id.
  2. Duplicados: mantém só o registro mais recente de cada cliente
     (ROW_NUMBER ordenado por cst_create_date decrescente).
  3. TRIM: tira espaços extras dos nomes.
  4. Padroniza códigos: S/M -> Single/Married, F/M -> Female/Male,
     qualquer outro valor -> 'n/a'.

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

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Silver carregada!';
    RAISE NOTICE '================================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERRO durante a carga da Silver: %', SQLERRM;
        RAISE;
END;
$$;