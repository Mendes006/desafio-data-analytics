# read_excel demora demais com 500 mil linhas (uns 40s por leitura), entao
# converto uma vez pra parquet e uso isso daqui pra frente. So precisa
# rodar de novo se o Excel original mudar (o parquet fica fora do git).
import time
import pandas as pd

EXCEL_PATH = "../Base-Dados-Desafio-500k.xlsx"

inicio = time.time()
vendas = pd.read_excel(EXCEL_PATH, sheet_name="VENDAS")
produtos = pd.read_excel(EXCEL_PATH, sheet_name="PRODUTOS")
print(f"leitura do Excel: {time.time() - inicio:.1f}s")

vendas.to_parquet("../data/vendas_raw.parquet", index=False)
produtos.to_parquet("../data/produtos_raw.parquet", index=False)

inicio = time.time()
pd.read_parquet("../data/vendas_raw.parquet")
print(f"leitura do Parquet: {time.time() - inicio:.2f}s")
