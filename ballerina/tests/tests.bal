import ballerina/io;
import ballerina/test;
import ballerina/http;
import ballerina/lang.runtime;

configurable string PAYPAL_CLIENT_ID = ?;
configurable string PAYPAL_CLIENT_SECRET = ?;
configurable string PAYPAL_API_BASE_URL = ?;
configurable string PAYPAL_MERCHANT_EMAIL = ?;

// Initialize the PayPal client for sandbox
ConnectionConfig config = {
    auth: {
        tokenUrl: "https://api-m.sandbox.paypal.com/v1/oauth2/token",
        clientId: PAYPAL_CLIENT_ID,
        clientSecret: PAYPAL_CLIENT_SECRET
    }
};

Client paypalClient = check new Client(config,PAYPAL_API_BASE_URL); // Assuming your connector accepts this

string generatedInvoiceNumber = "";
string testInvoiceId = "";
string testPaymentId = "";

// Test case to generate a draft invoice number
@test:Config {
    groups: ["paypal", "invoice"]
}

function testGenerateNextInvoiceNumber() returns error? {
    map<string|string[]> headers = {"Content-Type": "application/json"};
    InvoiceNumber|error result = paypalClient->/generate\-next\-invoice\-number.post(headers);

    test:assertFalse(result is error, msg = "Failed to generate next invoice number");

    if result is InvoiceNumber {
        io:println("Generated Invoice Number: ", result);
        test:assertNotEquals(result.invoiceNumber, "", msg = "Invoice number should not be empty");

        // Save for next test
        generatedInvoiceNumber = result.invoiceNumber ?: "";
    }
}

