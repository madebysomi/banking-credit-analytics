BEGIN;

-- =========================================================
-- CUSTOMER
-- =========================================================

INSERT INTO customers (
    customer_number,
    first_name,
    last_name,
    date_of_birth,
    email,
    country_code
)
VALUES (
    'TEST-CUST-001',
    'Test',
    'Customer',
    '1990-05-15',
    'test@example.com',
    'AT'
);


-- =========================================================
-- ACCOUNT
-- =========================================================

INSERT INTO accounts (
    customer_id,
    account_number,
    account_type,
    currency_code,
    current_balance
)
SELECT
    customer_id,
    'ATTEST000000000001',
    'checking',
    'EUR',
    5000.00
FROM customers
WHERE customer_number = 'TEST-CUST-001';


-- =========================================================
-- TRANSACTION
-- =========================================================

INSERT INTO transactions (
    account_id,
    transaction_reference,
    transaction_type,
    direction,
    amount,
    currency_code,
    transaction_at,
    counterparty_name,
    description
)
SELECT
    account_id,
    'TEST-TXN-001',
    'deposit',
    'credit',
    2500.00,
    'EUR',
    NOW(),
    'Test Employer GmbH',
    'Salary payment'
FROM accounts
WHERE account_number = 'ATTEST000000000001';


-- =========================================================
-- LOAN
-- =========================================================

INSERT INTO loans (
    customer_id,
    disbursement_account_id,
    loan_number,
    loan_type,
    principal_amount,
    currency_code,
    interest_rate,
    term_months,
    application_date,
    approval_date,
    disbursement_date,
    maturity_date,
    outstanding_principal,
    status
)
SELECT
    c.customer_id,
    a.account_id,
    'TEST-LOAN-001',
    'personal',
    10000.00,
    'EUR',
    0.0525,
    36,
    '2026-01-01',
    '2026-01-03',
    '2026-01-05',
    '2029-01-05',
    10000.00,
    'active'
FROM customers c
JOIN accounts a
    ON a.customer_id = c.customer_id
WHERE c.customer_number = 'TEST-CUST-001'
  AND a.account_number = 'ATTEST000000000001';


-- =========================================================
-- LOAN PAYMENT
-- =========================================================

INSERT INTO loan_payments (
    loan_id,
    installment_number,
    due_date,
    paid_date,
    scheduled_amount,
    principal_amount,
    interest_amount,
    paid_amount,
    status
)
SELECT
    loan_id,
    1,
    '2026-02-05',
    '2026-02-03',
    300.00,
    250.00,
    50.00,
    300.00,
    'paid'
FROM loans
WHERE loan_number = 'TEST-LOAN-001';


-- =========================================================
-- CREDIT INFORMATION
-- =========================================================

INSERT INTO credit_information (
    loan_id,
    provider_name,
    report_reference,
    report_date,
    credit_score,
    credit_rating,
    total_credit_limit,
    total_outstanding_debt,
    delinquent_accounts,
    bankruptcies
)
SELECT
    loan_id,
    'Synthetic Credit Bureau',
    'TEST-REPORT-001',
    '2026-01-02',
    720,
    'A',
    30000.00,
    8000.00,
    0,
    0
FROM loans
WHERE loan_number = 'TEST-LOAN-001';


-- =========================================================
-- RISK SNAPSHOT
-- =========================================================

INSERT INTO risk_snapshots (
    loan_id,
    snapshot_date,
    risk_score,
    risk_band,
    probability_of_default,
    exposure_at_default,
    loss_given_default,
    model_name,
    model_version
)
SELECT
    loan_id,
    '2026-01-05',
    0.18000,
    'medium',
    0.1800000,
    10000.00,
    0.4000000,
    'logistic-regression',
    'v1'
FROM loans
WHERE loan_number = 'TEST-LOAN-001';


-- =========================================================
-- VERIFY
-- =========================================================

SELECT 'customers' AS table_name, COUNT(*) AS rows
FROM customers
WHERE customer_number = 'TEST-CUST-001'

UNION ALL

SELECT 'accounts', COUNT(*)
FROM accounts
WHERE account_number = 'ATTEST000000000001'

UNION ALL

SELECT 'transactions', COUNT(*)
FROM transactions
WHERE transaction_reference = 'TEST-TXN-001'

UNION ALL

SELECT 'loans', COUNT(*)
FROM loans
WHERE loan_number = 'TEST-LOAN-001'

UNION ALL

SELECT 'loan_payments', COUNT(*)
FROM loan_payments
WHERE loan_id = (
    SELECT loan_id
    FROM loans
    WHERE loan_number = 'TEST-LOAN-001'
)

UNION ALL

SELECT 'credit_information', COUNT(*)
FROM credit_information
WHERE report_reference = 'TEST-REPORT-001'

UNION ALL

SELECT 'risk_snapshots', COUNT(*)
FROM risk_snapshots
WHERE loan_id = (
    SELECT loan_id
    FROM loans
    WHERE loan_number = 'TEST-LOAN-001'
);


ROLLBACK;