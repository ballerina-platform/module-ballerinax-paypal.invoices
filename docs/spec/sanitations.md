_Author_:  @DharshanSR \
_Created_: 13/06/2025 \
_Updated_: 19/06/2025 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Paypal Invoices. 
The OpenAPI specification is obtained from (https://github.com/paypal/paypal-rest-api-specifications/blob/main/openapi/invoicing_v2.json).

These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

**Manual sanitization**  
    After flattening the OpenAPI definition, manually sanitized the openapi.json file by removing redundant /v2/invoicing prefixes from endpoint paths. This improves compatibility with mock server routing and keeps paths consistent with the configured base URL.

**Sanitization Note:**
1. Changed the path from "/v2/invoicing/invoices" to "/invoices" at line 33 in the openapi.json file to support the mock server environment.
2. Updated the path from "/v2/invoicing/invoices/{invoice_id}/send" to "/invoices/{invoice_id}/send" at line 198 in the openapi.json file.
3. Changed the path from "/v2/invoicing/invoices/{invoice_id}/remind" to "/invoices/{invoice_id}/remind" at line 322 in the openapi.json file.
4. Updated the path from "/v2/invoicing/invoices/{invoice_id}/cancel" to "/invoices/{invoice_id}/cancel" at line 419 in the openapi.json file.
5. Changed the path from "/v2/invoicing/invoices/{invoice_id}/payments" to "/invoices/{invoice_id}/payments" at line 497 in the openapi.json file.
6. Updated the path from "/v2/invoicing/invoices/{invoice_id}/payments/{transaction_id}" to "/invoices/{invoice_id}/payments/{transaction_id}" at line 607 in the openapi.json file.
7. Changed the path from "/v2/invoicing/invoices/{invoice_id}/refunds" to "/invoices/{invoice_id}/refunds" at line 661 in the openapi.json file.
8. Updated the path from "/v2/invoicing/invoices/{invoice_id}/refunds/{transaction_id}" to "/invoices/{invoice_id}/refunds/{transaction_id}" at line 771 in the openapi.json file.
9. Changed the path from "/v2/invoicing/invoices/{invoice_id}/generate-qr-code" to "/invoices/{invoice_id}/generate-qr-code" at line 825 in the openapi.json file.
10. Updated the path from "/v2/invoicing/generate-next-invoice-number" to "/generate-next-invoice-number" at line 892 in the openapi.json file.
11. Changed the path from "/v2/invoicing/invoices/{invoice_id}" to "/invoices/{invoice_id}" at line 928 in the openapi.json file.
12. Updated the path from "/v2/invoicing/search-invoices" to "/search-invoices" at line 1154 in the openapi.json file
13. Changed the path from "/v2/invoicing/templates" to "/templates" at line 1237 in the openapi.json file.
14. Updated the path from "/v2/invoicing/templates/{template_id}" to "/templates/{template_id}" at line 1374 in the openapi.json file.

Reason:
In the mock server, the full base path (/v2/invoicing) is not included in the servers.url. Therefore, this change ensures that mock endpoints match the expected routing. Note that this change is specific to the mock server setup and not intended for live server use.

## OpenAPI cli command

The following command was used to generate the Ballerina client from the OpenAPI specification. The command should be executed from the repository root directory.

```bash
# TODO: Add OpenAPI CLI command used to generate the client
```
Note: The license year is hardcoded to 2025, change if necessary.
