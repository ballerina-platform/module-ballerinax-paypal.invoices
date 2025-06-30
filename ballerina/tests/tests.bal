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

import ballerina/lang.runtime;
import ballerina/log;
import ballerina/test;

configurable string clientId = "clientId";
configurable string clientSecret = "clientSecret";
configurable boolean isLiveServer = false;
configurable string merchantEmail = "sample@example.com";

configurable string serviceUrl = isLiveServer ?
    "https://api-m.sandbox.paypal.com/v2/invoicing" :
    "http://localhost:9090";

configurable string tokenUrl = isLiveServer ?
    "https://api-m.sandbox.paypal.com/v1/oauth2/token" :
    "http://localhost:9444/oauth2/token";

string invoiceNumber = "";
string invoiceId = "";
string testPaymentId = "";
string testRefundId = "";

Client paypalClient = test:mock(Client);

@test:BeforeSuite
function initClient() returns error? {
    if !isLiveServer {
        check stsListener.attach(sts, "/oauth2");
        check stsListener.'start();
        check mockListener.'start();

        runtime:registerListener(stsListener);
        runtime:registerListener(mockListener);
        log:printInfo(string `STS started on port: ${HTTP_SERVER_PORT} (HTTP)`);
        log:printInfo("Mock PayPal service started on port: 9090 (HTTP)");
    }

    ConnectionConfig config = {auth: {clientId, clientSecret, tokenUrl}};
    paypalClient = check new (config, serviceUrl);
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testGenerateInvoiceNumber() returns error? {
    InvoiceNumber result = check paypalClient->/generate\-next\-invoice\-number.post();
    test:assertNotEquals(result.invoice_number, "", msg = "Invoice number must not be empty");
    invoiceNumber = result.invoice_number ?: "";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testGenerateInvoiceNumber]
}
function testCreateInvoice() returns error? {
    Invoice invoicePayload = {
        detail: {
            invoice_number: invoiceNumber,
            currency_code: "USD",
            note: "Test invoice note",
            terms_and_conditions: "Standard terms apply.",
            memo: "Internal memo"
        },
        primary_recipients: [
            {
                billing_info: {
                    email_address: merchantEmail
                }
            }
        ],
        items: [
            {
                name: "Sample Item",
                quantity: "1",
                unit_amount: {currency_code: "USD", value: "100.00"}
            }
        ]
    };

    Invoice createdInvoice = check paypalClient->/invoices.post(invoicePayload);

    test:assertNotEquals(createdInvoice.id, "", msg = "Invoice ID must not be empty");
    test:assertEquals(createdInvoice.detail.invoice_number, invoiceNumber, msg = "Invoice number must match");

    if createdInvoice.status is string {
        test:assertEquals(createdInvoice.status.toString(), "DRAFT", msg = "Invoice should be in DRAFT state");
    } else {
        test:assertFail(msg = "Invoice status is nil or invalid");
    }

    invoiceId = createdInvoice.id ?: "";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateInvoice]
}
function testGetInvoice() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous test");

    Invoice invoice = check paypalClient->/invoices/[invoiceId].get();

    test:assertEquals(invoice.id, invoiceId, msg = "Invoice ID mismatch in response");
    test:assertEquals(invoice.detail.invoice_number, invoiceNumber, msg = "Invoice number mismatch");
    test:assertEquals(invoice.detail.currency_code, "USD", msg = "Currency code should be USD");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testGetInvoice]
}
function testUpdateInvoice() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous test");

    Invoice updatedInvoicePayload = {
        detail: {
            invoice_number: invoiceNumber,
            currency_code: "USD",
            note: "Updated invoice note from test case",
            terms_and_conditions: "Updated terms apply.",
            memo: "Updated internal memo"
        },
        primary_recipients: [
            {
                billing_info: {
                    email_address: merchantEmail
                }
            }
        ],
        items: [
            {
                name: "Updated Item",
                quantity: "2",
                unit_amount: {
                    currency_code: "USD",
                    value: "500000.00"
                }
            }
        ]
    };

    Invoice updatedInvoice = check paypalClient->/invoices/[invoiceId].put(updatedInvoicePayload);

    test:assertEquals(updatedInvoice.id, invoiceId, msg = "Invoice ID must remain the same after update");
    test:assertEquals(updatedInvoice.detail.note, "Updated invoice note from test case", msg = "Note not updated");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testUpdateInvoice]
}
function testSendInvoice() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous test");

    Notification notificationPayload = {
        subject: "Invoice from Ballerina Test",
        note: "Please find your invoice attached.",
        send_to_invoicer: true,
        send_to_recipient: true
    };

    _ = check paypalClient->/invoices/[invoiceId]/send.post(notificationPayload);

    Invoice invoiceDetails = check paypalClient->/invoices/[invoiceId].get();

    test:assertTrue(invoiceDetails.status is string && (invoiceDetails.status == "SENT" || invoiceDetails.status == "PAYABLE"),
            msg = "Invoice status must be SENT or PAYABLE after sending"
    );
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSendInvoice]
}
function testSendInvoiceReminder() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous test");

    Notification reminderPayload = {
        subject: "Reminder: Invoice Payment Due",
        note: "This is a friendly reminder to please pay your invoice.",
        send_to_invoicer: true,
        send_to_recipient: true
    };

    check paypalClient->/invoices/[invoiceId]/remind.post(reminderPayload);
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSendInvoiceReminder]
}
function testRecordExternalPayment() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous tests");

    PaymentDetail paymentPayload = {
        method: "CASH",
        amount: {
            currency_code: "USD",
            value: "100.00"
        },
        note: "Payment received in cash"
    };

    PaymentReference paymentRef = check paypalClient->/invoices/[invoiceId]/payments.post(paymentPayload);

    anydata? paymentIdRaw = paymentRef["payment_id"];
    if paymentIdRaw is string {
        test:assertNotEquals(paymentIdRaw, "", msg = "Payment ID must not be empty");
        testPaymentId = paymentIdRaw;
    } else {
        return error("Payment ID is missing or not a string");
    }
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testRecordExternalPayment]
}
function testDeleteExternalPayment() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous tests");
    test:assertNotEquals(testPaymentId, "", msg = "testPaymentId must be set from previous tests");

    check paypalClient->/invoices/[invoiceId]/payments/[testPaymentId].delete();

    testPaymentId = "";
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCreateInvoice]
}
function testListInvoices() returns error? {
    Invoices invoicesList = check paypalClient->/invoices.get(page = 1, page_size = 5, total_required = true);
    test:assertTrue(invoicesList.total_items > 0, msg = "Invoices list should contain one or more invoices");
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testListInvoicesWithDifferentQueries() returns error? {
    Invoices result = check paypalClient->/invoices.get(page = 1, page_size = 2);
    Invoice[]? items = result.items;

    test:assertNotEquals(items, (), msg = "Items should not be nil");

    if items is Invoice[] {
        test:assertTrue(items.length() > 0, msg = "Items should not be empty");
        test:assertTrue(items.length() <= 2, msg = "Should return at most 2 invoices as per page_size");
    }
}

@test:Config {
    groups: ["live_tests", "mock_tests"]
}
function testListInvoicesErrorHandling() returns error? {
    Invoices|error result = paypalClient->/invoices.get(page = -1, page_size = 5);
    test:assertTrue(result is error, msg = "Expected error for invalid page number");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testSendInvoice]
}
function testCancelInvoice() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous tests");

    check paypalClient->/invoices/[invoiceId]/cancel.post({
        subject: "Canceling invoice before delete",
        note: "Canceling invoice to enable deletion"
    });

    Invoice invoiceDetails = check paypalClient->/invoices/[invoiceId].get();
    test:assertEquals(invoiceDetails.status, "CANCELLED", msg = "Invoice should be in CANCELLED state");
}

@test:Config {
    groups: ["live_tests", "mock_tests"],
    dependsOn: [testCancelInvoice]
}
function testDeleteInvoice() returns error? {
    test:assertNotEquals(invoiceId, "", msg = "invoiceId must be set from previous tests");
    check paypalClient->/invoices/[invoiceId].delete();
}

