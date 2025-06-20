// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/io;
import ballerina/lang.runtime;
import ballerina/test;

configurable string PAYPAL_CLIENT_ID = ?;
configurable string PAYPAL_CLIENT_SECRET = ?;
configurable string PAYPAL_API_BASE_URL = ?;
configurable string PAYPAL_MERCHANT_EMAIL = ?;
configurable boolean isLiveServer = ?;

configurable string serviceUrl = isLiveServer ? "https://api-m.sandbox.paypal.com" : "http://localhost:9090";

// Initialize the PayPal client for sandbox
ConnectionConfig config = {
    auth: {
        tokenUrl: "https://api-m.sandbox.paypal.com/v1/oauth2/token",
        clientId: PAYPAL_CLIENT_ID,
        clientSecret: PAYPAL_CLIENT_SECRET
    }
};

final Client paypalClient = check new Client(config, serviceUrl);

string generatedInvoiceNumber = "";
string testInvoiceId = "";
string testPaymentId = "";

//Test case to generate a draft invoice number
@test:Config {
    groups: ["live_tests", "mock_tests"]}
function testGenerateNextInvoiceNumber() returns error? {
    map<string|string[]> headers = {"Content-Type": "application/json"};

    invoice_number result = check paypalClient->/v2/invoicing/generate\-next\-invoice\-number.post(headers);

    io:println("Generated Invoice Number: ", result);
    test:assertNotEquals(result.invoice_number, "", msg = "Invoice number should not be empty");
    generatedInvoiceNumber = result.invoice_number ?: "";
}

// Test case to create a draft invoice
@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testCreateDraftInvoice() returns error? {
    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    };

    // Minimal valid invoice payload
    invoice invoicePayload = {
        detail: {
            invoice_number: generatedInvoiceNumber,
            reference: "PO-123456",
            invoice_date: "2025-06-17",
            currency_code: "USD",
            note: "Thanks for your business!",
            memo: "Test invoice memo",
            payment_term: {
                term_type: "NET_30"
            }
        },
        invoicer: {
            name: {
                given_name: "Dharshan",
                surname: "Doe"
            },
            email_address: PAYPAL_MERCHANT_EMAIL
        },
        primary_recipients: [
            {
                billing_info: {
                    name: {
                        given_name: "Ravindran",
                        surname: "Smith"
                    },
                    email_address: "customer@example.com"
                }
            }
        ],
        items: [
            {
                name: "Item 1",
                quantity: "2",
                unit_amount: {
                    currency_code: "USD",
                    value: "25.00"
                }
            }
        ]
    };

    // Use `check` to simplify error handling
    invoice result = check paypalClient->/v2/invoicing/invoices.post(invoicePayload, headers);

    io:println("Invoice Created: ID = ", result.id);
    test:assertNotEquals(result.id, "", msg = "Invoice ID should not be empty");

    // Save for other test cases
    testInvoiceId = result.id ?: "";
}

// ---------------------------------------------Test case to list invoices---------------------------------------------
@test:Config {
    groups: ["paypal", "invoice"]
}
function testListInvoices() returns error? {
    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    InvoicesListQueries queries = {
        page: 1,
        page_size: 5,
        fields: "all",
        total_required: true
    };

    invoices result = check paypalClient->/v2/invoicing/invoices.get(headers, queries);

    // Get total_count safely
    int totalCount = 0;
    if result.hasKey("total_count") {
        anydata count = result["total_count"];
        if count is int {
            totalCount = count;
        }
    }
    io:println("Total Invoices: ", totalCount.toString());
    test:assertTrue(totalCount >= 0, msg = "Total count should be non-negative");

    // Get items or fallback to empty array
    invoice[] items = result.items ?: [];

    if items.length() > 0 {
        io:println("First Invoice ID: ", items[0].id ?: "N/A");
        test:assertTrue(items[0].id is string, msg = "Invoice should have an ID");
    } else {
        io:println("No invoices found.");
    }
}

// ---------------------------------------------Test case to get invoice by ID---------------------------------------------
@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateDraftInvoice]
}
function testGetInvoiceById() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping get invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    invoice result = check paypalClient->/v2/invoicing/invoices/[testInvoiceId].get(headers);

    io:println("Retrieved invoice: ", result.id);
    test:assertEquals(result.id, testInvoiceId, msg = "Retrieved invoice ID should match requested ID");
}


