/** Key Findings & Recommendations
 1. Fraud Rates by Loan Status
Finding: Rejected loan applicants had a fraud rate over 2× higher than approved applicants.

Recommendation:
 Introduce post-rejection monitoring for high-risk applicants.
 Flag rejected applicants with unusual transaction patterns for manual review.

 2. Fraud Concentration by Transaction Type
Finding: Fraudulent activity is disproportionately higher in certain transaction types (e.g., Online and Transfer transactions had highest fraud rates).

Recommendation:
Increase fraud detection controls (e.g., velocity checks, IP filters) on high-risk transaction types.
Consider stricter authentication for online transactions.

 3. Timing of Fraud Post-Loan
Finding: Fraudulent transactions occur, on average, within 30–45 days of a loan application (approved or rejected).

Recommendation:
 Implement fraud surveillance windows during the first 60 days post-loan interaction.
 Use temporal patterns in predictive fraud modeling.

 4. Credit Score & Fraud Correlation
Finding: Customers with credit scores below 600 show significantly higher fraud rates (up to 3–4×).

Recommendation:
 Integrate credit score risk tiers into fraud models.
 Require enhanced verification for low-score customers during onboarding and transactions.

 5. High-Risk Customer Profiles
Finding: A small subset of customers accounts for the majority of fraudulent transactions.

Recommendation:
 Build customer-level risk scores combining loan history, transaction behavior, and fraud flags.
 Prioritize investigations and interventions on top offenders.

 6. Peak Fraud Hours
Finding: Fraud is more likely to occur during off-peak hours (late night to early morning).
Recommendation:
 Trigger heightened fraud alerts during high-risk time windows.
 Consider time-based throttling or manual reviews for large-value transactions during off-hours.

Conclusion:
By combining loan history, transaction metadata, and credit risk insights, the organization can build smarter fraud detection systems and reduce exposure to financial risk while maintaining customer trust.
**/

-- Questions Asked & SQL Queries used in Making Findings

/** What is the average loan amount for approved vs rejected applications?**/
SELECT loan_status, AVG(loan_amount_requested) as Average_Amount
FROM loan_application
GROUP BY loan_status
HAVING loan_status = 'Approved' or loan_status = 'Declined'


/** How many applications were submitted each month?**/
Select FORMAT(application_date, 'MM/yyyy') as ApplicationMonth, Count(application_id) as NumberofApplications
From loan_application
Group by FORMAT(application_date, 'MM/yyyy')
Order by ApplicationMonth


/** Which loan purpose is most common among rejected applications?**/
Select  Top 1 count(*) as TotalRejected, purpose_of_loan
From loan_application
Where loan_status = 'Declined'
Group by purpose_of_loan
Order by TotalRejected


/** What is the average credit score by employment status?**/
SELECT
   employment_status,
   AVG(cibil_score) AS average_credit_score
FROM
   loan_application
GROUP BY
   employment_status
ORDER BY
   average_credit_score DESC;


/** What is the rejection rate by employment status?**/
SELECT
   employment_status,
   COUNT(CASE WHEN loan_status = 'Declined' THEN 1 END) * 1.0 /  ##Multiplying by 1.0 ensures you get a decimal (float) rejection rate
COUNT(*) AS rejection_rate,
   COUNT(*) AS total_applications,
   COUNT(CASE WHEN loan_status = 'Declined' THEN 1 END) AS total_rejected
FROM
   loan_application
GROUP BY
   employment_status
ORDER BY
   rejection_rate DESC;




/** What is the total and average transaction amount per customer?**/


SELECT
   customer_id,
   SUM(transaction_amount) AS total_transaction_amount,
   AVG(transaction_amount) AS average_transaction_amount,
   COUNT(*) AS transaction_count
FROM
   dbo.[transaction]
GROUP BY
   customer_id
ORDER BY
   total_transaction_amount DESC;


/** What is the most common transaction type? **/


SELECT TOP 1
   transaction_type,
   COUNT(*) AS transaction_count
FROM
   [transaction]
GROUP BY
   transaction_type
ORDER BY
   transaction_count DESC;


/**Which customers made the most transactions overall?**/
SELECT Top 10 customer_id,
   COUNT(*) AS transaction_count
FROM
   [transaction]
GROUP BY
   customer_id
ORDER BY
   transaction_count DESC;




/**What is the peak transaction hour across all customers??**/
SELECT TOP 1
   DATEPART(HOUR, transaction_date) AS transaction_hour,
   COUNT(*) AS transaction_count
FROM
   [transaction]
GROUP BY
   DATEPART(HOUR, transaction_date)
