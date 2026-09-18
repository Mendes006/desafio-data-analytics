# Desafio Técnico Data Analytics: Manchester Investimentos

Solução do desafio técnico de Analista de BI, desenvolvida por Maicon Mendes.

## Problema e abordagem

A empresa fictícia XYZ (varejo de casa e jardim) tem uma base de 500 mil
transações de venda e precisa transformar isso em decisão: entender quem são
os clientes, quais categorias performam melhor, se existe sazonalidade,
como as vendas evoluem por região e se idade influencia a categoria
comprada.

Tratei a base uma única vez em Python (nulos, join com o dicionário de
categorias, colunas derivadas) e exportei uma base limpa que alimenta as
três entregas (notebook, SQL teórico e Power BI), pra garantir que os
números batem entre elas, que é um dos critérios de avaliação do desafio.

## Decisões técnicas

- **Conversão para Parquet:** `read_excel` em 500 mil linhas levava ~40s por
  leitura. Converti uma vez pra Parquet (leitura em ~0,2s com cache quente),
  documentado em [`notebooks/00_conversao_parquet.py`](notebooks/00_conversao_parquet.py).
- **Faturamento:** a coluna `preco_unitario` é fixa por produto (cada um dos
  5 produtos tem exatamente 1 preço), confirmei que é unitário, não total da
  linha. Faturamento = `quantidade_vendida * preco_unitario`.
- **Linhas descartadas:** 548 linhas (0,11%) sem produto identificado foram
  removidas, sem produto não há categoria nem faturamento confiável (o
  preço vem zerado quando o produto é nulo). Também removi 3 duplicatas
  exatas. Nulos de `cliente`, `idade` e `estado` (todos abaixo de 0,3% e
  nunca sobrepostos na mesma linha) não foram descartados da base geral,
  cada análise ignora só as linhas que precisam do campo que falta.
- **Perfil demográfico por cliente único:** idade e estado são atributos do
  cliente, não da transação. Verifiquei que nenhum dos 79.840 clientes
  únicos tem mais de uma idade ou estado registrado, então agreguei por
  `cliente` antes de descrever a distribuição, pra não enviesar pelo volume
  de compras de cada um.
- **Macrorregião:** a base original só tem `estado` (7 estados: Bahia,
  Paraná, Paraíba, Rio de Janeiro, Rio Grande do Sul, Santa Catarina, São
  Paulo), sem coluna de região. Criei `macrorregiao` (Sul, Sudeste,
  Nordeste, padrão IBGE) via mapeamento, pra responder a pergunta de
  tendência regional no nível que o enunciado pede.
- **Idade x categoria (associação, não causalidade):** usei tabela de
  contingência normalizada e o teste qui-quadrado com V de Cramér. O
  qui-quadrado testa se existe associação estatisticamente significativa,
  o V de Cramér mede a força dela (0 a 1). Nenhum dos dois indica causa,
  só se as variáveis são ou não independentes na base.
- **Consistência entre notebook, SQL e Power BI:** o SQL teórico (não roda
  contra banco real, conforme pedido no enunciado) espelha exatamente a
  lógica do notebook. Validei cada query contra a base tratada com DuckDB
  (motor SQL compatível com PostgreSQL) antes de fechar o arquivo, os
  números batem entre as três fontes, com uma diferença de <0,001% no SQL
  porque ele não deduplica as 3 linhas repetidas (documentado no cabeçalho
  de [`sql/analises.sql`](sql/analises.sql)).

## Como executar

1. `pip install -r requirements.txt`
2. Rode `notebooks/00_conversao_parquet.py` (gera a base em Parquet a
   partir do Excel)
3. Rode `notebooks/01_tratamento.py` (trata e exporta a base limpa em
   `data/`, incluindo os CSVs usados pelo Power BI)
4. Abra `notebooks/02_analises.ipynb` pra ver as 5 análises com gráficos
5. `sql/analises.sql` é teórico, não precisa rodar (mas eu validei com
   DuckDB durante o desenvolvimento)
