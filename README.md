\# Data Warehouse em SQL - Arquitetura Medalhão



Projeto de capacitação do NDados, adaptado do vídeo do Data With Baraa para PostgreSQL.



\*\*Fontes de dados:\*\* arquivos CSV de dois sistemas: CRM (clientes, produtos e vendas) e ERP (nascimento, gênero e país dos clientes, e categorias dos produtos).



\- \*\*Bronze:\*\* carrega os CSVs como vieram, sem transformação (TRUNCATE + COPY). `CALL bronze.load\_bronze();`

\- \*\*Silver:\*\* limpa e padroniza os dados: remove duplicados, corrige datas e valores de venda, padroniza códigos e países. `CALL silver.load\_silver();`

\- \*\*Gold:\*\* modelo estrela em views, pronto para análise.



\*\*Tabelas da Gold:\*\*

\- `gold.dim\_customers`: clientes, juntando CRM e ERP

\- `gold.dim\_products`: produtos atuais com categoria

\- `gold.fact\_sales`: vendas ligadas às dimensões