@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testListInvoicesWithDifferentQueries() returns error? {
    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Fix: field name should be page_size not pageSize
    InvoicesListQueries queries = {
        page: 1,
        page_size: 2
    };

    invoices result = check paypalClient->/v2/invoicing/invoices.get(headers, queries);

    invoice[]? items = result.items;
    if items is invoice[] {
        int itemsLength = items.length();
        test:assertTrue(itemsLength <= 2, msg = "Should return at most 2 invoices as per page_size");
        io:println("Retrieved ", itemsLength.toString(), " invoices with minimal queries");
    }
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testListInvoicesErrorHandling() returns error? {
    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Fix: use correct field names (snake_case)
    InvoicesListQueries invalidQueries = {
        page: -1,
        page_size: 5
    };

    invoices|error result = paypalClient->/v2/invoicing/invoices.get(headers, invalidQueries);

    if result is error {
        io:println("Expected error for invalid page number: ", result.message());
    } else {
        io:println("PayPal handled invalid page number gracefully");
    }
}

// Helper function to check if an invoice is in DRAFT status
function isInvoiceDraft(string invoiceId, map<string|string[]> headers) returns boolean|error {
    invoice result = check paypalClient->/v2/invoicing/invoices/[invoiceId].get(headers);
    return result.status == "DRAFT";
}

// ---------------------------------------------Test case to send an invoice---------------------------------------------
@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateDraftInvoice]
}
function testSendInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping send invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    };

    boolean isDraft = check isInvoiceDraft(testInvoiceId, headers);
    if !isDraft {
        io:println("Invoice is not in DRAFT state. Cannot send.");
        return;
    }

    notification payload = {
        subject: "Invoice for your recent purchase",
        note: "Please see the attached invoice.",
        send_to_invoicer: true,
        send_to_recipient: true,
        additional_recipients: []
    };

    var result = paypalClient->/v2/invoicing/invoices/[testInvoiceId]/send.post(payload, headers);

    if result is link_description {
        io:println("Invoice sent. HREF: ", result.href);
    } else if result is '202\-response {
        io:println("Invoice accepted for future delivery (202).");
    } else if result is error {
        io:println("Failed to send invoice: ", result.message());
        if result is http:ClientError {
            io:println("🔍 Error details: ", result.detail().toString());
        }
        test:assertFalse(true, msg = "Failed to send invoice: " + result.message());
    } else {
        io:println("Unexpected response type.");
    }
}

// ---------------------------------------------Test case to send an invoice reminder---------------------------------------------

// Helper function to check if an invoice is in SENT status
function isInvoiceSent(string invoiceId, map<string|string[]> headers) returns boolean|error {
    invoice result = check paypalClient->/v2/invoicing/invoices/[invoiceId].get(headers);
    return result.status == "SENT";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSendInvoice]
}
function testSendInvoiceReminder() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping invoice reminder test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Check if invoice is SENT
    boolean isSent = check isInvoiceSent(testInvoiceId, headers);
    if !isSent {
        io:println("Invoice is not in SENT state. Cannot send reminder.");
        return;
    }

    notification reminderPayload = {
        subject: "Reminder: Payment Due for Invoice",
        note: "This is a friendly reminder that your payment is due. Please process payment at your earliest convenience.",
        send_to_invoicer: true,
        send_to_recipient: true
    };

    error? result = paypalClient->/v2/invoicing/invoices/[testInvoiceId]/remind.post(reminderPayload, headers);

    if result is error {
        io:println("Failed to send invoice reminder: ", result.message());
        if result is http:ClientError {
            io:println("Error details: ", result.detail().toString());
        }
        test:assertFalse(true, msg = "Failed to send invoice reminder: " + result.message());
        return result;
    }

    io:println("Invoice reminder sent successfully for invoice ID: ", testInvoiceId);
    test:assertTrue(true, msg = "Invoice reminder sent successfully");
}

//-------------------------------------------Test case to cancel sent invoice---------------------------------------------
@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testDeleteExternalPayment]
}
function testCancelSentInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping cancel invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Check if invoice is in SENT status before canceling
    boolean isSent = check isInvoiceSent(testInvoiceId, headers);
    if !isSent {
        io:println("Invoice is not in SENT state. Cannot cancel.");
        return;
    }

    // Prepare notification payload for cancellation
    notification cancelPayload = {
        subject: "Invoice Cancellation Notice",
        note: "This invoice has been cancelled. Please disregard any previous payment requests for this invoice.",
        send_to_invoicer: false,
        send_to_recipient: true
    };

    // Cancel the invoice
    error? result = paypalClient->/v2/invoicing/invoices/[testInvoiceId]/cancel.post(cancelPayload, headers);

    if result is error {
        io:println("Failed to cancel invoice: ", result.message());

        if result is http:ClientError {
            io:println("Error details: ", result.detail().toString());
        }

        test:assertFalse(true, msg = "Failed to cancel invoice: " + result.message());
        return result;
    }

    io:println("Invoice cancelled successfully for invoice ID: ", testInvoiceId);
    test:assertTrue(true, msg = "Invoice cancelled successfully");
}

