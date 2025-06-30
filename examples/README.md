# Examples

The `ballerinax/paypal.invoices` connector provides practical examples illustrating usage in various scenarios.

1. [Record Invoice Payment](paypal-record-invoice/) - Shows how to create an invoice, record a payment against it, and list recent invoices for account overview
2. [Send and Cancel Invoice](paypal-send-cancel-invoice/) - Illustrates creating an invoice, sending it to recipients, canceling it, and viewing invoice history 

## Prerequisites

Before running the examples, ensure you have:

1. **PayPal Developer Account** with:
   - Client ID and Client Secret from a PayPal REST API application
   - Access to PayPal Sandbox environment for testing
2. **Configuration Setup**:
   - Update the `Config.toml` file in each example directory with your PayPal credentials
   - Replace the placeholder values for `clientId` and `clientSecret`
   - For payment recording examples, also configure the `merchantEmail`

To obtain PayPal API credentials:
1. Visit [PayPal Developer Dashboard](https://developer.paypal.com/)
2. Create a new application or use an existing one
3. Copy the Client ID and Client Secret from your application settings

## Running an example

Execute the following commands to build an example from the source:

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building the examples with the local module

**Warning**: Due to the absence of support for reading local repositories for single Ballerina files, the Bala of the module is manually written to the central repository as a workaround. Consequently, the bash script may modify your local Ballerina repositories.

Execute the following commands to build all the examples against the changes you have made to the module locally:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
