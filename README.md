# \# Data Warehouse em SQL — Arquitetura Medalhão

# 

# Projeto de capacitação do NDados, adaptado do vídeo do Data With Baraa para PostgreSQL.

# 

# \*\*Fontes de dados:\*\* arquivos CSV de dois sistemas — CRM (clientes, produtos, vendas) e ERP (dados extras de clientes, localização e categorias).

# 

# \- \*\*Bronze:\*\* carrega os CSVs como vieram, sem transformação (TRUNCATE + COPY). ✅

# \- \*\*Silver:\*\* limpeza e padronização dos dados. (em andamento)

# \- \*\*Gold:\*\* modelo estrela em views, pronto para análise. (em andamento)

