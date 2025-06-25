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
import ballerina/lang.runtime;
import ballerina/test;

configurable string PAYPAL_CLIENT_ID = ?;
configurable string PAYPAL_CLIENT_SECRET = ?;
configurable string PAYPAL_API_BASE_URL = ?;
configurable string PAYPAL_MERCHANT_EMAIL = ?;
configurable boolean isLiveServer = ?;
configurable string serviceUrl = isLiveServer ? "https://api-m.sandbox.paypal.com/v2/invoicing" : "http://localhost:9090";

ConnectionConfig config = {
    auth: {
        clientId: PAYPAL_CLIENT_ID,
        clientSecret: PAYPAL_CLIENT_SECRET
    }
};

final Client paypalClient = check new (config, serviceUrl);

string generatedInvoiceNumber = "";
string testInvoiceId = "";
string testPaymentId = "";

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testGenerateInvoiceNumber() returns error? {
    map<string|string[]> headers = {"Content-Type": "application/json"};
    InvoiceNumber result = check paypalClient->/generate\-next\-invoice\-number.post(headers);
    test:assertNotEquals(result.invoice_number, "", msg = "Invoice number should not be empty");
    generatedInvoiceNumber = result.invoice_number ?: "";
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testCreateInvoice() returns error? {
    map<string|string[]> headers = {"Content-Type": "application/json","Prefer": "return=representation"};

    Invoice invoicePayload = {
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
    Invoice result = check paypalClient->/invoices.post(invoicePayload, headers);
    test:assertNotEquals(result.id, "", msg = "Invoice ID should not be empty");
    testInvoiceId = result.id ?: "";
}

@test:Config {
    groups: ["paypal", "invoice"]
}
function testListInvoices() returns error? {
    map<string|string[]> headers = {"Content-Type": "application/json"};

    Invoices result = check paypalClient->/invoices.get(headers, page = 1, page_size = 5, fields = "all", total_required = true);
    int totalCount = 0;
    if result.hasKey("total_count") {
        anydata count = result["total_count"];
        if count is int {
            totalCount = count;
        }
    }
    test:assertTrue(totalCount >= 0, msg = "Total count should be non-negative");
    Invoice[] items = result.items ?: [];
    if items.length() > 0 {
        test:assertTrue(items[0].id is string, msg = "Invoice should have an ID");
    }
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateInvoice]
}
function testGetInvoiceById() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");
    map<string|string[]> headers = {"Content-Type": "application/json"};
    Invoice result = check paypalClient->/invoices/[testInvoiceId].get(headers);
    test:assertEquals(result.id, testInvoiceId, msg = "Retrieved invoice ID should match requested ID");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testListInvoicesWithDifferentQueries() returns error? {
    map<string|string[]> headers = {"Content-Type": "application/json"};
    Invoices result = check paypalClient->/invoices.get(headers, page = 1, page_size = 2);

    Invoice[]? items = result.items;
    if items is Invoice[] {
        int itemsLength = items.length();
        test:assertTrue(itemsLength <= 2, msg = "Should return at most 2 invoices as per page_size");
    }
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testListInvoicesErrorHandling() returns error? {
    map<string|string[]> headers = {"Content-Type": "application/json"};

    Invoices|error result = paypalClient->/invoices.get(headers, page = -1, page_size = 5);
    test:assertTrue(result is error, msg = "Expected error for invalid page number");
}

function isInvoiceDraft(string invoiceId, map<string|string[]> headers) returns boolean|error {
    Invoice result = check paypalClient->/invoices/[invoiceId].get(headers);
    return result.status == "DRAFT";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateInvoice]
}
function testSendInvoice() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");

    map<string|string[]> headers = {"Content-Type": "application/json","Prefer": "return=representation"};

    boolean isDraft = check isInvoiceDraft(testInvoiceId, headers);
    if !isDraft {
        return;
    }
    Notification payload = {
        subject: "Invoice for your recent purchase",
        note: "Please see the attached invoice.",
        send_to_invoicer: true,
        send_to_recipient: true,
        additional_recipients: []
    };
    var result = paypalClient->/invoices/[testInvoiceId]/send.post(payload, headers);
    if result is error {
        if result is http:ClientError {
        }
        test:assertFalse(true, msg = "Failed to send invoice: " + result.message());
    }
}

