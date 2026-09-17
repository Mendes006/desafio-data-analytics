"""
Fase 0: conversao unica do Excel para Parquet.

read_excel em 500 mil linhas leva ~15-20s por leitura. Parquet e um formato
colunar binario: leitura fica quase instantanea e os tipos (datas, floats)
sao preservados sem precisar reconverter toda vez que reabrimos o notebook.

Rodar uma vez. O resultado fica em data/, ignorado pelo git (regeneravel
a partir do Excel original).
"""
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
