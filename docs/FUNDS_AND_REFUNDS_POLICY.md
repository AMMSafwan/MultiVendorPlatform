
# Funds, Refunds and Financial Protection Policy

## 1. Purpose

This document defines how the MultiVendorPlatform application
records payments, calculates platform fees, manages refunds,
and prepares seller and service-provider settlements.

The application must not assume it is legally authorised to
hold customer funds. Actual money movement must use approved
payment-provider and banking arrangements.

## 2. Financial Policy Decisions

- Refund destination: Original payment method.
- Seller settlement frequency: Weekly.
- Pending funds: Risk-based holding.
- Final refund approval: Platform administrator.

## 3. Financial Participants

- Customer
- Seller
- Service provider
- Courier
- Platform administrator
- Payment provider

## 4. Financial Records

The system must separately record:

- Customer payments
- Seller payable amounts
- Service-provider payable amounts
- Courier payable amounts
- Platform commissions
- Premium ERP/EPOS fees
- Refunds
- Pending adjustments
- COD collections and reconciliation

## 5. Platform Commission

Free plan:
- 10% of eligible earnings.

Premium plan:
- 15% total platform fee, consisting of the
  10% base fee and an additional 5% Premium fee.

Eligible earnings must be clearly defined in the
seller agreement and exclude agreed pass-through amounts.

Refunded transactions must be adjusted to prevent
incorrect commission calculations.

## 6. Seller Settlement

- Settlement frequency: Weekly.
- Calculate eligible seller payable amounts.
- Check pending refunds and disputes.
- Apply authorised fees and adjustments.
- Record settlement approval.
- Record payment-provider confirmation.
- Reconcile the settlement.

Weekly settlement is subject to provider capabilities
and the availability of funds.

## 7. Risk-Based Pending Funds

Settlement may be delayed when a transaction has:

- An active refund request.
- An unresolved customer complaint.
- A delivery dispute.
- A suspicious payment.
- A payment reversal or chargeback risk.

Each hold must have a reason, recorded amount,
creation date and review status.

## 8. Refund Process

1. Customer submits a refund request.
2. System checks the original transaction.
3. Seller provides a response when relevant.
4. Administrator reviews the evidence.
5. Administrator approves, partially approves or rejects.
6. Approved refund is initiated through the original
   payment method where supported.
7. Payment-provider confirmation is recorded.
8. Financial records are adjusted.

A refund is completed only after provider confirmation.

## 9. Refund Statuses

- requested
- under_review
- approved
- refund_initiated
- refunded
- partially_refunded
- rejected
- refund_failed
- escalated

## 10. Refund Categories

Marketplace:
- Damaged product
- Incorrect product
- Missing product
- Seller fails to dispatch
- Eligible cancellation

Services:
- Provider cancellation
- Provider no-show
- Incomplete work
- Approved service-quality dispute

Auctions:
- Seller cannot deliver
- Auction cancelled under applicable terms
- Duplicate payment
- Refundable security deposit

Delivery:
- Lost parcel
- Damaged parcel
- Incorrect COD collection
- Failed delivery

EPOS/ERP:
- Duplicate fee
- Incorrect fee
- Approved billing adjustment

## 11. COD Reconciliation

The system must record:

- COD amount due
- Amount collected by courier
- Collection confirmation
- Amount remitted
- Seller payable amount
- Platform commission
- Delivery and return charges
- Outstanding differences

COD must not be marked reconciled until the
required collection and remittance records are verified.

## 12. Financial Security

- Never store card numbers or CVV.
- Verify payment notifications on the server.
- Prevent duplicate payment and refund processing.
- Maintain an immutable financial transaction history.
- Record administrator actions.
- Apply role-based permissions.
- Require additional approval for high-value manual adjustments.

## 13. Implementation Status

Status: Policy design documented.
Database implementation: Not started.
Payment-provider integration: Not started.
Legal and payment-provider review: Required.