ORDER BY
   transaction_count DESC;




/** What percentage of all transactions are flagged as fraud??**/
##We use the CAST AS FLOAT to make the total fraud_flag a decimal number.
SELECT
   CAST(SUM(CASE WHEN fraud_flag = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS fraud_percentage
FROM
   [transaction];

/** What is the average transaction amount for fraudulent vs non-fraudulent transactions?**/
SELECT
   fraud_flag,
   COUNT(*) AS transaction_count,
   AVG(transaction_amount) AS average_transaction_amount
FROM
   [transaction]
GROUP BY
   fraud_flag;

/**  Which transaction types are most associated with fraud?**/
SELECT TOP 1
   transaction_type,
   COUNT(*) AS fraud_count
FROM
   [transaction]
WHERE
   fraud_flag = 1
GROUP BY
   transaction_type
ORDER BY
   fraud_count DESC;

/** Which customers have the highest number of fraud-flagged transactions?**/
SELECT TOP 10
   customer_id,
   COUNT(*) AS fraud_transaction_count
FROM
   [transaction]
WHERE
   fraud_flag = 1
GROUP BY
   customer_id
ORDER BY
   fraud_transaction_count DESC;

/** Are customers with rejected loans more likely to be involved in fraud?**/
WITH customer_status AS (
   SELECT
       customer_id,
       loan_status
   FROM
       loan_application
   WHERE
      loan_status IN ('Approved', 'Declined') 
),
fraud_summary AS (
   SELECT
       cs.loan_status,
       COUNT(CASE WHEN t.fraud_flag = 1 THEN 1 END) AS fraud_count,
       COUNT(*) AS total_transactions,
       CAST(COUNT(CASE WHEN t.fraud_flag = 1 THEN 1 END) AS FLOAT) / COUNT(*) * 100 AS fraud_rate
   FROM
       [transaction] t
   JOIN
       customer_status cs ON t.customer_id = cs.customer_id
   GROUP BY
       cs.loan_status
)
SELECT * FROM fraud_summary;

/** Do customers with low credit scores show higher fraudulent activity?**/
WITH credit_band AS (
   SELECT
       customer_id,
       CASE
           WHEN cibil_score < 600 THEN 'Low (<600)'
           WHEN cibil_score BETWEEN 600 AND 699 THEN 'Fair (600-699)'
           WHEN cibil_score BETWEEN 700 AND 749 THEN 'Good (700-749)'
           WHEN cibil_score >= 750 THEN 'Excellent (750+)'
           ELSE 'Unknown'
       END AS credit_score_band
   FROM loan_application
),
fraud_stats AS (
   SELECT
       cb.credit_score_band,
       COUNT(*) AS total_transactions,
       SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) AS fraud_count,
       CAST(SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS fraud_rate
   FROM
       [transaction] t
   JOIN credit_band cb ON t.customer_id = cb.customer_id
   GROUP BY
       cb.credit_score_band
)
SELECT * FROM fraud_stats
ORDER BY fraud_rate DESC;


/** What is the fraud rate among customers with approved loans vs rejected ones?**/


WITH loan_status AS (
   SELECT
       customer_id,
       loan_status
   FROM
       loan_application
   
),
fraud_by_status AS (
   SELECT
       ls.loan_status,
       COUNT(*) AS total_transactions,
       SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) AS fraud_count,
       CAST(SUM(CASE WHEN t.fraud_flag = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS fraud_rate
   FROM
       [transaction] t
   JOIN
       loan_status ls ON t.customer_id = ls.customer_id
   GROUP BY
       ls.loan_status
)
SELECT * FROM fraud_by_status
ORDER BY fraud_rate DESC;




/** For customers with both loans and fraud activity, what is the average time gap between loan application and fraudulent transaction?**/
WITH loan_dates AS (
   SELECT
       customer_id,
       MIN(application_date) AS first_loan_date
   FROM
       loan_application
   GROUP BY
       customer_id
),
fraud_dates AS (
   SELECT
       customer_id,
       MIN(transaction_date) AS first_fraud_date
   FROM
       [transaction]
   WHERE
       fraud_flag = 1
   GROUP BY
       customer_id
),
loan_fraud_gap AS (
   SELECT
       f.customer_id,
       DATEDIFF(DAY, l.first_loan_date, f.first_fraud_date) AS days_between_loan_and_fraud
   FROM
       loan_dates l
   JOIN
       fraud_dates f ON l.customer_id = f.customer_id
)
SELECT
   AVG(days_between_loan_and_fraud * 1.0) AS average_days_between_loan_and_fraud
FROM
   loan_fraud_gap;




