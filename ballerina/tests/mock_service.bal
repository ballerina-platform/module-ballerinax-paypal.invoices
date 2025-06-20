// // Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
// //
// // WSO2 LLC. licenses this file to you under the Apache License,
// // Version 2.0 (the "License"); you may not use this file except
// // in compliance with the License.
// // You may obtain a copy of the License at
// //
// // http://www.apache.org/licenses/LICENSE-2.0
// //
// // Unless required by applicable law or agreed to in writing,
// // software distributed under the License is distributed on an
// // "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// // KIND, either express or implied.  See the License for the
// // specific language governing permissions and limitations
// // under the License.

import ballerina/http;
import ballerina/io;
import ballerina/time;

listener http:Listener mockListener = new (9090);

map<string> invoiceStates = {};

service / on mockListener {

    // POST /v2/invoicing/generate-next-invoice-number
    resource function post v2/invoicing/generate\-next\-invoice\-number() returns json {
        return {"invoice_number": "INV-MOCK-001"};
    }

    // POST /v2/invoicing/invoices
    resource function post v2/invoicing/invoices(@http:Payload json payload) returns json {
        json response = {
            id: "INV-MOCK-001",
            detail: {
                invoice_number: "INV-MOCK-001",
                currency_code: "USD",
                note: "Mock Invoice"
            },
            payload: payload
        };
        return response;
    }

    // GET /v2/invoicing/invoices
    resource function get v2/invoicing/invoices() returns json {
        return {
            total_count: 2,
            items: [
                {
                    id: "INV-MOCK-001",
                    status: "DRAFT",
                    detail: {
                        invoice_number: "INV-MOCK-001",
                        currency_code: "USD",
                        note: "Mock Invoice 1"
                    }
                },
                {
                    id: "INV-MOCK-002",
                    status: "SENT",
                    detail: {
                        invoice_number: "INV-MOCK-002",
                        currency_code: "USD",
                        note: "Mock Invoice 2"
                    }
                }
            ]
        };
    }

    // GET /v2/invoicing/invoices/{invoiceId} — main working version
    resource function get v2/invoicing/invoices/[string invoiceId]() returns invoice|error {

        invoice mockInvoice = {
            id: invoiceId,
            status: "DRAFT",
            detail: {
                invoice_number: invoiceId,
                currency_code: "USD",
                reference: "Ref-Mock",
                note: "This is a mock invoice.",
                memo: "Mock Memo",
                payment_term: {
                    term_type: "NET_30"
                }
            },
            invoicer: {
                name: {
                    given_name: "Mock",
                    surname: "Merchant"
                },
                email_address: "merchant@example.com"
            },
            primary_recipients: [
                {
                    billing_info: {
                        name: {
                            given_name: "John",
                            surname: "Doe"
                        },
                        email_address: "john.doe@example.com"
                    }
                }
            ],
            items: [
                {
                    name: "Mock Item",
                    quantity: "1",
                    unit_amount: {
                        currency_code: "USD",
                        value: "100.00"
                    }
                }
            ],
            amount: {
                currency_code: "USD",
                value: "100.00"
            }
        };

        return mockInvoice;
    }

    // POST /v2/invoicing/invoices/{invoiceId}/send
    resource function post v2/invoicing/invoices/[string invoiceId]/send() returns json {
        invoiceStates[invoiceId] = "SENT";
        time:Utc currentTime = time:utcNow();
        string currentTimestamp = time:utcToString(currentTime);
        io:println("Invoice sent successfully. Timestamp: ", currentTimestamp);

        return {
            id: invoiceId,
            status: "SENT",
            success: true,
            detail: {
                message: "Invoice sent successfully and accepted for future delivery (202)",
                timestamp: currentTimestamp
            }
        };
    }

    // POST /v2/invoicing/invoices/{invoiceId}/remind
    resource function post v2/invoicing/invoices/[string invoiceId]/remind() returns json {
        if invoiceStates[invoiceId] != "SENT" {
            return {
                "error": true,
                message: "Invoice is not in SENT state. Cannot send reminder."
            };
        }

        return {
            id: invoiceId,
            status: "SENT",
            detail: {
                message: "Reminder sent successfully"
            }
        };
    }

    // POST /v2/invoicing/invoices/{invoiceId}/cancel
    resource function post v2/invoicing/invoices/[string invoiceId]/cancel() returns json {
        if invoiceStates[invoiceId] != "SENT" {
            return {
                "error": true,
                message: "Invoice is not in SENT state. Cannot cancel."
            };
        }

        return {
            id: invoiceId,
            status: "CANCELLED",
            detail: {
                message: "Invoice cancelled successfully"
            }
        };
    }

    // POST /v2/invoicing/invoices/{invoiceId}/payments
    resource function post v2/invoicing/invoices/[string invoiceId]/payments() returns json {
        return {
            payment_id: "PAY-MOCK-" + invoiceId + "-001",
            status: "RECORD_SUCCESS",
            detail: {
                message: "Payment recorded successfully"
            }
        };
    }

    // DELETE /v2/invoicing/invoices/{invoiceId}
    resource function delete v2/invoicing/invoices/[string invoiceId]() returns http:NoContent {
        io:println("Mock delete invoice invoked for ID: ", invoiceId);
        return http:NO_CONTENT;
    }
}
