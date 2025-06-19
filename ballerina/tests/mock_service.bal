// Creating invoices (POST /invoices)

// Retrieving invoices (GET /invoices, GET /invoices/{invoiceId})

// Sending invoices (POST /invoices/{invoiceId}/send)

// Cancelling invoices (POST /invoices/{invoiceId}/cancel)

// Recording payments (POST /invoices/{invoiceId}/payments)

// Deleting payments (DELETE /invoices/{invoiceId}/payments/{paymentId})

// Deleting invoices (DELETE /invoices/{invoiceId})

// Generating invoice number (POST /generate-next-invoice-number)

import ballerina/http;
import ballerina/io;
// import ballerina/log;
import ballerina/time;

listener http:Listener mockListener = new (9090);

// In-memory store for invoices
map<json> invoiceStore = {};

// In-memory store for payments
map<json[]> paymentStore = {};

service / on mockListener {

    // Create invoice
    resource function post invoices(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();
        io:println("Received POST /invoices request");
        io:println("Request payload: ", payload.toJsonString());

        map<json> payloadMap = <map<json>>payload;
        json detail = check payloadMap.detail ?: {};
        json invoicer = check payloadMap.invoicer ?: {};
        json primaryRecipients = check payloadMap["primary_recipients"] ?: [];
        json items = check payloadMap.items ?: [];

        json responseBody = {
            "id": "INV2-MOCK12345",
            "status": "DRAFT",
            "detail": detail,
            "invoicer": invoicer,
            "primary_recipients": primaryRecipients,
            "items": items
        };

        http:Response response = new;
        response.statusCode = http:STATUS_CREATED;
        response.setJsonPayload(responseBody);
        check caller->respond(response);
    }

    // List invoices
    resource function get invoices(http:Caller caller, http:Request req) returns error? {
        json invoicesList = {
            items: [
                {
                    id: "INV-MOCK-001",
                    status: "PAID",
                    detail: {
                        invoice_number: "1001",
                        invoice_date: "2025-06-15",
                        currency_code: "USD",
                        note: "Paid invoice"
                    }
                },
                {
                    id: "INV-MOCK-002",
                    status: "DRAFT",
                    detail: {
                        invoice_number: "1002",
                        invoice_date: "2025-06-18",
                        currency_code: "USD",
                        note: "Draft invoice"
                    }
                }
            ],
            total_items: 2,
            total_pages: 1,
            links: [
                {
                    href: "http://localhost:9090/invoices?page=1",
                    rel: "self",
                    method: "GET"
                }
            ]
        };

        http:Response res = new;
        res.statusCode = http:STATUS_OK;
        res.setJsonPayload(invoicesList);
        check caller->respond(res);
    }

    // Get invoice by ID
    resource function get invoices/[string invoiceId](http:Caller caller, http:Request req) returns error? {
        json invoice = {
            id: invoiceId,
            status: "DRAFT",
            detail: {
                reference: "PO-123456",
                currency_code: "USD",
                note: "Thanks for your business!",
                memo: "Test invoice memo",
                invoice_number: invoiceId,
                invoice_date: "2025-06-17",
                term: "Net 30",
                paymentTerm: {
                    termType: "NET_30"
                }
            },
            invoicer: {
                name: {
                    given_name: "Dharshan",
                    surname: "Doe"
                },
                email_address: "sb-bxzgi43697870@business.example.com"
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
                        value: "25.00",
                        currency_code: "USD"
                    }
                }
            ]
        };

        http:Response res = new;
        res.statusCode = http:STATUS_OK;
        res.setJsonPayload(invoice);
        check caller->respond(res);
    }

    // Send invoice
    resource function post invoices/[string invoiceId]/send(http:Caller caller, http:Request req) returns error? {
        json|error payload = req.getJsonPayload();
        if payload is json {
            json responseBody = {
                "id": invoiceId,
                "status": "SENT",
                "detail": {
                    "message": "Invoice sent successfully"
                }
            };

            http:Response response = new;
            response.statusCode = http:STATUS_ACCEPTED;
            response.setJsonPayload(responseBody);
            check caller->respond(response);
        } else {
            http:Response errorResponse = new;
            errorResponse.statusCode = http:STATUS_BAD_REQUEST;
            errorResponse.setJsonPayload({message: "Invalid JSON payload"});
            check caller->respond(errorResponse);
        }
    }

    // Cancel invoice
    resource function post invoices/[string invoiceId]/cancel(http:Caller caller, http:Request req) returns error? {
        json|error payload = req.getJsonPayload();
        if payload is json {
            invoiceStore[invoiceId] = {id: invoiceId, status: "CANCELLED"};

            http:Response response = new;
            response.statusCode = http:STATUS_NO_CONTENT;
            check caller->respond(response);
        } else {
            http:Response badRequest = new;
            badRequest.statusCode = http:STATUS_BAD_REQUEST;
            badRequest.setJsonPayload({message: "Invalid JSON payload"});
            check caller->respond(badRequest);
        }
    }

    // Record payment
    resource function post invoices/[string invoiceId]/payments(http:Caller caller, http:Request req) returns error? {
        json|error payload = req.getJsonPayload();
        if payload is json {
            json[] payments = paymentStore[invoiceId] ?: [];
            string paymentId = "pay_" + time:utcNow()[0].toString();

            json newPayment = payload.clone();
            map<json> newPaymentMap = <map<json>>newPayment;
            newPaymentMap["paymentId"] = paymentId;
            payments.push(newPaymentMap);
            paymentStore[invoiceId] = payments;

            json paymentReference = {paymentId: paymentId};

            http:Response response = new;
            response.statusCode = http:STATUS_CREATED;
            response.setJsonPayload(paymentReference);
            check caller->respond(response);
        } else {
            http:Response badRequest = new;
            badRequest.statusCode = http:STATUS_BAD_REQUEST;
            badRequest.setJsonPayload({message: "Invalid JSON payload"});
            check caller->respond(badRequest);
        }
    }

    // Delete payment
    resource function delete invoices/[string invoiceId]/payments/[string paymentId](http:Caller caller, http:Request req) returns error? {
        json[]? payments = paymentStore.get(invoiceId);
        if payments is json[] {
            int index = -1;
            foreach int i in 0 ..< payments.length() {
                map<json> payment = <map<json>>payments[i];
                if payment["paymentId"].toString() == paymentId {
                    index = i;
                    break;
                }
            }
            if index >= 0 {
                json _ = payments.remove(index);
                paymentStore[invoiceId] = payments;
                http:Response noContent = new;
                noContent.statusCode = http:STATUS_NO_CONTENT;
                check caller->respond(noContent);
            } else {
                http:Response notFound = new;
                notFound.statusCode = http:STATUS_NOT_FOUND;
                notFound.setJsonPayload({message: "Payment not found"});
                check caller->respond(notFound);
            }
        } else {
            http:Response notFound = new;
            notFound.statusCode = http:STATUS_NOT_FOUND;
            notFound.setJsonPayload({message: "Invoice not found"});
            check caller->respond(notFound);
        }
    }

    // Delete invoice
    resource function delete invoices/[string invoiceId](http:Request req) returns http:Response|error {
        http:Response res = new;
        res.statusCode = http:STATUS_NO_CONTENT;
        return res;
    }

    // Generate next invoice number
    resource function post generate\-next\-invoice\-number() returns json {
        return { "invoice_number": "INV-MOCK-001" };
    }
}
