BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- =========================================================
-- ENUM TYPES
-- =========================================================

CREATE TYPE account_status AS ENUM (
    'active',
    'blocked',
    'closed'
);

CREATE TYPE account_type AS ENUM (
    'checking',
    'savings',
    'credit_card'
);

CREATE TYPE transaction_type AS ENUM (
    'deposit',
    'withdrawal',
    'transfer',
    'payment',
    'fee',
    'interest',
    'adjustment'
);

CREATE TYPE transaction_status AS ENUM (
    'pending',
    'completed',
    'failed',
    'reversed'
);

CREATE TYPE transaction_direction AS ENUM (
    'debit',
    'credit'
);

CREATE TYPE loan_status AS ENUM (
    'application',
    'approved',
    'rejected',
    'active',
    'closed',
    'defaulted',
    'written_off',
    'cancelled'
);

CREATE TYPE payment_status AS ENUM (
    'scheduled',
    'paid',
    'partial',
    'late',
    'missed',
    'waived'
);


-- =========================================================
-- CUSTOMERS
-- =========================================================

CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_number VARCHAR(30) NOT NULL UNIQUE,

    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,

    email VARCHAR(255),
    phone VARCHAR(50),
    country_code CHAR(2),

    customer_since DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT customers_date_of_birth_ck
        CHECK (
            date_of_birth IS NULL
            OR date_of_birth <= CURRENT_DATE
        ),

    CONSTRAINT customers_country_code_ck
        CHECK (
            country_code IS NULL
            OR country_code ~ '^[A-Z]{2}$'
        )
);


-- =========================================================
-- ACCOUNTS
-- =========================================================

CREATE TABLE accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID NOT NULL
        REFERENCES customers(customer_id),

    account_number VARCHAR(34) NOT NULL UNIQUE,
    account_type account_type NOT NULL,

    currency_code CHAR(3) NOT NULL DEFAULT 'EUR',

    opened_at DATE NOT NULL DEFAULT CURRENT_DATE,
    closed_at DATE,

    status account_status NOT NULL DEFAULT 'active',

    credit_limit NUMERIC(18, 2),
    current_balance NUMERIC(18, 2) NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT accounts_currency_code_ck
        CHECK (
            currency_code ~ '^[A-Z]{3}$'
        ),

    CONSTRAINT accounts_balance_ck
        CHECK (
            current_balance >= 0
            OR account_type = 'credit_card'
        ),

    CONSTRAINT accounts_credit_limit_ck
        CHECK (
            (
                account_type = 'credit_card'
                AND credit_limit IS NOT NULL
                AND credit_limit > 0
            )
            OR
            (
                account_type <> 'credit_card'
                AND credit_limit IS NULL
            )
        ),

    CONSTRAINT accounts_dates_ck
        CHECK (
            closed_at IS NULL
            OR closed_at >= opened_at
        ),

    CONSTRAINT accounts_id_customer_unique
        UNIQUE (account_id, customer_id)
);


-- =========================================================
-- TRANSACTIONS
-- =========================================================

CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    account_id UUID NOT NULL
        REFERENCES accounts(account_id),

    related_account_id UUID
        REFERENCES accounts(account_id),

    counterparty_name VARCHAR(255),

    transaction_reference VARCHAR(80) NOT NULL UNIQUE,

    transaction_type transaction_type NOT NULL,
    direction transaction_direction NOT NULL,

    status transaction_status NOT NULL DEFAULT 'completed',

    amount NUMERIC(18, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL,

    transaction_at TIMESTAMPTZ NOT NULL,

    description VARCHAR(500),
    merchant_category VARCHAR(100),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT transactions_amount_ck
        CHECK (
            amount > 0
        ),

    CONSTRAINT transactions_currency_code_ck
        CHECK (
            currency_code ~ '^[A-Z]{3}$'
        ),

    CONSTRAINT transactions_related_account_ck
        CHECK (
            related_account_id IS NULL
            OR related_account_id <> account_id
        )
);


