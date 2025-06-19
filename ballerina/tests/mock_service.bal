// ----------------------------------------------------------------------------------
// Mock Server for PayPal Invoice Connector

// POST /v2/invoicing/generate-next-invoice-number
// POST /v2/invoicing/invoices
// GET /v2/invoicing/invoices
// GET /v2/invoicing/invoices/{invoiceId}
// POST /invoices/{invoiceId}/send
// POST /invoices/{invoiceId}/remind
// POST /invoices/{invoiceId}/cancel
// POST /invoices/{invoiceId}/payments
// DELETE /invoices/{invoiceId}/payments/{paymentId}

// This is used for connector testing without hitting the actual PayPal sandbox/live servers.
// ----------------------------------------------------------------------------------

import ballerina/http;
import ballerina/io;

listener http:Listener mockListener = new (9090);

// In-memory store
map<json> invoiceStore = {};
map<json> paymentStore = {};

service / on mockListener {

    // POST /v2/invoicing/generate-next-invoice-number
    resource function post v2/invoicing/generate\-next\-invoice\-number() returns json {
        return {"invoice_number": "INV-MOCK-001"};
    }

    // POST /v2/invoicing/invoices
    resource function post v2/invoicing/invoices(http:Caller caller, http:Request req) returns error? {
        json payload = check req.getJsonPayload();
        http:Response response = new;
        response.statusCode = http:STATUS_CREATED;
        response.setJsonPayload(payload);
        check caller->respond(response);
    }

    // GET /v2/invoicing/invoices (list)
    resource function get v2/invoicing/invoices(
            @http:Query int page = 1,
            @http:Query int page_size = 20,
            @http:Query string fields = "all",
            @http:Query boolean total_required = false
    ) returns json|error {
        if page < 1 {
            return {
                "timestamp": "2025-06-19T14:59:56Z",
                "status": 400,
                "reason": "Bad Request",
                "message": "Invalid page number"
            };
        }

        return {
            "total_count": 2,
            "items": [
                {
                    "id": "INV-MOCK-001",
                    "status": "DRAFT",
                    "detail": {
                        "invoice_number": "INV-MOCK-001",
                        "currency_code": "USD",
                        "note": "Mock Invoice 1"
                    }
                },
                {
                    "id": "INV-MOCK-002",
                    "status": "SENT",
                    "detail": {
                        "invoice_number": "INV-MOCK-002",
                        "currency_code": "USD",
                        "note": "Mock Invoice 2"
                    }
                }
            ]
        };
    }

    // ✅ GET /v2/invoicing/invoices/{invoiceId} — used by testShowInvoiceDetails
    resource function get v2/invoicing/invoices/[string invoiceId](http:Caller caller, http:Request req) returns error? {
        json responsePayload = {
            id: invoiceId,
            status: invoiceId == "INV-MOCK-001" ? "DRAFT" : "SENT",
            detail: {
                invoice_number: invoiceId,
                reference: "Ref-Mock",
                currency_code: "USD",
                note: "This is a mock invoice."
            },
            amount: {
                currency_code: "USD",
                value: "100.00"
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
            ]
        };

        http:Response res = new;
        res.statusCode = http:STATUS_OK;
        res.setJsonPayload(responsePayload);
        check caller->respond(res);
    }

    // POST /invoices/{invoiceId}/send
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

    // POST /invoices/{invoiceId}/remind
    resource function post invoices/[string invoiceId]/remind(http:Caller caller, http:Request req) returns error? {
        json|error payload = req.getJsonPayload();
        if payload is json {
            io:println("📩 Reminder payload for invoice ID: ", invoiceId);
            io:println(payload.toJsonString());

            json responseBody = {
                "id": invoiceId,
                "status": "SENT",
                "detail": {
                    "message": "Invoice reminder sent successfully"
                }
            };

            http:Response response = new;
            response.statusCode = http:STATUS_OK;
            response.setJsonPayload(responseBody);
            check caller->respond(response);
        } else {
            http:Response errorResponse = new;
            errorResponse.statusCode = http:STATUS_BAD_REQUEST;
            errorResponse.setJsonPayload({message: "Invalid JSON payload"});
            check caller->respond(errorResponse);
        }
    }

    // POST /invoices/{invoiceId}/cancel
    resource function post invoices/[string invoiceId]/cancel(http:Caller caller, http:Request req) returns error? {
        json|error payload = req.getJsonPayload();
        if payload is json {
            io:println("🚫 Cancel payload for invoice ID: ", invoiceId);
            io:println(payload.toJsonString());

            json responseBody = {
                "id": invoiceId,
                "status": "CANCELLED",
                "detail": {
                    "message": "Invoice cancelled successfully"
                }
            };

            http:Response res = new;
            res.statusCode = http:STATUS_OK;
            res.setJsonPayload(responseBody);
            check caller->respond(res);
        } else {
            http:Response errorResponse = new;
            errorResponse.statusCode = http:STATUS_BAD_REQUEST;
            errorResponse.setJsonPayload({message: "Invalid JSON payload"});
            check caller->respond(errorResponse);
        }
    }

    // DELETE /invoices/{invoiceId}/payments/{paymentId}
    resource function delete invoices/[string invoiceId]/payments/[string paymentId](http:Caller caller, http:Request req) returns error? {
        io:println("🗑️ Delete payment for invoice ID: ", invoiceId, ", payment ID: ", paymentId);

        string paymentKey = invoiceId + "-" + paymentId;
        if paymentStore.hasKey(paymentKey) {
            json _ = paymentStore.remove(paymentKey);
            http:Response res = new;
            res.statusCode = http:STATUS_NO_CONTENT;
            check caller->respond(res);
        } else {
            http:Response res = new;
            res.statusCode = http:STATUS_NOT_FOUND;
            res.setJsonPayload({message: "Payment not found"});
            check caller->respond(res);
        }
    }

    // POST /invoices/{invoiceId}/payments
    resource function post invoices/[string invoiceId]/payments(http:Caller caller, http:Request req) returns error? {
        json|error payload = req.getJsonPayload();
        if payload is json {
            io:println("💰 Record payment for invoice ID: ", invoiceId);
            io:println(payload.toJsonString());

            string newPaymentId = "PAY-MOCK-" + invoiceId + "-001";
            paymentStore[invoiceId + "-" + newPaymentId] = payload;

            json responseBody = {
                "payment_id": newPaymentId,
                "status": "RECORD_SUCCESS",
                "detail": {
                    "message": "Payment recorded successfully"
                }
            };

            http:Response res = new;
            res.statusCode = http:STATUS_CREATED;
            res.setJsonPayload(responseBody);
            check caller->respond(res);
        } else {
            http:Response errorResponse = new;
            errorResponse.statusCode = http:STATUS_BAD_REQUEST;
            errorResponse.setJsonPayload({message: "Invalid JSON payload"});
            check caller->respond(errorResponse);
        }
    }

    // POST /v2/invoicing/invoices/{invoiceId}/generate-qr-code
    // resource function post v2/invoicing/invoices/[string invoiceId]/generate\-qr\-code(http:Caller caller, http:Request req) returns error? {
    //     json|error payload = req.getJsonPayload();

    //     if payload is json {
    //         io:println("Mock server received QR code generate request for invoice ID: ", invoiceId);
    //         io:println(payload.toJsonString());

    //         // Simulate a PNG image encoded as base64 string or simply a placeholder string
    //         json responseBody = {
    //             "qr_code_png_base64": "iVBORw0KGgoAAAANSUhEUgAAASwAAAEsCAIAAAD2HXeMAAA..."
    //         };

    //         http:Response response = new;
    //         response.statusCode = http:STATUS_OK;
    //         response.setJsonPayload(responseBody);
    //         check caller->respond(response);
    //     } else {
    //         http:Response errorResponse = new;
    //         errorResponse.statusCode = http:STATUS_BAD_REQUEST;
    //         errorResponse.setJsonPayload({message: "Invalid JSON payload"});
    //         check caller->respond(errorResponse);
    //     }
    // }

}
