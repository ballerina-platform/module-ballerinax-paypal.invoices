# PayPal Invoice Management: Create, Send, Record Payment, and List Invoices

This use case demonstrates how the PayPal Invoices API can be used to create an invoice, send it to a customer, record an external payment, and list recent invoices. It showcases a complete invoice management workflow from creation to payment recording and account overview, which is useful for businesses that receive payments through various methods and need to manage their PayPal invoice records comprehensively.

## Prerequisites

### 1. Set up PayPal Developer account

Refer to the [Setup Guide](https://github.com/ballerina-platform/module-ballerinax-paypal.invoices#setup-guide) to obtain necessary credentials (`clientId`, `clientSecret`) and a verified merchant email address.

### 2. Configuration

Create a `Config.toml` file in the example's root directory and provide your PayPal credentials and merchant email as follows:

```toml
clientId = "<your_client_id>"
clientSecret = "<your_client_secret>"
merchantEmail = "<your_merchant_email>"
```

## Run the Example

Execute the following command to run the example:

```bash
bal run
```

## Expected Output

When you run the example successfully, you should see output similar to:

```diff
Generated unique invoice number: 2025-INV-1719648000
Created Invoice ID: INV2-XXXX-XXXX-XXXX-XXXX
Invoice sent successfully!
Payment recorded successfully! Payment ID: PAY-XXXXXXXXXXXX
Invoice Status: PAID
Total Paid: $300.00

+Recent Invoices:
+ ID: INV2-XXXX-XXXX-XXXX-XXXX | Status: PAID | Total: 300.00 USD
+ ID: INV2-YYYY-YYYY-YYYY-YYYY | Status: SENT | Total: 150.00 USD
+ ID: INV2-ZZZZ-ZZZZ-ZZZZ-ZZZZ | Status: DRAFT | Total: 450.00 USD
```

## What This Example Does

1. **Generates Unique Invoice Number**: Creates a timestamp-based invoice number to ensure uniqueness
2. **Creates Professional Invoice**: Generates an invoice for website maintenance services
3. **Sends Invoice to Customer**: Emails the invoice to the specified recipient
4. **Records External Payment**: Logs a check payment received outside of PayPal
5. **Updates Invoice Status**: Retrieves and displays the updated payment status
6. **Lists Recent Invoices**: Displays a summary of recent invoices with their status and amounts

## Key Features Demonstrated

- Unique invoice number generation using timestamps
- Complete invoice lifecycle management (create → send → record payment)
- External payment recording (check, cash, bank transfer)
- Invoice status tracking and verification
- Email notification system for invoices
- Invoice listing and summary display with pagination

## Troubleshooting

### Common Issues

1. **Authentication Error**: Verify your `clientId`, `clientSecret`, and `merchantEmail` are correct
2. **Invalid Merchant Email**: Ensure the merchant email is verified in your PayPal sandbox account
3. **Invoice Send Failed**: Check that recipient email addresses are valid
4. **Payment Recording Error**: Verify payment amount matches invoice total

