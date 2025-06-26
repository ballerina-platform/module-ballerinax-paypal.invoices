_Author_:  @DharshanSR \
_Created_: 13/06/2025 \
_Updated_: 26/06/2025 \
_Edition_: Swan Lake

# Sanitation for OpenAPI specification
This document outlines the manual sanitizations applied to the PayPal Invoicing v2 OpenAPI specification. The official specification is initially retrieved from [PayPal’s official GitHub repository](https://github.com/paypal/paypal-rest-api-specifications/blob/main/openapi/invoicing_v2.json). After being flattened and aligned by the Ballerina OpenAPI tool, these manual modifications are implemented to improve the developer experience and to circumvent certain language and tool limitations.

## 1. Update OAuth2 token URL to relative URL.

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

```diff
- "tokenUrl": "/v1/oauth2/token"
+ "tokenUrl": "https://api-m.sandbox.paypal.com/v1/oauth2/toke
```

## 2. Fix invalid generated schema names with Apostrophe

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

```diff
- "Schema'400"
+ "BadRequest"

- "Schema'403"
+ "ForbiddenError"

- "Schema'422"
+ "UnprocessableEntity"
````
**Reason**: Apostrophes in schema names generate invalid JSON Schema; plain identifiers prevent generator errors.

**Reason**: JSON keys with apostrophes (e.g., `Schema'404`) are invalid and break schema parsing; using plain, descriptive identifiers (e.g., `NotFound`) ensures valid JSON Schema and prevents generator errors. See GitHub issue [#8011](https://github.com/ballerina-platform/ballerina-library/issues/8011) for details.

## 3. Avoid property name sanitisation to avoid data-binding error which is caused by a language limitation

Changed `x-ballerina-name` extension property to `x-ballerina-name-ignore` to exclude specific properties from Ballerina code generation when they conflict with reserved keywords or naming conventions.

```diff
- "x-ballerina-name": "..."
+ "x-ballerina-name-ignore": "..."
```

>**Reason**: Due to issue [#38535](https://github.com/ballerina-platform/ballerina-lang/issues/38535); the data binding fails for the fields which have json data name annotations. above chagne will avoid adding this annotations to the fields.


## 4. Add Header Parameters for Content-Type and Prefer

**A. Update components.parameters**

**Original**

```json
"parameters": {
  // (no content-type or prefer headers defined)
}

```

**Sanitized**

```json
"parameters": {
  "content-type": {
    "in": "header",
    "name": "Content-Type",
    "required": true,
    "schema": {
      "type": "string",
      "enum": ["application/json"],
      "default": "application/json"
    },
    "description": "The content type should be set to `application/json`."
  },
  "prefer": {
    "in": "header",
    "name": "Prefer",
    "required": false,
    "schema": {
      "type": "string",
      "default": "return=representation"
    },
    "description": "Specifies the preferred response format."
  }
}
```

```diff
+ "content-type": {
+   "in": "header",
+   "name": "Content-Type",
+   "required": true,
+   "schema": {
+     "type": "string",
+     "enum": ["application/json"],
+     "default": "application/json"
+   },
+   "description": "The content type should be set to `application/json`."
+ },
+ "prefer": {
+   "in": "header",
+   "name": "Prefer",
+   "required": false,
+   "schema": {
+     "type": "string",
+     "default": "return=representation"
+   },
+   "description": "Specifies the preferred response format."
+ }
```

**B. Patch Affected Paths**

**Location**: `paths.invoice.post`

**Original**:

```json
"paths": {
  "/invoice": {
    "post": {
      ....
    }
  }
}
```

**Sanitized**:

```json
"paths": {
  "/invoice": {
    "post": {
      "parameters": [
        {
          "$ref": "#/components/parameters/prefer"
        }
      ],
    }
  }
}
```

```diff
"paths": {
  "/invoice": {
    "post": {
-      {...}
+      "parameters": [
+        {
+         "$ref": "#/components/parameters/prefer"
+       }
+     ],
    }
  }
}
```
**POST /generate-next-invoice-number**

**Location**: `paths.generate-next-invoice-number.post`

**Original**:

```json
"paths": {
  "/generate-next-invoice-number": {
    "post": {
      ....
    }
  }
}
```

**Sanitized**:

```json
"paths": {
  "/generate-next-invoice-number": {
    "post": {
      "parameters": [
        {
          "$ref": "#/components/parameters/content-type"
        }
      ],
    }
  }
}
```

```diff
"paths": {
  "/generate-next-invoice-number": {
    "post": {
-      {...}
+      "parameters": [
+        {
+         "$ref": "#/components/parameters/content-type"
+       }
+     ],
    }
  }
}
```
### Why `Prefer` and `Content-Type` Were Added

The PayPal Invoicing API requires certain headers that were missing in the original OpenAPI spec:

- **`Content-Type: application/json`**  
  Required for all `POST` requests — even if the payload is empty.  
  Without it, PayPal returns **HTTP 415 Unsupported Media Type**.

- **`Prefer: return=representation`**  
  Ensures PayPal returns the **full response body**.  
  Without it, Ballerina may receive an incomplete or empty response, causing **`PayloadBindingError`** during deserialization.

These headers were added under `components.parameters` and injected into relevant paths to ensure proper request handling and successful response binding.

## OpenAPI CLI command

The following command was used to generate the Ballerina client from the OpenAPI specification. The command should be executed from the repository root directory.

```bash
bal openapi -i docs/spec/openapi.json --mode client --license docs/license.txt -o ballerina
```
Note: The license year is hardcoded to 2025, change if necessary.
