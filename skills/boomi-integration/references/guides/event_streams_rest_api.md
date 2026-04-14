# Event Streams REST Produce API

REST API reference for producing messages to Event Streams topics without a Boomi process. Prefer the `rest-produce` CLI command which handles auth internally. Consult this reference for direct REST integration or edge cases the CLI doesn't cover. 

## Authentication

All requests require a Bearer token — the ES environment token value (`data` field from token query or `create-token`).

```
Authorization: Bearer <environment_token_data_value>
```

## Single Message Endpoint

**URL Pattern:**
```
https://{region}-web.eventstreams.boomi.com/rest/singlemsg/{account_identifier}/{environment_id}/{topic_name}
```

**Method:** POST

**Content-Type:** Must match the message body (e.g., `application/json`, `text/xml`)

**Body:** Raw message content.

**Message Properties:** Set via request headers with prefix `x-msg-props-`:
```
x-msg-props-samplePropKey1: value1
x-msg-props-orderType: purchase
```

**Success Response:**
```json
{"status": "success", "messageIds": "744:7:0"}
```

## Batch Message Endpoint

**URL Pattern:**
```
https://{region}-web.eventstreams.boomi.com/rest/{account_identifier}/{environment_id}/{topic_name}
```

**Method:** POST

**Content-Type:** `application/json`

**Payload:**
```json
{
    "messages": [
        {
            "payload": "SampleTestPayload1",
            "properties": {
                "key1": "Value1",
                "key2": "Value2"
            }
        },
        {
            "payload": "SampleTestPayload2",
            "properties": {}
        }
    ]
}
```

**Success Response:**
```json
{"status": "success", "messageIds": "744:7:0,744:8:0,744:9:0"}
```

## Retrieving URLs

Topic REST URLs are queryable via GraphQL — the `query-topic` CLI command returns them. The fields are `restProduceUrl` (batch) and `restProduceSingleMsgUrl` (single message) on the `EventStreamsTopic` type.

## Limits

| Constraint | Value |
|-----------|-------|
| Max message size (REST) | 5 MB |
| Max message size (Connector) | 1 MB |
| Max HTTP request size | 10 MB |
| Rate limit | 60,000 requests per IP per 5-minute window |
