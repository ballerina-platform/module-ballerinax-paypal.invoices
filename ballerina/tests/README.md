# Test Suite for PayPal Invoicing Connector
This test suite ensures the reliability and correctness of the Ballerina connector for the PayPal Invoicing API. It includes both mock and live test environments to validate connector functionality across various scenarios.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Running Tests](#running-tests)
  - [Running Tests in the Mock Server](#running-tests-in-the-mock-server)
  - [Executing Tests Against the PayPal Sandbox Environment](#executing-tests-against-the-paypal-sandbox-environment)

## Prerequisites

You need valid **PayPal Sandbox API credentials** to run the live server tests. These include:

- `Client ID`
- `Client Secret`

To obtain these, refer to the [PayPal Developer Documentation](https://developer.paypal.com/tools/sandbox/).

> **Note:** Live server tests are optional. If you're only testing against the mock server, credentials are not required.

Additionally, some test cases (such as retrieving, updating, or deleting invoices) require a valid `invoice_id`, which is typically generated in earlier test cases. You will also need your **PayPal Sandbox Business Account Email** (`merchantEmail`). This is required to simulate the **merchant's identity** when sending invoices to customers.

Additionally, for some test cases (like retrieving or updating an invoice), you will need a valid `invoice_id`, which is typically created during earlier test runs.

## Running Tests

There are two test environments for running the PayPal Invoice connector tests. By default, tests are run against the **mock server**, which simulates PayPal's behavior. You can also run tests against the **actual PayPal Sandbox API** for real API integration testing.

 Test Group    | Environment                                  
|--------------|----------------------------------------------|
| `mock_test`  | Mock server simulating PayPal Invoice API    |
| `live_test`  | PayPal Sandbox (real API with credentials)   |

## Running Tests in the Mock Server

To execute the tests on the mock server, ensure that the `IS_LIVE_SERVER` environment variable is either set to `false` or unset before initiating the tests. This environment variable can be configured within the `Config.toml` file located in the tests directory or specified as an environmental variable.

#### Using a Config.toml File

Create a `Config.toml` file in the tests directory and the following content:

```toml
isLiveServer = false
```

### Using Environment Variables

#### Linux or macOS

```bash
export IS_LIVE_SERVER=false
```

#### Windows

```bash
setx IS_LIVE_SERVER false
```

## Executing Tests Against the PayPal Sandbox Environment

You can run the connector tests against the actual PayPal **Sandbox** API by configuring your credentials in a `Config.toml` file.

### Using a `Config.toml` File

Create a `Config.toml` file inside the `tests/` directory with the following content:

```toml
isLiveServer = true
clientId = "<YOUR_PAYPAL_SANDBOX_CLIENT_ID>"
clientSecert = "<YOUR_PAYPAL_SANDBOX_CLIENT_SECRET>"
merchantEmail = "<YOUR_PAYPAL_BUSINESS_EMAIL>"
```

> Make sure your credentials are from the PayPal Sandbox environment, not from the live/production PayPal account.

Then, run the following command to run the tests:

```bash
   ./gradlew clean test 
```

## Running Specific Groups or Test Cases

To run only certain test groups or individual test cases, pass the -Pgroups property:

```bash
./gradlew clean test -Pgroups=<comma-separated-groups-or-test-cases>
```

For example, to run only the mock tests:

```bash
./gradlew clean test -Pgroups=mock_tests
```
