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
map<string> mapPayments = {};

final Invoice defaultInvoice1 = {
    id: "INV-DEFAULT-001",
    status: "DRAFT",
    detail: {
        invoice_number: "INV-DEFAULT-001",
        currency_code: "USD",
        note: "Default test invoice 1"
    },
    primary_recipients: [
        {
            billing_info: {
                email_address: "test1@example.com"
            }
        }
    ],
    items: [
        {
            id: "ITEM-001",
            name: "Test Item 1",
            quantity: "1",
            unit_amount: {
                currency_code: "USD",
                value: "50.00"
            }
        }
    ],
    amount: {
        currency_code: "USD",
        value: "50.00",
        breakdown: {
            item_total: {
                currency_code: "USD",
                value: "50.00"
            },
            discount: {
                invoice_discount: {
                    amount: {
                        currency_code: "USD",
                        value: "0.00"
                    }
                },
                item_discount: {
                    currency_code: "USD",
                    value: "0.00"
                }
            },
            tax_total: {
                currency_code: "USD",
                value: "0.00"
            }
        }
    }
};

final Invoice defaultInvoice2 = {
    id: "INV-DEFAULT-002",
    status: "SENT",
    detail: {
        invoice_number: "INV-DEFAULT-002",
        currency_code: "USD",
        note: "Default test invoice 2"
    },
    primary_recipients: [
        {
            billing_info: {
                email_address: "test2@example.com"
            }
        }
    ],
    items: [
        {
            id: "ITEM-002",
            name: "Test Item 2",
            quantity: "2",
            unit_amount: {
                currency_code: "USD",
                value: "75.00"
            }
        }
    ],
    amount: {
        currency_code: "USD",
        value: "150.00",
        breakdown: {
            item_total: {
                currency_code: "USD",
                value: "150.00"
            },
            discount: {
                invoice_discount: {
                    amount: {
                        currency_code: "USD",
                        value: "0.00"
                    }
                },
                item_discount: {
                    currency_code: "USD",
                    value: "0.00"
                }
            },
            tax_total: {
                currency_code: "USD",
                value: "0.00"
            }
        }
    }
};

final map<Invoice> defaultInvoices = {
    "INV-DEFAULT-001": defaultInvoice1,
    "INV-DEFAULT-002": defaultInvoice2
};

map<Invoice> invoices = defaultInvoices.clone();

service / on mockListener {
    resource function post generate\-next\-invoice\-number() returns InvoiceNumber {
        return {invoice_number: "INV-MOCK-001"};
    }

    resource function post invoices(Invoice payload) returns Invoice {
        string invoiceId = "INV2-MOCK-12345";
        Invoice createdInvoice = {
            id: invoiceId,
            status: "DRAFT",
            detail: payload.detail,
            primary_recipients: payload.primary_recipients,
            items: payload.items,
            amount: {
                currency_code: payload.detail.currency_code,
                value: "100.00"
            }
        };
        invoices[invoiceId] = createdInvoice;
        return createdInvoice;
    }

    resource function get invoices/[string invoiceId]() returns Invoice|error {
        Invoice? maybeInvoice = invoices[invoiceId];
        if maybeInvoice is Invoice {
            Invoice invoice = maybeInvoice;

            string? currentStatus = invoiceStates[invoiceId];
            if currentStatus is string {
                InvoiceStatus? newStatus = <InvoiceStatus?>currentStatus;
                invoice.status = newStatus;
            }
            return invoice;
        }
        return error("Invoice not found: " + invoiceId);
    }

    resource function put invoices/[string invoiceId](Invoice updatedInvoice) returns Invoice|error {
        if invoices.hasKey(invoiceId) {
            updatedInvoice.id = invoiceId;
            invoices[invoiceId] = updatedInvoice;
            return updatedInvoice;
        }
        return error("Invoice not found: " + invoiceId);
    }

    resource function post invoices/[string invoiceId]/send(Notification payload) returns LinkDescription|http:Response {
        invoiceStates[invoiceId] = "SENT";

        time:Utc currentTime = time:utcNow();
        string currentTimestamp = time:utcToString(currentTime);

        LinkDescription linkDescription = {
            href: "/invoices/" + invoiceId,
            rel: "send",
            method: "POST",
            "title": "Invoice Sent on " + currentTimestamp
        };
        return linkDescription;
    }

    resource function post invoices/[string invoiceId]/remind(Notification payload) returns http:NoContent|json {
        if invoiceStates[invoiceId] != "SENT" {
            return {
                "error": true,
                "message": "Invoice must be in SENT state to remind."
            };
        }
        return http:NO_CONTENT;
    }

    resource function post invoices/[string invoiceId]/payments(PaymentDetail payment) returns PaymentReference|error {
        if invoices.hasKey(invoiceId) {
            string paymentId = "PAY-MOCK-" + invoiceId;
            mapPayments[invoiceId] = paymentId;

            PaymentReference paymentRef = {
                "payment_id": paymentId,
                "status": "RECEIVED",
                "amount": payment.amount,
                "method": payment.method,
                "note": payment.note
            };
            return paymentRef;
        }
        return error("Invoice not found: " + invoiceId);
    }

    resource function delete invoices/[string invoiceId]/payments/[string paymentId]() returns http:NoContent|error {
        if !invoices.hasKey(invoiceId) {
            return error("Invoice not found: " + invoiceId);
        }

        string? storedPaymentId = mapPayments[invoiceId];
        if storedPaymentId is string && storedPaymentId == paymentId {
            _ = mapPayments.remove(invoiceId);
            return http:NO_CONTENT;
        }
        return error("Payment ID not found for this invoice");
    }

    resource function get invoices(int page, int page_size, boolean total_required) returns Invoices|http:Response {
        if page < 1 {
            json errorResponse = {
                "error": true,
                "message": "Invalid page number",
                "detail": {}
            };
            http:Response res = new;
            res.statusCode = 400;
            res.setPayload(errorResponse);
            return res;
        }

        Invoice[] allInvoices = invoices.entries().map(entry => entry[1]).toArray();
        int startIndex = (page - 1) * page_size;
        int endIndex = startIndex + page_size;

        if startIndex >= allInvoices.length() {
            return {
                "total_items": total_required ? allInvoices.length() : (),
                items: []
            };
        }

        Invoice[] pageItems = allInvoices.slice(startIndex, endIndex.min(allInvoices.length()));
        return {
            "total_items": total_required ? allInvoices.length() : (),
            "items": pageItems
        };
    }

    resource function post invoices/[string invoiceId]/cancel(Notification payload) returns http:NoContent|json {
        if invoices.hasKey(invoiceId) {
            invoiceStates[invoiceId] = "CANCELLED";
            return http:NO_CONTENT;
        }
    }

    resource function delete invoices/[string invoiceId]() returns http:NoContent|json {
        if invoices.hasKey(invoiceId) {
            _ = invoices.remove(invoiceId);
            _ = invoiceStates.remove(invoiceId);
            return http:NO_CONTENT;
        }
    }
}
