# PayPal Invoice Management: Create, Send, Cancel, and List Invoices

This use case demonstrates how the PayPal Invoices API can be used to create an invoice, send it to a customer, cancel it when needed, and list recent invoices. It showcases the complete invoice lifecycle management including cancellation scenarios and account overview, which is useful for businesses that need to void invoices due to changes in agreements, order modifications, or customer requests while maintaining visibility of their invoice history.

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

```
Generated unique invoice number: 2025-INV-1719648000
Created Invoice ID: INV2-XXXX-XXXX-XXXX-XXXX
Invoice sent successfully.
Invoice cancelled successfully.

Recent Invoices:
- ID: INV2-XXXX-XXXX-XXXX-XXXX | Status: CANCELLED | Total: 300.00 USD
- ID: INV2-YYYY-YYYY-YYYY-YYYY | Status: SENT | Total: 150.00 USD
- ID: INV2-ZZZZ-ZZZZ-ZZZZ-ZZZZ | Status: PAID | Total: 450.00 USD
```

## What This Example Does

1. **Generates Unique Invoice Number**: Creates a timestamp-based invoice number to ensure uniqueness
2. **Creates Professional Invoice**: Generates an invoice for website maintenance services
3. **Sends Invoice to Customer**: Emails the invoice to the specified recipient with custom message
4. **Cancels Invoice**: Voids the invoice and notifies the customer about the cancellation
5. **Provides Cancellation Reason**: Includes a note explaining why the invoice was cancelled
6. **Lists Recent Invoices**: Displays a summary of recent invoices with their status and amounts

## Key Features Demonstrated

- Complete invoice lifecycle management (create → send → cancel)
- Unique invoice number generation using timestamps
- Custom notification messages for both sending and cancellation
- Professional invoice formatting with detailed line items
- Automated email notifications to customers
- Invoice listing and summary display with pagination

## Invoice Cancellation Scenarios

This example demonstrates cancellation capabilities useful for various business situations:

- **Order Changes**: Customer modifies their order after invoice is sent
- **Agreement Modifications**: Terms or pricing changes require new invoice
- **Customer Requests**: Client asks to cancel or postpone services
- **Billing Errors**: Incorrect amounts or details need correction
- **Project Cancellation**: Service or project is no longer needed

## Invoice Status Flow

```
DRAFT → SENT → CANCELLED
```

- **DRAFT**: Invoice created but not yet sent
- **SENT**: Invoice delivered to customer via email
- **CANCELLED**: Invoice voided and no longer payable

## Troubleshooting

### Common Issues

1. **Authentication Error**: Verify your `clientId`, `clientSecret`, and `merchantEmail` are correct
2. **Invoice Already Paid**: Cannot cancel invoices that have been paid
3. **Invalid Invoice ID**: Ensure invoice exists before attempting cancellation
4. **Email Delivery Issues**: Check recipient email addresses are valid