-- =========================================================
-- LOANS
-- =========================================================

CREATE TABLE loans (
    loan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    customer_id UUID NOT NULL
        REFERENCES customers(customer_id),

    disbursement_account_id UUID,

    loan_number VARCHAR(30) NOT NULL UNIQUE,
    loan_type VARCHAR(50) NOT NULL,

    principal_amount NUMERIC(18, 2) NOT NULL,
    currency_code CHAR(3) NOT NULL DEFAULT 'EUR',

    /*
     * Stored as decimal:
     *
     * 5.25% = 0.0525
     * 8.90% = 0.0890
     */
    interest_rate NUMERIC(7, 4) NOT NULL,

    term_months INTEGER NOT NULL,

    application_date DATE NOT NULL DEFAULT CURRENT_DATE,
    approval_date DATE,
    disbursement_date DATE,
    maturity_date DATE,

    outstanding_principal NUMERIC(18, 2) NOT NULL DEFAULT 0,

    status loan_status NOT NULL DEFAULT 'application',

    collateral_value NUMERIC(18, 2),

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT loans_principal_ck
        CHECK (
            principal_amount > 0
        ),

    CONSTRAINT loans_currency_code_ck
        CHECK (
            currency_code ~ '^[A-Z]{3}$'
        ),

    CONSTRAINT loans_interest_rate_ck
        CHECK (
            interest_rate BETWEEN 0 AND 1
        ),

    CONSTRAINT loans_term_ck
        CHECK (
            term_months > 0
        ),

    CONSTRAINT loans_outstanding_ck
        CHECK (
            outstanding_principal >= 0
            AND outstanding_principal <= principal_amount
        ),

    CONSTRAINT loans_collateral_ck
        CHECK (
            collateral_value IS NULL
            OR collateral_value >= 0
        ),

    CONSTRAINT loans_dates_ck
        CHECK (
            (
                approval_date IS NULL
                OR approval_date >= application_date
            )
            AND
            (
                disbursement_date IS NULL
                OR (
                    approval_date IS NOT NULL
                    AND disbursement_date >= approval_date
                )
            )
            AND
            (
                maturity_date IS NULL
                OR (
                    disbursement_date IS NOT NULL
                    AND maturity_date >= disbursement_date
                )
            )
        ),

    /*
     * Ensures that the disbursement account belongs
     * to the same customer as the loan.
     */
    CONSTRAINT loans_disbursement_account_fk
        FOREIGN KEY (
            disbursement_account_id,
            customer_id
        )
        REFERENCES accounts (
            account_id,
            customer_id
        )
);


-- =========================================================
-- LOAN PAYMENTS
-- =========================================================

CREATE TABLE loan_payments (
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_id UUID NOT NULL
        REFERENCES loans(loan_id),

    installment_number INTEGER NOT NULL,

    due_date DATE NOT NULL,
    paid_date DATE,

    scheduled_amount NUMERIC(18, 2) NOT NULL,

    principal_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    interest_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    fee_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    paid_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,

    status payment_status NOT NULL DEFAULT 'scheduled',

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT loan_payments_installment_ck
        CHECK (
            installment_number > 0
        ),

    CONSTRAINT loan_payments_amounts_ck
        CHECK (
            scheduled_amount > 0
            AND principal_amount >= 0
            AND interest_amount >= 0
            AND fee_amount >= 0
            AND paid_amount >= 0
            AND (
                principal_amount
                + interest_amount
                + fee_amount
            ) <= scheduled_amount
        ),

    CONSTRAINT loan_payments_unique_installment
        UNIQUE (
            loan_id,
            installment_number
        )
);


-- =========================================================
-- CREDIT INFORMATION
-- =========================================================

