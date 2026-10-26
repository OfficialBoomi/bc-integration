# SFTP Connector Operation Component

Component type: `connector-action`
SubType: `officialboomi-X3979C-sftpvx-prod`

## Contents
- Operation Types
- Directory Resolution
- Write
- Read
- List

## Operation Types

| Action | Step `actionType` | `customOperationType` | `operationType` | `objectTypeId` / `objectTypeName` | Request | Response | `trackResponse` |
|--------|-------------------|----------------------|-----------------|-----------------------------------|---------|----------|-----------------|
| Write | `Write` | `WRITE` | `CREATE` | `File` / `File` | binary | json | `false` |
| Read | `Read` | `READ` | `GET` | `file` / `File` | xml | binary | `true` |
| List (file content) | `List` | `List` | `QUERY` | `file` / `File` | xml | binary | `true` |
| List (metadata) | `List` | `List` | `QUERY` | `fileMetadata` / `File Metadata` | xml | json | `true` |

Casing differs between columns and rows; copy each value exactly. Delete and Listen actions are not covered.

The `GenericOperationConfig` blocks below sit inside the standard operation wrapper (`<Operation returnApplicationErrors=... trackResponse=...>` → `<Configuration>`), with `subType="officialboomi-X3979C-sftpvx-prod"` on the component.

## Directory Resolution

Three settings name the directory: the connection's `remoteDirectory`, the Remote Directory document property (`connector.officialboomi-X3979C-sftpvx-prod.remoteDirectory`; Write, Read, List), and the operation's `remoteDirectory` field (GUI: **Sub Directory**; Read, List).

- The connection value is used only when neither of the others is set. A non-blank Sub Directory or document property **replaces** it; it is never appended.
- A relative value resolves as `/{value}`, not against the connection directory. With the connection at `/data`, Sub Directory `inbound` reads `/inbound`. This also applies to Read's relative move `destination`.
- On Read, a non-blank Sub Directory takes precedence over the document property.

This contradicts the Boomi documentation, which says the Sub Directory is appended to the connection directory. Use absolute paths everywhere.

## Write

Requires the File Name document property on the input document (see `sftp_connector_step.md`).

```xml
<GenericOperationConfig customOperationType="WRITE" objectTypeId="File" objectTypeName="File"
    operationType="CREATE" requestProfileType="binary" responseProfileType="json">
  <field id="createDir" type="boolean" value="true"/>
  <field id="actionIfFileExists" type="string" value="ERROR"/>
  <field id="stagingDirectory" type="string" value=""/>
  <field id="tempExtension" type="string" value=""/>
  <field id="targetFileName" type="string" value=""/>
  <field id="tempFileName" type="string" value=""/>
  <cookie role="OUTPUT">
    <value>{"includeAllMetadata":true}</value>
  </cookie>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File">
          <FieldList>
            <ConnectorField filterable="true" name="fileName" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="remoteDirectory" selectable="true" selected="true" sortable="true"/>
            <ConnectorField filterable="true" name="timestamp" selectable="true" selected="true" sortable="true"/>
          </FieldList>
        </ConnectorObject>
      </Fields>
      <Inputs/>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

**The `<cookie role="OUTPUT">` is required.** Without it the file is uploaded, then the document fails (`the cookie containing the browsing metadata for Create is not set...`). The failure ignores `returnApplicationErrors`, ends the execution in ERROR, and leaves the file on the server. The editor gives no warning.

A GUI import also sets `responseProfile="{json-profile-id}"`; it is not needed, so no JSON profile has to be created.

`createDir="true"` creates every missing level of the target path.

| `actionIfFileExists` | GUI label | When the file exists |
|----------------------|-----------|----------------------|
| `ERROR` | Generate error | Document fails |
| `OVERWRITE` | Overwrite | Replaces the file |
| `FORCE_UNIQUE_NAMES` | Create unique name | Writes `report1.txt` for `report.txt`, etc. |
| `APPEND` | Append | Needs server support for appends; otherwise fails with `operation unsupported: 8` |

The response body's `fileName` / `remoteDirectory` are the name and resolved directory actually written.

## Read

Downloads the file named by the step's `ID` parameter.

```xml
<GenericOperationConfig customOperationType="READ" objectTypeId="file" objectTypeName="File"
    operationType="GET" requestProfileType="xml" responseProfileType="binary">
  <field id="actionAfterRead" type="string" value="none"/>
  <field id="destination" type="string" value=""/>
  <field id="newFileName" type="string" value=""/>
  <field id="remoteDirectory" type="string" value=""/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File">
          <FieldList/>
        </ConnectorObject>
      </Fields>
      <Inputs>
        <Input key="0" name="ID"/>
      </Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

