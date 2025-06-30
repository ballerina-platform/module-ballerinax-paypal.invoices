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

    paypal:Notification sendPayload = {
        subject: "Your invoice from Dharshan Web Services",
        note: "Thank you for your continued business!",
        send_to_recipient: true
    };

    string invoiceId = createdInvoice.id ?: "";
    if invoiceId != "" {
        _ = check paypal->/invoices/[invoiceId]/send.post(sendPayload);
        io:println("Invoice sent successfully.");
    } else {
        return error("Invoice ID is null or empty.");
    }

    paypal:Notification cancelPayload = {
        subject: "Invoice Cancelled",
        note: "This invoice was cancelled due to a change in agreement.",
        send_to_recipient: true
    };

    if invoiceId != "" {
        _ = check paypal->/invoices/[invoiceId]/cancel.post(cancelPayload);
        io:println("Invoice cancelled successfully.");
    } else {
        return error("Invoice ID is null or empty.");
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
