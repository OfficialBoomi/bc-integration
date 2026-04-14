# Stop Step

## Contents
- Purpose
- Configuration Structure
- Attributes
- XML Reference

## Purpose
Terminates document processing on the current path. This is a successful termination -- no error is generated (use Exception step for error exits).

**Use when:**
- Ending a processing path that should not return documents (e.g., unhappy-path exit after a Decision or Route)
- Terminating one branch while other branches continue processing
- Halting all remaining execution when a condition is met

## Configuration Structure
```xml
<shape image="stop_icon" name="[shapeName]" shapetype="stop" userlabel="[label]" x="[x]" y="[y]">
  <configuration>
    <stop continue="[true|false]"/>
  </configuration>
  <dragpoints/>
</shape>
```

Stop is a terminal shape -- `<dragpoints/>` is always empty.

## Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `continue` | boolean | **Yes** | `true`: ends processing on this path only; other execution paths continue normally ("End and continue"). `false`: ends the entire process; no further paths execute ("End and return"). |

**CRITICAL:** The `continue` attribute must always be present. Omitting it (bare `<stop/>`) causes both runtime failure (`NullPointerException` at `StopShape.init`) and GUI failure (JavaScript stack overflow). The platform API silently accepts and deploys bare `<stop/>` with no validation error -- the failure only surfaces at execution time. See `references/guides/boomi_error_reference.md` Issue #15.

## XML Reference

### End and Continue (other paths keep processing)
```xml
<shape image="stop_icon" name="shape3" shapetype="stop" userlabel="" x="400.0" y="80.0">
  <configuration>
    <stop continue="true"/>
  </configuration>
  <dragpoints/>
</shape>
```

### End and Return (entire process stops)
```xml
<shape image="stop_icon" name="shape4" shapetype="stop" userlabel="Halt Processing" x="416.0" y="160.0">
  <configuration>
    <stop continue="false"/>
  </configuration>
  <dragpoints/>
</shape>
```
