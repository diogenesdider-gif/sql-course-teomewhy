
WITH tb_transacoes AS (

SELECT IdTransacao,
       IdCliente,
       QtdePontos,
       substr(DtCriacao,1,19) AS DtCriacao,
       julianday('2025-08-01') - julianday(substr(DtCriacao,1,10)) AS DiffDate,
       CAST(strftime('%H', substr(DtCriacao,1,19)) AS INTEGER) AS DtHora

FROM transacoes
WHERE DtCriacao < '2025-08-01'
),

tb_cliente AS (
SELECT idCliente,
       substr(DtCriacao,1,19) AS DtCriacao,
       julianday('2025-08-01') - julianday(substr(DtCriacao,1,10)) AS IdadeBase
FROM clientes
),

tb_sumario_transacoes AS (

SELECT IdCliente,
       count(IdTransacao) AS QtdeTransacoesVida,
       count(CASE 
             WHEN DiffDate <= 56 THEN IdTransacao END) AS QtdeTransa56,
       count(CASE 
             WHEN DiffDate <= 28 THEN IdTransacao END) AS QtdeTransa28,
       count(CASE 
             WHEN DiffDate <= 14 THEN IdTransacao END) AS QtdeTransa14,
       count(CASE 
             WHEN DiffDate <= 7 THEN IdTransacao END) AS QtdeTransa7,
       min(DiffDate) AS DiasUltimasInteracoes,
       sum(qtdePontos) AS SaldoPontos,
       sum(CASE WHEN qtdePontos > 0 THEN qtdePontos ELSE 0 END) AS QtdePontosPosiVida,
       sum(CASE WHEN QtdePontos > 0 AND DiffDate <= 56 THEN QtdePontos ELSE 0 END) AS QtdePontosPositivos56,
       sum(CASE WHEN QtdePontos > 0 AND DiffDate <= 28 THEN QtdePontos ELSE 0 END) AS QtdePontosPositivos28,
       sum(CASE WHEN QtdePontos > 0 AND DiffDate <= 14 THEN QtdePontos ELSE 0 END) AS QtdePontosPositivos14,
       sum(CASE WHEN QtdePontos > 0 AND DiffDate <=  7 THEN QtdePontos ELSE 0 END) AS QtdePontosPositivos7,

       sum(CASE WHEN qtdePontos < 0 THEN qtdePontos ELSE 0 END) AS QtdePontosNegVida,
       sum(CASE WHEN QtdePontos < 0 AND DiffDate <= 56 THEN QtdePontos ELSE 0 END) AS QtdePontosNeg56,
       sum(CASE WHEN QtdePontos < 0 AND DiffDate <= 28 THEN QtdePontos ELSE 0 END) AS QtdePontosNeg28,
       sum(CASE WHEN QtdePontos < 0 AND DiffDate <= 14 THEN QtdePontos ELSE 0 END) AS QtdePontosNeg14,
       sum(CASE WHEN QtdePontos < 0 AND DiffDate <=  7 THEN QtdePontos ELSE 0 END) AS QtdePontosNeg7
    
FROM tb_transacoes
GROUP BY IdCliente
),

tb_transacao_produto AS (

SELECT T1.*,
       T3.DescNomeProduto,
       T3.DescCategoriaProduto
FROM tb_transacoes AS T1
LEFT JOIN transacao_produto AS T2
ON T1.IdTransacao = T2.IdTransacao
LEFT JOIN produtos AS T3
ON T2.IdProduto = T3.IdProduto

),

tb_cliente_produto AS (

SELECT IdCliente,
       DescNomeProduto,
       count(*) AS QtdeVida,
       count(CASE WHEN DiffDate <= 56 THEN IdTransacao END) AS Qtde56,
       count(CASE WHEN DiffDate <= 28 THEN IdTransacao END) AS Qtde28,
       count(CASE WHEN DiffDate <= 14 THEN IdTransacao END) AS Qtde14,
       count(CASE WHEN DiffDate <= 7 THEN IdTransacao END) AS Qtde7
       
FROM tb_transacao_produto
GROUP BY IdCliente, DescNomeProduto
),

