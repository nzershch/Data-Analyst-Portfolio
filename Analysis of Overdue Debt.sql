-- Query 1
--расчет сумм выданных овердрафтов в соотношении с просроченными за весь период 
  
--вычисление общей суммы выданных овердрафтов
WITH
  granted AS (
  SELECT
    ROUND(SUM(amount), 2) AS sum_granted
  FROM
    billing.credits ),
 --вычисление общей суммы просроченных овердрафтов
  overdue AS (
  SELECT
    ROUND(SUM(amount), 2) AS sum_overdue
  FROM
    billing.credits
  WHERE
    (paid = 0
      OR paid_date > CAST(due_date AS string))
    AND due_date < '2023-08-01' )

--объединение двух запросов и вычисление доли просроченных овердрафтов 
SELECT
  sum_granted,
  sum_overdue,
  ROUND(sum_overdue / sum_granted * 100, 2) AS percentage_overdue
FROM
  granted
CROSS JOIN
  overdue
  
-- Query 2
-- расчет сумм выданных овердрафтов по мес€цам в соотношении с просроченными с нарастающим итогом

-- извлечение мес€ца и расчет суммы просроченных и выданных по мес€цам
WITH
  granted AS (
  SELECT
    EXTRACT(month
    FROM
      created_at) AS month,
    ROUND(SUM(amount), 2) AS sum_granted
  FROM
    billing.credits
  GROUP BY
    month
  ORDER BY
    month ),
  overdue AS (
  SELECT
    EXTRACT(month
    FROM
      created_at) AS month,
    ROUND(SUM(amount), 2) AS sum_overdue
  FROM
    billing.credits
  WHERE
    paid = 0
    AND due_date < '2023-08-01'
  GROUP BY
    month )

--замена пор€дкового числа мес€ца на текст, расчет сумм выданных и просроченных нарастающим итогом
--определение нарастающей доли просроченных к выданным овердрафтам    
SELECT
  CASE
    WHEN granted.month = 1 THEN 'January'
    WHEN granted.month = 2 THEN 'February'
    WHEN granted.month = 3 THEN 'March'
    WHEN granted.month = 4 THEN 'April'
    WHEN granted.month = 5 THEN 'May'
    WHEN granted.month = 6 THEN 'June'
  ELSE
  'July'
END
  AS month,
  sum_granted,
  SUM(sum_granted) OVER (ORDER BY granted.month) AS growing_granted,
  sum_overdue,
  SUM(sum_overdue) OVER (ORDER BY granted.month) AS growing_overdue,
  ROUND(SUM(sum_overdue) OVER (ORDER BY granted.month) / SUM(sum_granted) OVER (ORDER BY granted.month) * 100, 2) AS overdue_ratio
FROM
  granted
LEFT JOIN
  overdue
USING
  (month)
GROUP BY
  granted.month,
  sum_granted,
  sum_overdue
  
-- Query 3
  --расчет сумм просроченных овердрафтов в зависимости от типа клиента
SELECT
  type,
  ROUND(SUM(amount), 2) AS sum_overdue
FROM
  billing.credits
WHERE
  paid = 0
  AND due_date < '2023-08-01'
GROUP BY
  TYPE
  
-- Query 4
  --расчет сумм просроченных овердрафтов в зависимости от типа овердрафта
SELECT
  basis,
  ROUND(SUM(amount), 2) AS sum_overdue
FROM
  billing.credits
WHERE
  paid = 0
  AND due_date < '2023-08-01'
GROUP BY
  basis
  
-- Query 5
  --расчет суммы просроченных овердрафтов в зависимости от срока возникновени€ просрочки
SELECT
  ROUND(SUM(sum_overdue), 2) AS sum_overdue,
  category
FROM (
  SELECT
    user_id,
    ROUND(SUM(amount), 2) AS sum_overdue,
    CASE
      WHEN TIMESTAMP_DIFF('2023-08-01', MIN(due_date), DAY) < 30 THEN 'less than 30 days'
      WHEN TIMESTAMP_DIFF('2023-08-01', MIN(due_date), DAY) BETWEEN 30
    AND 60 THEN '30 to 60 days'
      WHEN TIMESTAMP_DIFF('2023-08-01', MIN(due_date), DAY) BETWEEN 60 AND 90 THEN '60 to 90 days'
    ELSE
    'over 90 days'
  END
    AS category
  FROM
    billing.credits
  WHERE
    paid = 0
    AND due_date < '2023-08-01'
  GROUP BY
    user_id
  ORDER BY
    category DESC ) AS query
GROUP BY
  category
ORDER BY
  sum_overdue
  
-- Query 6
  --расчет среднего количества дней оплаты просрочки, расчет частоты оплаты по дн€м после наступлени€ просрочки 
--определение медианы срока оплаты
  
SELECT
  DISTINCT diffrence AS day,
  mean,
  median,
  frequency_by_days
FROM (
  SELECT
    diffrence,
    ROUND(AVG(diffrence) OVER()) AS mean,
    PERCENTILE_CONT(diffrence, 0.5) OVER () AS median,
    COUNT(diffrence) OVER (PARTITION BY diffrence) AS frequency_by_days
  FROM (
    SELECT
      user_id,
      deposit_accounting_id,
      DATETIME_DIFF(CAST(paid_date AS datetime), CAST(due_date AS datetime), day) AS diffrence
    FROM
      billing.credits
    WHERE
      due_date < '2023-08-01'
      AND paid = 1
    GROUP BY
      user_id,
      paid_date,
      deposit_accounting_id,
      due_date
    HAVING
      diffrence > 0) AS diffrences
  ORDER BY
    frequency_by_days DESC ) AS total
ORDER BY
  frequency_by_days DESC,
  day
  