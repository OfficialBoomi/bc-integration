# SFTP Connector Step

Connector steps for the SFTP connector (`connectorType="officialboomi-X3979C-sftpvx-prod"`). Operation XML is in `sftp_connector_operation_component.md`.

## Step Configuration

```xml
<connectoraction actionType="Read" allowDynamicCredentials="NONE"
    connectionId="{connection-component-id}"
    connectorType="officialboomi-X3979C-sftpvx-prod" hideSettings="false"
    operationId="{operation-component-id}"
    parameter-profile="EMBEDDED|genericparameterchooser|{operation-component-id}">
  <parameters>
    <parametervalue elementToSetId="0" elementToSetName="ID" name="ID" usesEncryption="false" valueType="static">
      <staticparameter staticproperty="orders.csv"/>
    </parametervalue>
  </parameters>
  <dynamicProperties/>
</connectoraction>
```

- `actionType` is `Write`, `Read`, or `List`.
- `parameter-profile` and parameters are present only when the operation has `Inputs`: Read (`ID` = file name) and filtered List. Write and unfiltered List steps omit `parameter-profile` and use `<parameters/>`.
- List filter parameters: one `parametervalue` per operation `Input`, with `elementToSetId` = the `Input key` and `elementToSetName` / `name` = the `Input name` (e.g. `fileName:WILDCARD`).

## Document Properties

Set in a Set Properties step before the connector step. Use absolute paths (see `sftp_connector_operation_component.md` § Directory Resolution).

| Property ID | Display name | Used by |
|-------------|--------------|---------|
| `connector.officialboomi-X3979C-sftpvx-prod.fileName` | `SFTP - File Name` | Write (required) |
| `connector.officialboomi-X3979C-sftpvx-prod.remoteDirectory` | `SFTP - Remote Directory` | Write, Read, List |

On Read and List output, both are populated per document. On Write output they are empty; the written name and directory are in the JSON body.

## List Input Document

A List step parses its incoming document's content as an XML query filter. Non-XML content (e.g. from a Message step) fails the whole process with `Could not unmarshall query filter`. Place the List after the Start shape (No Data), optionally with a Set Properties step between them.