- `actionAfterRead`: `none`, `move` (to `destination`), `rename` (to `newFileName`, same directory), `delete`. **SAFETY**: use anything but `none` only when the user asked for it; `delete` is irreversible.
- **A missing file produces zero documents and no error**, even with `returnApplicationErrors="true"` — the path silently stops.

## List

File object: one document per file, body = file content. File Metadata object: one JSON document per entry, directories included.

```xml
<GenericOperationConfig customOperationType="List" objectTypeId="file" objectTypeName="File"
    operationType="QUERY" requestProfileType="xml" responseProfileType="binary">
  <field id="actionAfterRead" type="string" value="none"/>
  <field id="destination" type="string" value=""/>
  <field id="remoteDirectory" type="string" value=""/>
  <field id="recursiveList" type="boolean" value="false"/>
  <field id="maximumDepth" type="integer" value=""/>
  <field id="count" type="integer" value="-1"/>
  <field id="includeAllMetadata" type="boolean" value="false"/>
  <dynamicOperationField displayType="list" id="count" label="Maximum Number of Files to Return" overrideable="false" type="integer">
    <defaultValue>-1</defaultValue>
  </dynamicOperationField>
  <dynamicOperationField displayType="list" id="includeAllMetadata" label="Include all metadata" overrideable="false" type="boolean"/>
  <Options>
    <QueryOptions>
      <Fields>
        <ConnectorObject name="File">
          <FieldList>
            <ConnectorField filterable="true" name="fileName" selected="false" type="FilePath"/>
            <ConnectorField filterable="true" name="fileSize" selected="false" type="Comparable"/>
            <ConnectorField filterable="true" name="modifiedDate" selected="false" sortable="true" type="Comparable"/>
          </FieldList>
          <Filter>
            <ConnectorBaseFilter>
              <ConnectorFilterExpression expressionField="fileName" expressionOperator="WILDCARD"
                  key="0" name="fileName:WILDCARD" type="FilePath"/>
            </ConnectorBaseFilter>
          </Filter>
          <Sorts/>
        </ConnectorObject>
      </Fields>
      <Inputs>
        <Input key="0" name="fileName:WILDCARD"/>
      </Inputs>
    </QueryOptions>
  </Options>
</GenericOperationConfig>
```

**File Metadata** differs only in: `objectTypeId="fileMetadata"`, `objectTypeName="File Metadata"`, `responseProfileType="json"`, `<ConnectorObject name="File Metadata">`, and an extra `<ConnectorField filterable="true" name="isDirectory" selected="false" type="Boolean"/>`.

**No filter**: `<ConnectorBaseFilter/>` and `<Inputs/>`.

**Recursion**: with `recursiveList="true"`, empty `maximumDepth` lists one level below the directory; `maximumDepth="N"` lists N levels (no cap at 5).

**Post actions**: keep `actionAfterRead="none"`; other List post actions are not covered.

### Filters

Operator values include `WILDCARD`, `EQUALS`, `GREATER_THAN`. One expression sits directly in `ConnectorBaseFilter`; multiple are grouped with nestable `ConnectorFilterLogical`:

```xml
<ConnectorBaseFilter>
  <ConnectorFilterLogical logicalOperator="and">
    <ConnectorFilterExpression expressionField="fileName" expressionOperator="WILDCARD" key="0" name="fileName:WILDCARD" type="FilePath"/>
    <ConnectorFilterLogical logicalOperator="or">
      <ConnectorFilterExpression expressionField="fileSize" expressionOperator="GREATER_THAN" key="1" name="fileSize:GREATER_THAN" type="Comparable"/>
      <ConnectorFilterExpression expressionField="fileName" expressionOperator="EQUALS" key="2" name="fileName:EQUALS" type="FilePath"/>
    </ConnectorFilterLogical>
  </ConnectorFilterLogical>
</ConnectorBaseFilter>
```

Each expression needs a matching `<Input key="{key}" name="{name}"/>`.

### Sorting

```xml
<Sorts>
  <ConnectorSortField fieldName="modifiedDate" sortOrder="DESC"/>
</Sorts>
```

`DESC` = newest first, `ASC` = oldest first. `modifiedDate` is the only sortable field.