// Test case to create a draft invoice
@test:Config {
    groups: ["paypal", "invoice"]
}
function testCreateDraftInvoice() returns error? {
    // Prepare headers
    map<string|string[]> headers = {
        "Content-Type": "application/json",
       "Prefer": "return=representation"
    };

    // Prepare a minimal valid invoice payload
    Invoice invoicePayload = {
        detail: {
            invoice_number: generatedInvoiceNumber,
            reference: "PO-123456",
            invoice_date: "2025-06-17",
            currency_code: "USD",
            note: "Thanks for your business!",
           "term": "Net 30",
            memo: "Test invoice memo",
            "paymentTerm": {
                termType: "NET_30"
            }
        },
        invoicer: {
            name: {
                givenName: "Dharshan",
                surname: "Doe"
            },
            email_address: PAYPAL_MERCHANT_EMAIL
        },
        primaryRecipients: [
            {
                billingInfo: {
                    name: {
                        givenName: "Ravindran",
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
                unitAmount: {
                    currencyCode: "USD",
                    value: "25.00"
                }
            }
        ]
    };

    // Call the resource function to create the invoice
    Invoice|error result = paypalClient->/invoices.post(invoicePayload, headers);
    // Assert that the result is not an error
    test:assertFalse(result is error, msg = "Failed to create invoice");

    // Optionally verify some key fields in the result
    if result is error {
        io:println("❌ Invoice creation failed with error: ", result.message());
        return result;
    } else if result is Invoice {
        // Save the invoice ID for use in dependent tests
        testInvoiceId = result.id ?: "";
    }
}

// Test case to list invoices
@test:Config {
    groups: ["paypal", "invoice"]
}
function testListInvoices() returns error? {
    // Prepare headers
    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Query parameters
    InvoicesListQueries queries = {
        page: 1,
        pageSize: 5,
        fields: "all",
        totalRequired: true
    };

    // Call the connector function
    Invoices|error result = paypalClient->/invoices.get(headers, queries);

    // Assert the result is not an error
    test:assertFalse(result is error, msg = "Failed to list invoices");

    if result is Invoices {
        // Use member access for totalCount
        anydata totalCount = result["totalCount"];
        if totalCount is int {
            io:println("✅ Total Invoices: ", totalCount.toString());
            test:assertTrue(totalCount >= 0, msg = "Total count should be non-negative");
        }

        // Safely access items
        Invoice[]? items = result.items;
        if items is Invoice[] {
            int itemsLength = items.length();
            if itemsLength > 0 {
                io:println("🧾 First Invoice ID: ", items[0].id);
                test:assertTrue(items[0].id is string, msg = "Invoice should have an ID");
            } else {
                io:println("📭 No invoices found.");
            }
        } else {
            io:println("📭 No invoice items in response.");
        }
    }
}

// Test case to get an invoice by ID
@test:Config {
    groups: ["paypal", "invoice"],
    dependsOn: [testCreateDraftInvoice]
}
function testGetInvoiceById() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("⚠️ Skipping get invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    Invoice|error result = paypalClient->/invoices/[testInvoiceId].get(headers);

    test:assertFalse(result is error, msg = "Failed to get invoice by ID");

    if result is Invoice {
        io:println("✅ Retrieved invoice: ", result.id);
        test:assertEquals(result.id, testInvoiceId, msg = "Retrieved invoice ID should match requested ID");
    }
}


// Test case to list invoices with different queries
@test:Config {
    groups: ["paypal", "invoice"]
}
function testListInvoicesWithDifferentQueries() returns error? {
    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Test with minimal queries
    InvoicesListQueries queries = {
        page: 1,
        pageSize: 2
    };

    Invoices|error result = paypalClient->/invoices.get(headers, queries);

    test:assertFalse(result is error, msg = "Failed to list invoices with minimal queries");

    if result is Invoices {
        Invoice[]? items = result.items;
        if items is Invoice[] {
            int itemsLength = items.length();
            test:assertTrue(itemsLength <= 2, msg = "Should return at most 2 invoices as per pageSize");
            io:println("✅ Retrieved ", itemsLength.toString(), " invoices with minimal queries");
        }
    }
}

// Test case to handle errors in listing invoices
@test:Config {
    groups: ["paypal", "invoice"]
}
function testListInvoicesErrorHandling() returns error? {
    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Test with invalid page number
    InvoicesListQueries invalidQueries = {
        page: -1,
        pageSize: 5
    };

    Invoices|error result = paypalClient->/invoices.get(headers, invalidQueries);

    // This might succeed or fail depending on PayPal's validation
    // Just ensure we handle both cases properly
    if result is error {
        io:println("⚠️ Expected error for invalid page number: ", result.message());
    } else {
        io:println("✅ PayPal handled invalid page number gracefully");
    }
}

// Helper function to check if an invoice is in DRAFT status
function isInvoiceDraft(string invoiceId, map<string|string[]> headers) returns boolean|error {
    Invoice|error result = paypalClient->/invoices/[invoiceId].get(headers);
    if result is error {
        return result;
    }
    if result is Invoice {
        // Assuming the status field exists and is a string
        if result.status is string {
            return result.status == "DRAFT";
        }
    }
    return false;
}

// ---------------------------------------------Test case to send an invoice---------------------------------------------
@test:Config {
    groups: ["paypal", "invoice"],
    dependsOn: [testCreateDraftInvoice]
}
function testSendInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("⚠️ Skipping send invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "Prefer": "return=representation"
    };

    boolean|error isDraft = isInvoiceDraft(testInvoiceId, headers);
    if isDraft is error {
        io:println("❌ Could not verify invoice status: ", isDraft.message());
        return isDraft;
    } else if !isDraft {
        io:println("⚠️ Invoice is not in DRAFT state. Cannot send.");
        return;
    }

    Notification payload = {
        subject: "Invoice for your recent purchase",
        note: "Please see the attached invoice.",
        sendToInvoicer: true,
        sendToRecipient: true,
        additionalRecipients: []
    };

    LinkDescription|'202Response|error result = paypalClient->/invoices/[testInvoiceId]/send.post(payload, headers);

    if result is error {
        io:println("❌ Failed to send invoice: ", result.message());

        if result is http:ClientError {
            io:println("🔍 Error details: ", result.detail().toString());
        }

        test:assertFalse(true, msg = "Failed to send invoice: " + result.message());
    } else if result is LinkDescription {
        io:println("✅ Invoice sent. HREF: ", result.href);
    } else if result is '202Response {
        io:println("✅ Invoice accepted for future delivery (202).");
    }
}