tb_cliente_produto_rn AS (

SELECT *,
       row_number () OVER (PARTITION BY IdCliente ORDER BY QtdeVida) AS RnVida,
       row_number () OVER (PARTITION BY IdCliente ORDER BY Qtde56) AS RnVida56,
       row_number () OVER (PARTITION BY IdCliente ORDER BY Qtde28) AS RnVida28,
       row_number () OVER (PARTITION BY IdCliente ORDER BY Qtde14) AS RnVida14,
       row_number () OVER (PARTITION BY IdCliente ORDER BY Qtde7) AS RnVida7
FROM tb_cliente_produto
),


tb_cliente_dia AS (

SELECT IdCliente,
       strftime('%w', DtCriacao) AS DtDia,
       count(*) AS QtdeTransacao
FROM tb_transacoes
GROUP BY IdCliente, DtDia
ORDER BY DiffDate ASC

),

tb_cliente_dia_rn AS (

SELECT *,
       ROW_NUMBER () OVER (PARTITION BY IdCliente ORDER BY QtdeTransacao DESC) AS RnDia 
FROM tb_cliente_dia

),

tb_cliente_periodo AS (

SELECT 
       IdCliente,
       CASE
       WHEN DtHora BETWEEN 7 AND 12 THEN 'Manha'
       WHEN DtHora BETWEEN 13 AND 18 THEN 'Tarde'
       WHEN DtHora BETWEEN 19 AND 23 THEN 'Noite'
       ELSE 'MADRUGADA'
       END AS Periodo,
       count(*) AS QtdeTransacao
FROM tb_transacoes
GROUP BY 1,2
ORDER BY DiffDate DESC

),

tb_cliente_periodo_rn AS (

SELECT *,
       row_number() OVER (PARTITION BY IdCliente ORDER BY QtdeTransacao DESC) AS RnPeriodo 
FROM tb_cliente_periodo

),

tb_join AS (

SELECT T1.*,
       T2.IdadeBase,
       T3.DescNomeProduto AS ProdutoVida,
       T4.DescNomeProduto AS Produto56,
       T5.DescNomeProduto AS Produto26,
       T6.DescNomeProduto AS Produto14,
       T7.DescNomeProduto AS Produto7,
       COALESCE(T8.DtDia, -1) AS DtDia,
       COALESCE(T9.Periodo, 'SEM INFORMACAO') AS PeriodoMaisTransacao28

FROM tb_sumario_transacoes AS T1
LEFT JOIN tb_cliente AS T2
ON T1.IdCliente = T2.IdCliente

LEFT JOIN tb_cliente_produto_rn AS T3
ON T1.IdCliente = T3.IdCliente
AND T3.RnVida = 1

LEFT JOIN tb_cliente_produto_rn AS T4
ON T1.IdCliente = T4.IdCliente
AND T4.RnVida56 = 1

LEFT JOIN tb_cliente_produto_rn AS T5
ON T1.IdCliente = T5.IdCliente
AND T5.RnVida28 = 1

LEFT JOIN tb_cliente_produto_rn AS T6
ON T1.IdCliente = T6.IdCliente
AND T6.RnVida14 = 1

LEFT JOIN tb_cliente_produto_rn AS T7
ON T1.IdCliente = T7.IdCliente
AND T7.RnVida7 = 1

LEFT JOIN tb_cliente_dia_rn AS T8
ON T1.IdCliente = T8.IdCliente
AND T8.RnDia = 1

LEFT JOIN tb_cliente_periodo_rn AS T9
ON T1.IdCliente = T9.IdCliente
AND T9.RnPeriodo = 1

)

SELECT '2025-06-01' AS DtRef,
       *,
       1. * QtdeTransa28 / QtdeTransacoesVida AS Engajamento28Vida
FROM tb_join
ORDER BY Engajamento28Vida DESC