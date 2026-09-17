"""
Fase 1: diagnostico e tratamento da base.

Decisoes tomadas (documentadas tambem no README):
- Linhas sem PRODUTO (548, 0.11%) sao descartadas: sem produto nao ha
  categoria nem faturamento confiavel (preco vem 0 quando produto e nulo).
- Linhas sem CLIENTE, IDADE ou ESTADO nao sao descartadas da base geral,
  cada analise faz dropna só nas colunas que usa. Ex.: perfil demografico
  ignora as poucas linhas sem idade, mas uma analise de faturamento por
  categoria nao precisa de idade e nao perde essas linhas.
- Duplicatas exatas (3 linhas) sao removidas.
"""
import pandas as pd

vendas = pd.read_parquet("../data/vendas_raw.parquet")
produtos = pd.read_parquet("../data/produtos_raw.parquet")

vendas.columns = [c.strip().lower().replace("ç", "c").replace("é", "e") for c in vendas.columns]
produtos.columns = [c.strip().lower() for c in produtos.columns]

antes = len(vendas)
vendas = vendas.drop_duplicates()
vendas = vendas.dropna(subset=["produto"])
print(f"linhas removidas (duplicatas + produto nulo): {antes - len(vendas)}")

vendas = vendas.merge(produtos, on="produto", how="left", validate="many_to_one")

vendas["faturamento"] = vendas["quantidade_vendida"] * vendas["preco_unitario"]

vendas["ano"] = vendas["data"].dt.year
vendas["mes"] = vendas["data"].dt.month
vendas["trimestre"] = vendas["data"].dt.quarter

bins = [17, 24, 34, 44, 54, 64, 200]
labels = ["18-24", "25-34", "35-44", "45-54", "55-64", "65+"]
vendas["faixa_etaria"] = pd.cut(vendas["idade"], bins=bins, labels=labels)

macrorregiao = {
    "PARANA": "Sul", "RIO GRANDE DO SUL": "Sul", "SANTA CATARINA": "Sul",
    "RIO DE JANEIRO": "Sudeste", "SAO PAULO": "Sudeste",
    "BAHIA": "Nordeste", "PARAIBA": "Nordeste",
}
import unicodedata
def normaliza(s):
    if pd.isna(s):
        return s
    return "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn").upper()

vendas["estado_norm"] = vendas["estado"].apply(normaliza)
vendas["macrorregiao"] = vendas["estado_norm"].map(macrorregiao)
vendas = vendas.drop(columns=["estado_norm"])

print(vendas.isnull().sum())
print(vendas.shape)
print(vendas.head())

vendas.to_parquet("../data/vendas_tratado.parquet", index=False)
vendas.to_csv("../data/vendas_tratado.csv", index=False, encoding="utf-8-sig")
print("exportado para data/vendas_tratado.parquet e .csv")
