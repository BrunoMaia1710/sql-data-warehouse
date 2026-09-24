/*
=============================================================
Procedure: bronze.load_bronze (PostgreSQL)
=============================================================
Objetivo:
    Carrega os CSVs de origem nas tabelas da camada Bronze.
    Para cada tabela:
      1. TRUNCATE  -> esvazia a tabela (evita duplicar dados a cada carga)
      2. COPY      -> importa o CSV sem nenhuma transformação
    Mostra o tempo de cada carga com RAISE NOTICE.

Observações:
    - O COPY é executado pelo SERVIDOR PostgreSQL, então o caminho
      precisa ser acessível por ele (por isso C:/datasets/).
    - Se qualquer passo falhar, o PostgreSQL desfaz toda a chamada
      (inclusive os TRUNCATEs): o banco volta ao estado anterior.

Como usar:
    CALL bronze.load_bronze();
=============================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
DECLARE
    v_inicio_lote   TIMESTAMP;
    v_inicio        TIMESTAMP;
BEGIN
    v_inicio_lote := clock_timestamp();
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Carregando camada Bronze';
    RAISE NOTICE '================================================';

    -- ---------------------------- CRM ----------------------------
    RAISE NOTICE '---------- Tabelas CRM ----------';

    v_inicio := clock_timestamp();
    TRUNCATE TABLE bronze.crm_cust_info;
    COPY bronze.crm_cust_info
        FROM 'C:/datasets/source_crm/cust_info.csv'
        WITH (FORMAT csv, HEADER true);
    RAISE NOTICE 'crm_cust_info carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    v_inicio := clock_timestamp();
    TRUNCATE TABLE bronze.crm_prd_info;
    COPY bronze.crm_prd_info
        FROM 'C:/datasets/source_crm/prd_info.csv'
        WITH (FORMAT csv, HEADER true);
    RAISE NOTICE 'crm_prd_info carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    v_inicio := clock_timestamp();
    TRUNCATE TABLE bronze.crm_sales_details;
    COPY bronze.crm_sales_details
        FROM 'C:/datasets/source_crm/sales_details.csv'
        WITH (FORMAT csv, HEADER true);
    RAISE NOTICE 'crm_sales_details carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    -- ---------------------------- ERP ----------------------------
    RAISE NOTICE '---------- Tabelas ERP ----------';

    v_inicio := clock_timestamp();
    TRUNCATE TABLE bronze.erp_cust_az12;
    COPY bronze.erp_cust_az12
        FROM 'C:/datasets/source_erp/CUST_AZ12.csv'
        WITH (FORMAT csv, HEADER true);
    RAISE NOTICE 'erp_cust_az12 carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    v_inicio := clock_timestamp();
    TRUNCATE TABLE bronze.erp_loc_a101;
    COPY bronze.erp_loc_a101
        FROM 'C:/datasets/source_erp/LOC_A101.csv'
        WITH (FORMAT csv, HEADER true);
    RAISE NOTICE 'erp_loc_a101 carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    v_inicio := clock_timestamp();
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;
    COPY bronze.erp_px_cat_g1v2
        FROM 'C:/datasets/source_erp/PX_CAT_G1V2.csv'
        WITH (FORMAT csv, HEADER true);
    RAISE NOTICE 'erp_px_cat_g1v2 carregada em % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio)::numeric, 2);

    RAISE NOTICE '================================================';
    RAISE NOTICE 'Bronze carregada! Tempo total: % s',
        ROUND(EXTRACT(EPOCH FROM clock_timestamp() - v_inicio_lote)::numeric, 2);
    RAISE NOTICE '================================================';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERRO durante a carga da Bronze: %', SQLERRM;
        RAISE;  -- repassa o erro; a carga inteira é desfeita
END;
$$;