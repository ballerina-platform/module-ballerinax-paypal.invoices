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

import ballerina/io;
import ballerina/time;
import ballerinax/paypal.invoices as paypal;

configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string merchantEmail = ?;

final paypal:Client paypal = check new paypal:Client({
    auth: {
        clientId,
        clientSecret
    }
});

public function main() returns error? {
    time:Utc currentTime = time:utcNow();
    int timestamp = currentTime[0];
    string uniqueInvoiceNumber = string `2025-INV-${timestamp}`;
    io:println("Generated unique invoice number: ", uniqueInvoiceNumber);

    paypal:Invoice invoicePayload = {
        detail: {
            currency_code: "USD",
            invoice_number: uniqueInvoiceNumber,
            note: "Website maintenance for June 2025",
            terms_and_conditions: "Net 10. Payable within 10 days.",
            "due_date": "2025-07-08"
        },
        invoicer: {
            name: {
                given_name: "Dharshan",
                surname: "Ravindran"
            },
            email_address: merchantEmail
        },
        primary_recipients: [
            {
                billing_info: {
                    name: {
                        given_name: "Brian",
                        surname: "Jackson"
                    },
                    email_address: "brian@techserve.io"
                }
            }
        ],
        items: [
            {
                name: "Website Maintenance",
                description: "Monthly updates, monitoring, and backups",
                quantity: "1",
                unit_amount: {
                    currency_code: "USD",
                    value: "300.00"
                }
            }
        ]
    };

    paypal:Invoice createdInvoice = check paypal->/invoices.post(invoicePayload);
    io:println("Created Invoice ID: ", createdInvoice.id);

    string invoiceId = createdInvoice.id ?: "";
    if invoiceId == "" {
        return error("Failed to get invoice ID from created invoice");
    }

    // Step 2: Send the invoice to make it payable
    paypal:Notification sendPayload = {
        additional_recipients: ["brian@techserve.io"],
        note: "Payment required within 10 days",
        send_to_invoicer: true,
        send_to_recipient: true,
        subject: "Invoice for Website Maintenance - June 2025"
    };

    paypal:LinkDescription|paypal:'202Response _ = check paypal->/invoices/[invoiceId]/send.post(sendPayload);
    io:println("Invoice sent successfully!");

    paypal:PaymentDetail paymentPayload = {
        method: "CHECK",
        'type: "EXTERNAL",
        amount: {
            currency_code: "USD",
            value: "300.00"
        },
        payment_date: "2025-06-29",
        note: "Check payment received from client"
    };

    paypal:PaymentReference paymentReference = check paypal->/invoices/[invoiceId]/payments.post(paymentPayload);
    io:println("Payment recorded successfully! Payment ID: ", paymentReference.payment_id);

    paypal:Invoice updatedInvoice = check paypal->/invoices/[invoiceId].get();
    io:println("Invoice Status: ", updatedInvoice.status);

    if updatedInvoice.payments is paypal:Payments {
        paypal:Payments? paymentsOpt = updatedInvoice.payments;
        if paymentsOpt is paypal:Payments {
            paypal:Money? paidAmountOpt = paymentsOpt.paid_amount;
            if paidAmountOpt is paypal:Money {
                io:println("Total Paid: $", paidAmountOpt.value);
            }
        }
    }

    paypal:Invoices invoiceList = check paypal->/invoices.get({
        page: "1",
        page_size: "5",
        total_required: "true"
    });

    io:println("\nRecent Invoices:");
    foreach var inv in invoiceList.items ?: [] {
        io:println("- ID: ", inv.id, " | Status: ", inv.status, " | Total: ", inv.amount?.value, " ", inv.amount?.currency_code);
    }
}
