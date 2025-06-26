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
import ballerina/test;
import ballerina/lang.runtime;

configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string merchantEmail = ?;
configurable boolean isLiveServer = ?;
configurable string serviceUrl = isLiveServer ? "https://api-m.sandbox.paypal.com/v2/invoicing" : "http://localhost:9090";

ConnectionConfig config = {
    auth: {
        clientId,
        clientSecret
    }
};

final Client paypalClient = check new (config, serviceUrl);

string generatedInvoiceNumber = "";
string testInvoiceId = "";
string testPaymentId = "";
string paymentTransactionId = "";

@test:BeforeSuite
function setup() returns error? {
    InvoiceNumber result = check paypalClient->/generate\-next\-invoice\-number.post();
    generatedInvoiceNumber = result.invoice_number ?: "";
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function CreateInvoice() returns error? {
    test:assertNotEquals(generatedInvoiceNumber, "", msg = "Invoice number must be set before creating invoice");

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
            email_address: merchantEmail
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

    Invoice result = check paypalClient->/invoices.post(invoicePayload);
    test:assertNotEquals(result.id, "", msg = "Invoice ID should not be empty");
    testInvoiceId = result.id ?: "";
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function ListInvoices() returns error? {
    Invoices result = check paypalClient->/invoices.get(page = 1, page_size = 5, total_required = true);
    int totalCount = 0;
    if result.hasKey("total_items") {
        anydata count = result["total_items"];
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
    dependsOn: [CreateInvoice]
}
function testRetrieveInvoiceById() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");
    Invoice result = check paypalClient->/invoices/[testInvoiceId];
    test:assertEquals(result.id, testInvoiceId, msg = "Retrieved invoice ID should match requested ID");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testListInvoicesWithDifferentQueries() returns error? {
    Invoices result = check paypalClient->/invoices.get(page = 1, page_size = 2);
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
    Invoices|error result = paypalClient->/invoices.get(page = -1, page_size = 5);
    test:assertTrue(result is error, msg = "Expected error for invalid page number");
}

function isInvoiceDraft(string invoiceId) returns boolean|error {
    Invoice result = check paypalClient->/invoices/[invoiceId];
    return result.status == "DRAFT";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [CreateInvoice]
}
function SendInvoice() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");
    boolean isDraft = check isInvoiceDraft(testInvoiceId);
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
    var result = paypalClient->/invoices/[testInvoiceId]/send.post(payload);
    if result is error {
        if result is http:ClientError {
        }
        test:assertFalse(true, msg = "Failed to send invoice: " + result.message());
    }
}

function isInvoiceSent(string invoiceId) returns boolean|error {
    Invoice result = check paypalClient->/invoices/[invoiceId];
    return result.status == "SENT";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [SendInvoice]
}
function testSendInvoiceReminder() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");
    boolean isSent = check isInvoiceSent(testInvoiceId);
    if !isSent {
        return;
    }

    Notification reminderPayload = {
        subject: "Reminder: Payment Due for Invoice",
        note: "This is a friendly reminder that your payment is due. Please process payment at your earliest convenience.",
        send_to_invoicer: true,
        send_to_recipient: true
    };

    error? result = paypalClient->/invoices/[testInvoiceId]/remind.post(reminderPayload);
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
    dependsOn: [SendInvoice]
}
function CancelSentInvoice() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");
    boolean isSent = check isInvoiceSent(testInvoiceId);
    if !isSent {
        return;
    }

    Notification cancelPayload = {
        subject: "Invoice Cancellation Notice",
        note: "This invoice has been cancelled. Please disregard any previous payment requests for this invoice.",
        send_to_invoicer: false,
        send_to_recipient: true
    };
    error? result = paypalClient->/invoices/[testInvoiceId]/cancel.post(cancelPayload);
    if result is error {
        if result is http:ClientError {
        }
        test:assertFalse(true, msg = "Failed to cancel invoice: " + result.message());
        return result;
    }
    test:assertTrue(true, msg = "Invoice cancelled successfully");
}

function waitForInvoiceToBeSent(string invoiceId) returns boolean|error {
    int maxRetries = 5;
    foreach int i in 0 ... maxRetries {
        boolean|error isSent = isInvoiceSent(invoiceId);
        if isSent is error || isSent {
            return isSent;
        }
        runtime:sleep(2);
    }
    return false;
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [CreateInvoice]
}
function testShowInvoiceDetails() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");
    Invoice response = check paypalClient->/invoices/[testInvoiceId];
    test:assertEquals(response.id, testInvoiceId, msg = "Invoice ID should match");
    test:assertNotEquals(response.status, (), msg = "Invoice should have a status");
    test:assertNotEquals(response.amount?.value, (), msg = "Invoice should have an amount");
    test:assertTrue(true, msg = "Invoice details retrieved successfully");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [CreateInvoice]
}
function DeleteInvoice() returns error? {
    test:assertTrue(testInvoiceId.length() > 0, msg = "testInvoiceId must not be empty");
    check paypalClient->/invoices/[testInvoiceId].delete();
    test:assertTrue(true, msg = "Invoice deleted successfully");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [CreateInvoice]
}
function testRecordPayment() returns error? {
    PaymentDetail paymentPayload = {
        method: "CREDIT_CARD",
        "date": "2025-06-26",
        amount: {
            currency_code: "USD",
            value: "100.00"
        },
        note: "Payment recorded by test"
    };

    var paymentResponse = paypalClient->/invoices/[testInvoiceId]/payments.post(
        paymentPayload
    );

    if (paymentResponse is PaymentReference) {
        paymentTransactionId = paymentResponse["transaction_id"].toString();
        test:assertNotEquals(paymentTransactionId, "", msg = "Transaction ID should not be empty");
    } else if (paymentResponse is error) {
        return;
    }
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testRecordPayment]
}
function testDeleteExternalPayment() returns error? {
    if (paymentTransactionId == "") {
        return;
    }
    error? deleteResult = paypalClient->/invoices/[testInvoiceId]/payments/[paymentTransactionId].delete();
    if (deleteResult is error) {
        return;
    }
}
