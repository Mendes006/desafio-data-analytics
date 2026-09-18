# Tratamento da base: tirei as linhas sem produto (548, ~0.1% da base) porque
# sem produto nao da pra saber a categoria nem confiar no faturamento (o
# preco vem 0 quando o produto e nulo). Ja cliente/idade/estado eu deixei os
# nulos na base mesmo, cada analise ignora so as linhas que precisam do
# campo que falta (mais detalhe disso no README).
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