CREATE TABLE credit_information (
    credit_information_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_id UUID NOT NULL
        REFERENCES loans(loan_id),

    provider_name VARCHAR(100) NOT NULL,
    report_reference VARCHAR(100),

    report_date DATE NOT NULL,

    credit_score INTEGER,
    credit_rating VARCHAR(20),

    total_credit_limit NUMERIC(18, 2),
    total_outstanding_debt NUMERIC(18, 2),

    delinquent_accounts INTEGER NOT NULL DEFAULT 0,
    bankruptcies INTEGER NOT NULL DEFAULT 0,

    raw_payload JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT credit_information_score_ck
        CHECK (
            credit_score IS NULL
            OR credit_score BETWEEN 0 AND 1000
        ),

    CONSTRAINT credit_information_limits_ck
        CHECK (
            total_credit_limit IS NULL
            OR total_credit_limit >= 0
        ),

    CONSTRAINT credit_information_debt_ck
        CHECK (
            total_outstanding_debt IS NULL
            OR total_outstanding_debt >= 0
        ),

    CONSTRAINT credit_information_delinquency_ck
        CHECK (
            delinquent_accounts >= 0
            AND bankruptcies >= 0
        ),

    CONSTRAINT credit_information_report_unique
        UNIQUE (
            loan_id,
            provider_name,
            report_date
        )
);


-- =========================================================
-- RISK SNAPSHOTS
-- =========================================================

CREATE TABLE risk_snapshots (
    risk_snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    loan_id UUID NOT NULL
        REFERENCES loans(loan_id),

    snapshot_date DATE NOT NULL,

    risk_score NUMERIC(8, 5) NOT NULL,
    risk_band VARCHAR(20) NOT NULL,

    probability_of_default NUMERIC(8, 7),

    exposure_at_default NUMERIC(18, 2),

    loss_given_default NUMERIC(8, 7),

    model_name VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,

    features JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT risk_snapshots_score_ck
        CHECK (
            risk_score >= 0
        ),

    CONSTRAINT risk_snapshots_pd_ck
        CHECK (
            probability_of_default IS NULL
            OR probability_of_default BETWEEN 0 AND 1
        ),

    CONSTRAINT risk_snapshots_ead_ck
        CHECK (
            exposure_at_default IS NULL
            OR exposure_at_default >= 0
        ),

    CONSTRAINT risk_snapshots_lgd_ck
        CHECK (
            loss_given_default IS NULL
            OR loss_given_default BETWEEN 0 AND 1
        ),

    CONSTRAINT risk_snapshots_unique
        UNIQUE (
            loan_id,
            snapshot_date,
            model_name,
            model_version
        )
);


-- =========================================================
-- UPDATED_AT TRIGGER
-- =========================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER customers_set_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();


CREATE TRIGGER accounts_set_updated_at
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();


CREATE TRIGGER loans_set_updated_at
BEFORE UPDATE ON loans
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();


-- =========================================================
-- INDEXES
-- =========================================================

CREATE INDEX accounts_customer_idx
    ON accounts(customer_id);


CREATE INDEX transactions_account_date_idx
    ON transactions(
        account_id,
        transaction_at DESC
    );


CREATE INDEX transactions_related_account_idx
    ON transactions(related_account_id)
    WHERE related_account_id IS NOT NULL;


CREATE INDEX transactions_status_idx
    ON transactions(status);


CREATE INDEX loans_customer_status_idx
    ON loans(
        customer_id,
        status
    );


CREATE INDEX loans_disbursement_account_idx
    ON loans(disbursement_account_id)
    WHERE disbursement_account_id IS NOT NULL;


CREATE INDEX loan_payments_loan_due_date_idx
    ON loan_payments(
        loan_id,
        due_date
    );


CREATE INDEX loan_payments_status_due_date_idx
    ON loan_payments(
        status,
        due_date
    );


CREATE INDEX credit_information_loan_date_idx
    ON credit_information(
        loan_id,
        report_date DESC
    );


CREATE INDEX risk_snapshots_loan_date_idx
    ON risk_snapshots(
        loan_id,
        snapshot_date DESC
    );


COMMIT;