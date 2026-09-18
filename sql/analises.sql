-- Consultas teoricas do desafio Manchester Investimentos, dialeto PostgreSQL.
-- Nao rodam contra banco real (nao e exigido no enunciado), mas espelham a
-- mesma logica do tratamento em Python (notebooks/01_tratamento.py e
-- 02_analises.py) pra os numeros baterem entre as duas entregas.
--
-- Tabelas assumidas:
--   vendas (cliente, idade, estado, produto, quantidade_vendida,
--           preco_unitario, data_venda)
--   categorias_produtos (produto, categoria)
--
-- preco_unitario e por unidade, nao o total da linha, entao faturamento
-- sempre calculo como quantidade_vendida * preco_unitario. Linhas com
-- produto nulo ficam de fora (sem produto nao da pra saber categoria nem
-- confiar no faturamento). Idade e estado sao do cliente, nao da transacao,
-- entao a pergunta 1 usa DISTINCT por cliente. Nao existe coluna de regiao
-- na base, so estado, entao derivo a macrorregiao via CASE WHEN.
--
-- Obs: a base bruta tem 3 linhas 100% duplicadas, removidas no notebook mas
-- nao aqui (SQL puro nao tem um drop_duplicates() direto sem assumir uma
-- chave), entao o SQL fica com uma diferenca de <0,001% em relacao aos
-- totais do notebook. Irrelevante pras conclusoes, so documentando.


-- Pergunta 1: perfil demografico dos clientes, por cliente unico (nao por
-- transacao, senao um cliente que compra mais vezes pesa mais na distribuicao)

WITH clientes AS (
    SELECT DISTINCT cliente, idade, estado
    FROM vendas
    WHERE cliente IS NOT NULL
      AND idade IS NOT NULL
      AND estado IS NOT NULL
)
SELECT
    CASE
        WHEN idade BETWEEN 18 AND 24 THEN '18-24'
        WHEN idade BETWEEN 25 AND 34 THEN '25-34'
        WHEN idade BETWEEN 35 AND 44 THEN '35-44'
        WHEN idade BETWEEN 45 AND 54 THEN '45-54'
        WHEN idade BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END AS faixa_etaria,
    COUNT(*) AS qtd_clientes,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_do_total
FROM clientes
GROUP BY 1
ORDER BY 1;

-- distribuicao geografica dos clientes
WITH clientes AS (
    SELECT DISTINCT cliente, idade, estado
    FROM vendas
    WHERE cliente IS NOT NULL
      AND idade IS NOT NULL
      AND estado IS NOT NULL
)
SELECT
    estado,
    COUNT(*) AS qtd_clientes,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_do_total
FROM clientes
GROUP BY estado
ORDER BY qtd_clientes DESC;

-- estatisticas gerais de idade
WITH clientes AS (
    SELECT DISTINCT cliente, idade, estado
    FROM vendas
    WHERE cliente IS NOT NULL
      AND idade IS NOT NULL
      AND estado IS NOT NULL
)
SELECT
    ROUND(AVG(idade), 1) AS idade_media,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY idade) AS idade_mediana,
    MIN(idade) AS idade_min,
    MAX(idade) AS idade_max
FROM clientes;


-- Pergunta 2: performance por categoria (volume, faturamento, ticket medio
-- e Pareto). Uso window function pra calcular % do total e % acumulado sem
-- precisar de subquery a parte.

WITH vendas_validas AS (
    SELECT v.*, c.categoria
    FROM vendas v
    INNER JOIN categorias_produtos c ON c.produto = v.produto
    WHERE v.produto IS NOT NULL
),
por_categoria AS (
    SELECT
        categoria,
        SUM(quantidade_vendida) AS volume_total,
        SUM(quantidade_vendida * preco_unitario) AS faturamento_total,
        COUNT(*) AS qtd_transacoes,
        ROUND(AVG(quantidade_vendida * preco_unitario), 2) AS ticket_medio
    FROM vendas_validas
    GROUP BY categoria
)
SELECT
    categoria,
    volume_total,
    faturamento_total,
    qtd_transacoes,
    ticket_medio,
    ROUND(100.0 * faturamento_total / SUM(faturamento_total) OVER (), 2) AS pct_faturamento,
    ROUND(
        100.0 * SUM(faturamento_total) OVER (ORDER BY faturamento_total DESC
                                              ROWS UNBOUNDED PRECEDING)
        / SUM(faturamento_total) OVER (),
        2
    ) AS pct_acumulado
FROM por_categoria
ORDER BY faturamento_total DESC;


-- Pergunta 3: sazonalidade, faturamento por mes e por trimestre somando os
-- 5 anos da base (2021-2025, todos completos)