// ---------------------------------------------Test case to send an invoice reminder---------------------------------------------

// Helper function to check if an invoice is in SENT status
function isInvoiceSent(string invoiceId, map<string|string[]> headers) returns boolean|error {
    Invoice|error result = paypalClient->/invoices/[invoiceId].get(headers);
    if result is error {
        return result;
    }
    if result is Invoice {
        if result.status is string {
            return result.status == "SENT";
        }
    }
    return false;
}

// Test case to send invoice reminder
@test:Config {
    groups: ["paypal", "invoice"],
    dependsOn: [testSendInvoice]
}
function testSendInvoiceReminder() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("⚠️ Skipping invoice reminder test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Check if invoice is in SENT status before sending reminder
    boolean|error isSent = isInvoiceSent(testInvoiceId, headers);
    if isSent is error {
        io:println("❌ Could not verify invoice status: ", isSent.message());
        return isSent;
    } else if !isSent {
        io:println("⚠️ Invoice is not in SENT state. Cannot send reminder.");
        return;
    }

    // Prepare notification payload for reminder
    Notification reminderPayload = {
        subject: "Reminder: Payment Due for Invoice",
        note: "This is a friendly reminder that your payment is due. Please process payment at your earliest convenience.",
        sendToInvoicer: true,
        sendToRecipient: true
    };

    // Send the reminder
    error? result = paypalClient->/invoices/[testInvoiceId]/remind.post(reminderPayload, headers);

    if result is error {
        io:println("❌ Failed to send invoice reminder: ", result.message());
        
        if result is http:ClientError {
            io:println("🔍 Error details: ", result.detail().toString());
        }
        
        test:assertFalse(true, msg = "Failed to send invoice reminder: " + result.message());
    } else {
        io:println("✅ Invoice reminder sent successfully for invoice ID: ", testInvoiceId);
        test:assertTrue(true, msg = "Invoice reminder sent successfully");
    }
}

//-------------------------------------------Test case to cancel sent invoice---------------------------------------------
@test:Config {
    groups: ["paypal", "invoice"],
    dependsOn: [testDeleteExternalPayment]
}
function testCancelSentInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("⚠️ Skipping cancel invoice test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    // Check if invoice is in SENT status before canceling
    boolean|error isSent = isInvoiceSent(testInvoiceId, headers);
    if isSent is error {
        io:println("❌ Could not verify invoice status: ", isSent.message());
        return isSent;
    } else if !isSent {
        io:println("⚠️ Invoice is not in SENT state. Cannot cancel.");
        return;
    }

    // Prepare notification payload for cancellation
    Notification cancelPayload = {
        subject: "Invoice Cancellation Notice",
        note: "This invoice has been cancelled. Please disregard any previous payment requests for this invoice.",
        sendToInvoicer: true,
        sendToRecipient: true
    };

    // Cancel the invoice
    error? result = paypalClient->/invoices/[testInvoiceId]/cancel.post(cancelPayload, headers);

    if result is error {
        io:println("❌ Failed to cancel invoice: ", result.message());
        
        if result is http:ClientError {
            io:println("🔍 Error details: ", result.detail().toString());
        }
        
        test:assertFalse(true, msg = "Failed to cancel invoice: " + result.message());
    } else {
        io:println("✅ Invoice cancelled successfully for invoice ID: ", testInvoiceId);
        test:assertTrue(true, msg = "Invoice cancelled successfully");
    }
}

//------------------------------------ Helper function to wait for SENT state ------------------------------------
function waitForInvoiceToBeSent(string invoiceId, map<string|string[]> headers) returns boolean|error {
    int maxRetries = 5;
    int delayMs = 2000; // 2 seconds

    foreach int i in 0...maxRetries {
        boolean|error isSent = isInvoiceSent(invoiceId, headers);
        if isSent is error {
            return isSent;
        } else if isSent {
            return true;
        } else {
            io:println("⏳ Invoice not in SENT state yet. Retrying in ", delayMs, "ms...");
            runtime:sleep(<decimal>delayMs / 1000.0);
        }
    }

    return false; // after retries, still not sent
}

