# Connection Registry

List your Boomi connections here so the agent can find and re-use them.

Format is free-form — describe each connection and include whatever helps the agent identify and select it: a platform link, component IDs, operations, endpoints, or notes about when to use it. The agent reads this file and matches entries by context to the connectors it needs.

## Example formats

### Salesforce connection - production org
https://platform.boomi.com/AtomSphere.html#build;accountId=YOUR_ACCOUNT_ID;components=CONNECTION_COMPONENT_ID

### RevOps API
Use this when posting billing events from internal pipelines.
REST Client Connection (sender): CONNECTION_COMPONENT_ID
API Service component (listener): API_SERVICE_COMPONENT_ID
charge-event endpoint: /ws/rest/revops/charge-event
refund-event endpoint: /ws/rest/revops/refund-event

### PostgreSQL - customer orders database
Connection: CONNECTION_COMPONENT_ID
get-orders operation: OPERATION_COMPONENT_ID
submit-order operation: OPERATION_COMPONENT_ID