6. `powerbi/dashboard.pbix` abre direto no Power BI Desktop (ele lê os CSVs
   de `data/`, gerados no passo 3)

## Principais insights e recomendações

**Perfil demográfico:** clientes concentrados entre 25 e 54 anos (pico em
35-44, idade média 39 anos), maioria em São Paulo e no eixo Sul/Sudeste.

**Performance por categoria:** o volume de transações é quase idêntico
entre as 5 categorias (~20% cada), mas o faturamento é concentrado:
Jardinagem (33,2%) e Utilidades Domésticas (30,4%) somam 63,7% da receita,
puxadas pelo preço unitário mais alto, não por volume de vendas. As 3
primeiras categorias somam 79,8% do faturamento, próximo do padrão Pareto
mesmo sem ser literal. **Recomendação:** priorizar estoque e visibilidade
de Jardinagem e Utilidades Domésticas, que geram mais receita por venda.

**Sazonalidade:** variação mensal discreta (~7,8% de coeficiente de
variação), sem pico sazonal forte. Janeiro é o mês de maior faturamento e
abril o de menor. **Recomendação:** não há justificativa nessa base pra
campanhas sazonais agressivas, o esforço comercial pode ser distribuído de
forma mais uniforme ao longo do ano.

**Tendência por região:** faturamento estável nos 5 anos (variação de
-0,3% a +1,2% entre 2021 e 2025, dentro do ruído), sem região em
crescimento ou queda clara. Sudeste concentra o maior faturamento absoluto.
**Recomendação:** alocar recursos por concentração atual (Sudeste em
primeiro lugar), não por uma aposta em região emergente, que os dados não
sustentam.

**Idade x categoria:** V de Cramér de 0,002 e p-valor de 0,989, sem
associação estatística entre faixa etária e categoria comprada. Esse é um
achado honesto, não o que se esperaria a priori, mas é o que os dados
mostram. **Recomendação:** não usar idade como critério de segmentação de
campanhas por categoria. Se a empresa quiser buscar segmentação por
perfil, recomendo captar dados que fazem mais sentido pra uma loja de casa
e jardim (tamanho da residência, se tem jardim ou quintal) em vez de
insistir em idade.

## Limitações

- A base é fictícia e, pelos testes de associação e crescimento, parece ter
  sido gerada sem embutir correlações reais entre idade, sazonalidade ou
  crescimento regional, os padrões encontrados são fracos ou inexistentes
  nesses recortes.
- Região é uma derivação de estado (mapeamento IBGE), não veio pronta na
  base, então cobre só 3 macrorregiões (Sul, Sudeste, Nordeste) dos 7
  estados presentes.
- Perfil demográfico se apoia só em idade e estado, a base não tem gênero,
  renda ou outras variáveis demográficas comuns.
- O slicer de `ano` no Power BI ficou no formato de campo numérico (dígita
  o ano) em vez de lista, por causa do tipo de dado da coluna, funciona
  como filtro mas é menos intuitivo que uma lista.

## Próximos passos sugeridos

- Captar dados adicionais de cliente (gênero, renda, tipo de residência)
  pra viabilizar segmentação de verdade, já que idade isolada não mostrou
  associação com categoria.
- Se houver interesse em sazonalidade real, cruzar com um calendário de
  datas comemorativas e campanhas passadas, a base atual não indica pico
  sazonal forte, mas também não tem esse cruzamento.
- Medidas DAX de variação temporal (MoM/YoY) e ranking dinâmico no Power
  BI, cortadas dessa entrega por causa do prazo, mas o SQL já demonstra a
  lógica de tendência ano a ano com `LAG()`.

## Transparência

Essa foi minha primeira vez usando Power BI e DAX, venho de uma base mais
forte em SQL, Python e integração de dados. Desenvolvi o projeto com apoio
de um assistente de IA (Claude) como par de programação, guiando decisões
técnicas, revisando código e me orientando passo a passo no Power BI. As
decisões de modelagem, os cortes de escopo e a interpretação dos
resultados foram minhas.
