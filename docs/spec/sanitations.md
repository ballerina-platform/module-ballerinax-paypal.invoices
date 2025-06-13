_Author_:  @DharshanSR \
_Created_: 13/06/2025 \
_Updated_: 13/06/2025 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Paypal Invoices. 
The OpenAPI specification is obtained from (https://github.com/paypal/paypal-rest-api-specifications/blob/main/openapi/invoicing_v2.json).

These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

**Manual sanitization**  
    After flattening and aligning, manually sanitize the OpenAPI definition to follow Ballerina's naming conventions.

1. Renamed `Schema'400` to `BadRequestError` to comply with OpenAPI naming conventions.
2. Renamed `Schema'403` to `ForbiddenError` to comply with OpenAPI naming conventions.
3. Renamed `Schema'422` to `ValidationError` to comply with OpenAPI naming conventions.

## OpenAPI cli command

The following command was used to generate the Ballerina client from the OpenAPI specification. The command should be executed from the repository root directory.

```bash
# TODO: Add OpenAPI CLI command used to generate the client
```
Note: The license year is hardcoded to 2025, change if necessary.