SELECT
    EXTRACT(MONTH FROM data_venda)::int AS mes,
    SUM(quantidade_vendida * preco_unitario) AS faturamento_mensal
FROM vendas
WHERE produto IS NOT NULL
GROUP BY 1
ORDER BY 1;

SELECT
    EXTRACT(QUARTER FROM data_venda)::int AS trimestre,
    SUM(quantidade_vendida * preco_unitario) AS faturamento_trimestral
FROM vendas
WHERE produto IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- Pergunta 4: tendencia por regiao. Nao ha coluna de regiao, so estado,
-- entao derivo a macrorregiao (padrao IBGE) via CASE WHEN. Uso LAG() pra
-- comparar com o ano anterior e RANK() pra um ranking dinamico por ano.

WITH vendas_regiao AS (
    SELECT
        v.*,
        CASE
            WHEN estado IN ('PARANA', 'PARANÁ', 'RIO GRANDE DO SUL', 'SANTA CATARINA') THEN 'Sul'
            WHEN estado IN ('RIO DE JANEIRO', 'SAO PAULO', 'SÃO PAULO') THEN 'Sudeste'
            WHEN estado IN ('BAHIA', 'PARAIBA', 'PARAÍBA') THEN 'Nordeste'
        END AS macrorregiao
    FROM vendas v
    WHERE v.produto IS NOT NULL
      AND v.estado IS NOT NULL
),
regiao_ano AS (
    SELECT
        macrorregiao,
        EXTRACT(YEAR FROM data_venda)::int AS ano,
        SUM(quantidade_vendida * preco_unitario) AS faturamento
    FROM vendas_regiao
    GROUP BY macrorregiao, EXTRACT(YEAR FROM data_venda)
)
SELECT
    macrorregiao,
    ano,
    faturamento,
    LAG(faturamento) OVER (PARTITION BY macrorregiao ORDER BY ano) AS faturamento_ano_anterior,
    ROUND(
        100.0 * (faturamento - LAG(faturamento) OVER (PARTITION BY macrorregiao ORDER BY ano))
        / NULLIF(LAG(faturamento) OVER (PARTITION BY macrorregiao ORDER BY ano), 0),
        2
    ) AS crescimento_pct_vs_ano_anterior,
    RANK() OVER (PARTITION BY ano ORDER BY faturamento DESC) AS ranking_no_ano
FROM regiao_ano
ORDER BY macrorregiao, ano;

-- resumo consolidado por regiao
WITH vendas_regiao AS (
    SELECT
        v.*,
        CASE
            WHEN estado IN ('PARANA', 'PARANÁ', 'RIO GRANDE DO SUL', 'SANTA CATARINA') THEN 'Sul'
            WHEN estado IN ('RIO DE JANEIRO', 'SAO PAULO', 'SÃO PAULO') THEN 'Sudeste'
            WHEN estado IN ('BAHIA', 'PARAIBA', 'PARAÍBA') THEN 'Nordeste'
        END AS macrorregiao
    FROM vendas v
    WHERE v.produto IS NOT NULL
      AND v.estado IS NOT NULL
)
SELECT
    macrorregiao,
    SUM(quantidade_vendida * preco_unitario) AS faturamento_total,
    ROUND(AVG(quantidade_vendida * preco_unitario), 2) AS ticket_medio,
    SUM(quantidade_vendida) AS volume_total
FROM vendas_regiao
GROUP BY macrorregiao
ORDER BY faturamento_total DESC;


-- Pergunta 5: relacao entre idade e categoria. Aqui so monto a tabela de
-- contingencia (contagem e % dentro de cada faixa etaria), o teste
-- estatistico (qui-quadrado e V de Cramer) fiz em Python porque SQL puro
-- nao calcula isso nativamente.

WITH base AS (
    SELECT
        v.*,
        c.categoria,
        CASE
            WHEN idade BETWEEN 18 AND 24 THEN '18-24'
            WHEN idade BETWEEN 25 AND 34 THEN '25-34'
            WHEN idade BETWEEN 35 AND 44 THEN '35-44'
            WHEN idade BETWEEN 45 AND 54 THEN '45-54'
            WHEN idade BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
        END AS faixa_etaria
    FROM vendas v
    INNER JOIN categorias_produtos c ON c.produto = v.produto
    WHERE v.produto IS NOT NULL
      AND v.idade IS NOT NULL
)
SELECT
    faixa_etaria,
    categoria,
    COUNT(*) AS qtd_transacoes,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY faixa_etaria), 2) AS pct_dentro_da_faixa
FROM base
GROUP BY faixa_etaria, categoria
ORDER BY faixa_etaria, categoria;
