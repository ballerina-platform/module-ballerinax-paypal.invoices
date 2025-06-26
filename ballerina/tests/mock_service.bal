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
import ballerina/time;

listener http:Listener mockListener = new (9090);

map<string> invoiceStates = {};
map<string> paymentRecords = {};

service / on mockListener {

    resource function post generate\-next\-invoice\-number() returns InvoiceNumber {
        return {invoice_number: "INV-MOCK-001"};
    }

    resource function post invoices(@http:Payload json payload) returns json {
        return {
            id: "INV-MOCK-001",
            detail: {
                invoice_number: "INV-MOCK-001",
                currency_code: "USD",
                note: "Mock Invoice"
            },
            payload: payload
        };
    }
    
    resource function get invoices(http:Request req) returns json|http:Response {
        var queryParams = req.getQueryParams();
        string|string[]? pageParam = queryParams.get("page");
        string? pageStr = pageParam is string ? pageParam : (pageParam is string[] ? pageParam[0] : ());

        if pageStr is string {
            int|error pageNum = int:fromString(pageStr);
            if pageNum is int {
                if pageNum <= 0 {
                    json errorResponse = {
                        name: "INVALID_REQUEST",
                        message: "Page number must be greater than 0."
                    };
                    http:Response res = new;
                    res.statusCode = 400;
                    res.setJsonPayload(errorResponse);
                    return res;
                }
            } else {
                json errorResponse = {
                    name: "INVALID_REQUEST",
                    message: "Invalid page number format."
                };
                http:Response res = new;
                res.statusCode = 400;
                res.setJsonPayload(errorResponse);
                return res;
            }
        }

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

    resource function get invoices/[string invoiceId]() returns json {
        return {
            id: invoiceId,
            status: invoiceStates[invoiceId] ?: "DRAFT",
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
    }

    resource function post invoices/[string invoiceId]/send() returns json {
        invoiceStates[invoiceId] = "SENT";
        time:Utc currentTime = time:utcNow();
        string currentTimestamp = time:utcToString(currentTime);

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

    resource function post invoices/[string invoiceId]/remind() returns http:NoContent|json {
        if invoiceStates[invoiceId] != "SENT" {
            return {
                "error": true,
                message: "Invoice is not in SENT state. Cannot send reminder."
            };
        }

        return http:NO_CONTENT;
    }

    resource function post invoices/[string invoiceId]/cancel() returns http:NoContent|json {
        if invoiceStates[invoiceId] != "SENT" {
            return {
                "error": true,
                message: "Invoice is not in SENT state. Cannot cancel."
            };
        }
        invoiceStates[invoiceId] = "CANCELLED";
        return http:NO_CONTENT;
    }

    resource function post invoices/[string invoiceId]/payments(@http:Payload json payload) returns json {
        string transactionId = "TRANSACTION-MOCK-" + invoiceId + "-001";
        paymentRecords[invoiceId] = transactionId;

        return {
            payment_id: "PAY-MOCK-" + invoiceId + "-001",
            transaction_id: transactionId,
            status: "RECORD_SUCCESS",
            detail: {
                message: "Payment recorded successfully"
            }
        };
    }

    resource function delete invoices/[string invoiceId]/payments/[string paymentId]() returns http:NoContent|json {
        if paymentRecords[invoiceId] != paymentId {
            json errorResponse = {
                "error": true,
                "message": "Payment ID not found for this invoice"
            };
            return errorResponse;
        }

        _ = paymentRecords.remove(invoiceId);
        return http:NO_CONTENT;
    }

    resource function delete invoices/[string invoiceId]() returns http:NoContent {
        return http:NO_CONTENT;
    }
}