//------------------------------------ Test case to delete external payment ------------------------------------
@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testRecordPaymentForInvoice]
}
function testDeleteExternalPayment() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping delete payment test - no invoice ID available");
        return;
    }

    if testPaymentId.length() == 0 {
        io:println("Skipping delete payment test - no payment ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "PayPal-Request-Id": "delete-payment-" + testInvoiceId + "-" + testPaymentId
    };

    // Delete the external payment
    error? result = paypalClient->/v2/invoicing/invoices/[testInvoiceId]/payments/[testPaymentId].delete(headers);

    if result is error {
        io:println("Failed to delete external payment: ", result.message());

        if result is http:ClientError {
            io:println("Error details: ", result.detail().toString());
        }

        test:assertFalse(true, msg = "Failed to delete external payment: " + result.message());
    } else {
        io:println("External payment deleted successfully");
        io:println("Deleted payment ID: ", testPaymentId, " from invoice: ", testInvoiceId);
        test:assertTrue(true, msg = "External payment deleted successfully");

        // Clear the payment ID since it's been deleted
        testPaymentId = "";
    }
}

//------------------------------------ Helper function to wait for SENT state ------------------------------------
function waitForInvoiceToBeSent(string invoiceId, map<string|string[]> headers) returns boolean|error {
    int maxRetries = 5;
    int delayMs = 2000; // 2 seconds

    foreach int i in 0 ... maxRetries {
        boolean|error isSent = isInvoiceSent(invoiceId, headers);
        if isSent is error {
            return isSent;
        } else if isSent {
            return true;
        } else {
            runtime:sleep(<decimal>delayMs / 1000.0);
        }
    }

    return false; // after retries, still not sent
}

//------------------------------------ Test case to record payment for invoice ------------------------------------
@test:Config {
   groups: ["live_tests", "mock_tests"],
    dependsOn: [testSendInvoice]
}
function testRecordPaymentForInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping record payment test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "PayPal-Request-Id": "test-payment-" + testInvoiceId
    };

    // Wait for invoice to reach SENT state
    boolean isSent = check waitForInvoiceToBeSent(testInvoiceId, headers);
    if !isSent {
        io:println("Invoice did not reach SENT state in time. Skipping payment recording.");
        return;
    }

    // Prepare payment detail payload
    payment_detail paymentPayload = {
        method: "CASH",
        'type: "EXTERNAL",
        amount: {
            currency_code: "USD",
            value: "50.00"
        },
        payment_date: "2025-06-18",
        note: "Payment received via cash - Test payment recording"
    };

    // Record the payment
    payment_reference result = check paypalClient->/v2/invoicing/invoices/[testInvoiceId]/payments.post(paymentPayload, headers);

    io:println("Payment recorded successfully for invoice ID: ", testInvoiceId);
    if result.payment_id is string {
        io:println("Payment Reference ID: ", result.payment_id);
        testPaymentId = result.payment_id ?: "";
    }

    test:assertTrue(true, msg = "Payment recorded successfully");
    test:assertNotEquals(result.payment_id, (), msg = "Payment reference should have an ID");
}

//-----------------------------------Test case to show invoice details ------------------------------------
@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateDraftInvoice]
}
function testShowInvoiceDetails() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping show invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    invoice response = check paypalClient->/v2/invoicing/invoices/[testInvoiceId].get(headers);

    // Validate some key invoice fields
    io:println("Retrieved invoice: ", response.id);
    io:println("Status: ", response.status);
    io:println("Amount: ", response.amount?.currency_code, " ", response.amount?.value);

    test:assertEquals(response.id, testInvoiceId, msg = "Invoice ID should match");
    test:assertNotEquals(response.status, (), msg = "Invoice should have a status");
    test:assertNotEquals(response.amount?.value, (), msg = "Invoice should have an amount");
    test:assertTrue(true, msg = "Invoice details retrieved successfully");
}

// -----------------------------------Test case to delete an invoice ------------------------------------
@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateDraftInvoice]
}
function testDeleteInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("Skipping delete invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "PayPal-Request-Id": "delete-invoice-" + testInvoiceId
    };

    // Attempt to delete the invoice
    check paypalClient->/v2/invoicing/invoices/[testInvoiceId].delete(headers);

    io:println("Invoice deleted successfully: ", testInvoiceId);
    test:assertTrue(true, msg = "Invoice deleted successfully");
}
