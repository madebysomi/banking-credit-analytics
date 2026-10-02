# Banking Credit Analytics Data Model

## Scope

The model supports customer-level credit risk analysis, account activity, loan repayment performance, and historical risk scoring.

## Core Relationships

| Entity | Relationship | Purpose |
| --- | --- | --- |
| `customers` | 1-to-many `accounts` | Stores the customer master record and owned accounts. |
| `accounts` | 1-to-many `transactions` | Stores account activity and transfers between accounts. |
| `customers` | 1-to-many `loans` | Stores loan applications and originated loans. |
| `loans` | 1-to-many `loan_payments` | Stores the repayment schedule and payment performance. |
| `loans` | 1-to-many `credit_information` | Stores dated credit reports relevant to a loan assessment. |
| `loans` | 1-to-many `risk_snapshots` | Stores time-series risk scores and model outputs for a loan. |

## Design Decisions

- Every business entity uses a UUID primary key; human-readable customer, account, and loan numbers remain separate unique identifiers.
- Monetary values use `NUMERIC(18, 2)` and carry an explicit currency code where the amount may cross account boundaries.
- Transaction, loan, payment, and risk states use PostgreSQL enums to prevent invalid status values.
- `credit_information` belongs to a loan assessment and keeps provider reports as dated history rather than overwriting the current score.
- `risk_snapshots` belongs to a loan and is append-oriented; model name/version allows scores from different model releases to be compared.
- JSONB fields are limited to provider payloads and model features that may evolve without changing the relational contract.

## Analytical Grain

- Customer analytics: one row per customer and reporting period.
- Account analytics: one row per account transaction.
- Loan analytics: one row per loan and one row per scheduled installment.
- Credit analytics: one row per loan/provider/report date.
- Risk analytics: one row per loan/model/version/snapshot date.

## Recommended Next Layer

Create analytical views or a warehouse star schema on top of these operational tables. Useful dimensions include customer, date, account, loan, and risk model; useful facts include transactions, loan payments, credit reports, and risk snapshots.
