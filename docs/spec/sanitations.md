_Author_:  @DharshanSR \
_Created_: 13/06/2025 \
_Updated_: 25/06/2025 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification

This document records the sanitation done on top of the official OpenAPI specification from Paypal Invoices. 
The OpenAPI specification is obtained from (``https://github.com/paypal/paypal-rest-api-specifications/blob/main/openapi/invoicing_v2.json``).

These changes are done in order to improve the overall usability, and as workarounds for some known language limitations.

**Manual sanitization**  
After flattening and aligning the OpenAPI definition, manually sanitized the openapi.

## 1. Update `tokenUrl` to absolute URL

**Location**: `components.securitySchemes.Oauth2.flows.clientCredentials`

**Original**:

```json
"clientCredentials": {
  "tokenUrl": "/v1/oauth2/token",
  "scopes": {
    ...
  }
}
```

**Sanitized**:

```json
"clientCredentials": {
  "tokenUrl": "https://api-m.sandbox.paypal.com/v1/oauth2/token",
  "scopes": {
    ...
  }
}
```

## 2. Rename error response schemas for better readability

**Location**: `components.schemas`

Schema names were updated to use more descriptive and consistent naming conventions for HTTP error responses.

**Original**:

```json
"Schema'400": {
  "type": "object",
  ...
},
"Schema'403": {
  "type": "object", 
  ...
},
"Schema'422": {
  "type": "object",
  ...
}
```

**Sanitized**:

```json
"BadRequest": {
  "type": "object",
  ...
},
"ForbiddenError": {
  "type": "object",
  ...
},
"UnprocessableEntity": {
  "type": "object",
  ...
}
```

## 3. Update Ballerina extension property

Changed `x-ballerina-name` extension property to `x-ballerina-name-ignore` to exclude specific properties from Ballerina code generation when they conflict with reserved keywords or naming conventions.

Note: The license year is hardcoded to 2025, change if necessary.