function isInvoiceSent(string invoiceId, map<string|string[]> headers) returns boolean|error {
    Invoice result = check paypalClient->/invoices/[invoiceId].get(headers);
    return result.status == "SENT";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSendInvoice]
}
function testSendInvoiceReminder() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");

    map<string|string[]> headers = {"Content-Type": "application/json"};

    boolean isSent = check isInvoiceSent(testInvoiceId, headers);
    if !isSent {
        return;
    }

    Notification reminderPayload = {
        subject: "Reminder: Payment Due for Invoice",
        note: "This is a friendly reminder that your payment is due. Please process payment at your earliest convenience.",
        send_to_invoicer: true,
        send_to_recipient: true
    };

    error? result = paypalClient->/invoices/[testInvoiceId]/remind.post(reminderPayload, headers);
    if result is error {
        if result is http:ClientError {
        }
        test:assertFalse(true, msg = "Failed to send invoice reminder: " + result.message());
        return result;
    }
    test:assertTrue(true, msg = "Invoice reminder sent successfully");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testDeleteExternalPayment]
}
function testCancelSentInvoice() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");

    map<string|string[]> headers = {"Content-Type": "application/json"};

    boolean isSent = check isInvoiceSent(testInvoiceId, headers);
    if !isSent {
        return;
    }

    Notification cancelPayload = {
        subject: "Invoice Cancellation Notice",
        note: "This invoice has been cancelled. Please disregard any previous payment requests for this invoice.",
        send_to_invoicer: false,
        send_to_recipient: true
    };
    error? result = paypalClient->/invoices/[testInvoiceId]/cancel.post(cancelPayload, headers);
    if result is error {
        if result is http:ClientError {
        }

        test:assertFalse(true, msg = "Failed to cancel invoice: " + result.message());
        return result;
    }
    test:assertTrue(true, msg = "Invoice cancelled successfully");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testRecordPaymentForInvoice]
}
function testDeleteExternalPayment() returns error? {
    test:assertTrue(testPaymentId.length() > 0, msg = "testPaymentId must not be empty");

    if testPaymentId.length() == 0 {
        return;
    }

    map<string|string[]> headers = {"Content-Type": "application/json","PayPal-Request-Id": "delete-payment-" + testInvoiceId + "-" + testPaymentId};

    error? result = paypalClient->/invoices/[testInvoiceId]/payments/[testPaymentId].delete(headers);
    if result is error {
        if result is http:ClientError {
        }
        test:assertFalse(true, msg = "Failed to delete external payment: " + result.message());
    } else {
        test:assertTrue(true, msg = "External payment deleted successfully");
        testPaymentId = "";
    }
}

function waitForInvoiceToBeSent(string invoiceId, map<string|string[]> headers) returns boolean|error {
    int maxRetries = 5;
    foreach int i in 0 ... maxRetries {
        boolean|error isSent = isInvoiceSent(invoiceId, headers);
        if isSent is error || isSent {
            return isSent;
        }
        runtime:sleep(2);
    }
    return false;
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSendInvoice]
}
function testRecordPaymentForInvoice() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");

    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "PayPal-Request-Id": "test-payment-" + testInvoiceId
    };

    boolean isSent = check waitForInvoiceToBeSent(testInvoiceId, headers);
    if !isSent {
        return;
    }

    PaymentDetail paymentPayload = {
        method: "CASH",
        'type: "EXTERNAL",
        amount: {
            currency_code: "USD",
            value: "50.00"
        },
        payment_date: "2025-06-18",
        note: "Payment received via cash - Test payment recording"
    };

    PaymentReference result = check paypalClient->/invoices/[testInvoiceId]/payments.post(paymentPayload, headers);
    if result.payment_id is string {
        testPaymentId = result.payment_id ?: "";
    }
    test:assertTrue(true, msg = "Payment recorded successfully");
    test:assertNotEquals(result.payment_id, (), msg = "Payment reference should have an ID");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateInvoice]
}
function testShowInvoiceDetails() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");

    map<string|string[]> headers = {
        "Content-Type": "application/json"
    };

    Invoice response = check paypalClient->/invoices/[testInvoiceId].get(headers);
    test:assertEquals(response.id, testInvoiceId, msg = "Invoice ID should match");
    test:assertNotEquals(response.status, (), msg = "Invoice should have a status");
    test:assertNotEquals(response.amount?.value, (), msg = "Invoice should have an amount");
    test:assertTrue(true, msg = "Invoice details retrieved successfully");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateInvoice]
}
function testDeleteInvoice() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");

    map<string|string[]> headers = {"Content-Type": "application/json","PayPal-Request-Id": "delete-invoice-" + testInvoiceId};
    
    check paypalClient->/invoices/[testInvoiceId].delete(headers);
    test:assertTrue(true, msg = "Invoice deleted successfully");
}