//------------------------------------ Test case to record payment for invoice ------------------------------------
@test:Config {
    groups: ["paypal", "invoice"],
    dependsOn: [testSendInvoice]
}
function testRecordPaymentForInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("⚠️ Skipping record payment test - no invoice ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "PayPal-Request-Id": "test-payment-" + testInvoiceId
    };

    // Wait for invoice to reach SENT state
    boolean|error isSent = waitForInvoiceToBeSent(testInvoiceId, headers);
    if isSent is error {
        io:println("❌ Could not verify invoice status: ", isSent.message());
        return isSent;
    } else if !isSent {
        io:println("⚠️ Invoice did not reach SENT state in time. Skipping payment recording.");
        return;
    }

    // Prepare payment detail payload
    PaymentDetail paymentPayload = {
        method: "CASH",
        'type: "EXTERNAL",
        amount: {
            currencyCode: "USD",
            value: "50.00"
        },
        paymentDate: "2025-06-18",
        note: "Payment received via cash - Test payment recording"
    };

    // Record the payment
    PaymentReference|error result = paypalClient->/invoices/[testInvoiceId]/payments.post(paymentPayload, headers);

    if result is error {
        io:println("❌ Failed to record payment for invoice: ", result.message());

        if result is http:ClientError {
            io:println("🔍 Error details: ", result.detail().toString());
        }

        test:assertFalse(true, msg = "Failed to record payment for invoice: " + result.message());
    } else if result is PaymentReference {
        io:println("✅ Payment recorded successfully for invoice ID: ", testInvoiceId);
        if result.paymentId is string {
            io:println("💰 Payment Reference ID: ", result.paymentId);
            testPaymentId = result.paymentId ?: ""; // Save the payment ID for deletion test
        }
        test:assertTrue(true, msg = "Payment recorded successfully");
        test:assertNotEquals(result.paymentId, (), msg = "Payment reference should have an ID");
    }
}

//------------------------------------ Test case to delete external payment ------------------------------------
@test:Config {
    groups: ["paypal", "invoice"],
    dependsOn: [testRecordPaymentForInvoice]
}
function testDeleteExternalPayment() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("⚠️ Skipping delete payment test - no invoice ID available");
        return;
    }

    if testPaymentId.length() == 0 {
        io:println("⚠️ Skipping delete payment test - no payment ID available");
        return;
    }

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "PayPal-Request-Id": "delete-payment-" + testInvoiceId + "-" + testPaymentId
    };

    // Delete the external payment
    error? result = paypalClient->/invoices/[testInvoiceId]/payments/[testPaymentId].delete(headers);

    if result is error {
        io:println("❌ Failed to delete external payment: ", result.message());

        if result is http:ClientError {
            io:println("🔍 Error details: ", result.detail().toString());
        }

        test:assertFalse(true, msg = "Failed to delete external payment: " + result.message());
    } else {
        io:println("✅ External payment deleted successfully");
        io:println("🗑️ Deleted payment ID: ", testPaymentId, " from invoice: ", testInvoiceId);
        test:assertTrue(true, msg = "External payment deleted successfully");

        // Clear the payment ID since it's been deleted
        testPaymentId = "";
    }
}

// -----------------------------------Test case to generate QR code for an invoice ------------------------------------
@test:Config {
    groups: ["paypal", "invoice"],
    dependsOn: [testCreateDraftInvoice]
}
function testGenerateQrCodeForInvoice() returns error? {
    if testInvoiceId.length() == 0 {
        io:println("⚠️ Skipping QR code test - no invoice ID available");
        return;
    }

    QrConfig config = {
        width: 300,
        height: 300,
        action: "pay" // or "details"
    };

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "PayPal-Request-Id": "generate-qr-" + testInvoiceId
    };

    // Generate QR code
    error? result = paypalClient->/invoices/[testInvoiceId]/generate\-qr\-code.post(config, headers);

    if result is error {
        io:println("❌ Failed to generate QR code: ", result.message());
        test:assertFalse(true, msg = "QR code generation failed");
        return result;
    } else {
        io:println("✅ QR code generated successfully for invoice: ", testInvoiceId);
        test:assertTrue(true, msg = "QR code generation successful");
    }
}
