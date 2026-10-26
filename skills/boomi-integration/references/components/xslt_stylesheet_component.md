# XSLT Stylesheet Component

## Contents
- Purpose
- Component Structure
- Referencing the Component from a Data Process Step
- Security Settings
- Engine and Input
- Dynamic Document Properties

## Purpose
An XSLT Stylesheet component (`type="xslt"`) holds a complete XSLT stylesheet. It runs only through a Data Process step's XSLT Transformation operation (process type 16). It has no inline alternative, so the step always references a component.

## Component Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               componentId=""
               name="[XSLT_COMPONENT_NAME]"
               type="xslt"
               folderId="[FOLDER_ID]">
  <bns:object>
    <Xslt xmlns=""><stylesheet>&lt;xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"&gt;
  &lt;xsl:template match="@*|node()"&gt;
    &lt;xsl:copy&gt;&lt;xsl:apply-templates select="@*|node()"/&gt;&lt;/xsl:copy&gt;
  &lt;/xsl:template&gt;
&lt;/xsl:stylesheet&gt;</stylesheet></Xslt>
  </bns:object>
</bns:Component>
```

### Key structural facts
- Component `type="xslt"`. Body root element is `<Xslt xmlns="">`.
- The stylesheet is stored as **entity-escaped text** in `<stylesheet>` (`<` → `&lt;`). This is the form the platform returns on pull and a valid form to push.

## Referencing the Component from a Data Process Step

```xml
<step index="1" key="1" name="XSLT Transformation" processtype="16">
  <dataprocessxslt componentId="[XSLT_COMPONENT_GUID]" modelVersion="2" recommendedSecuritySettings="true">
    <stylesheet>[XSLT_COMPONENT_NAME]</stylesheet>
  </dataprocessxslt>
</step>
```

- Step `name="XSLT Transformation"`.
- **`componentId` alone selects the stylesheet.** `<stylesheet>` holds the component name for display only.
- **Always emit `modelVersion="2" recommendedSecuritySettings="true"`.** The platform saves the attributes exactly as pushed. Omitted attributes are not filled in, and an omitted `recommendedSecuritySettings` behaves as `false` (see Security Settings).
- A step without `componentId` saves and deploys, but fails when the process runs (`using XSLT stylesheet null`, `java.lang.NullPointerException`).
- **Redeploy referencing processes after editing the component.** A deployment captures the component version that is current at deploy time. Redeploying an unchanged process picks up the new component version.

## Security Settings
`recommendedSecuritySettings` controls how the input document's external resources are handled.

- `true`: external entities and external DTDs are not fetched. An external entity silently resolves to an empty string, with no error or warning, so a document that legitimately depends on one loses that content. DOCTYPEs are not rejected and internal entities still expand.
- `false` or omitted: the parser attempts the fetch. On a public cloud runtime the sandbox denies it, and the document fails with `access denied ("java.net.SocketPermission" "<host>:80" "connect,resolve")`.
- The setting applies only to parsing the input document. It does not cover `xsl:include` or `document()` in the stylesheet.

## Engine and Input
- The engine is Saxon EE (XSLT 3.0), so streaming (`<xsl:mode streamable="yes"/>`) is available.
- **Input must be XML.** Each document is XML-parsed before any template runs. JSON input fails with `org.xml.sax.SAXParseException; lineNumber: 1; columnNumber: 1; Content is not allowed in prolog.` This happens even with a stylesheet that uses only `xsl:initial-template`.
- Each document is transformed separately. N documents in produce N documents out, never combined or split.
- `xsl:include` can't reference another XSLT component, because a relative `href` resolves to a file path on the runtime. On a public cloud runtime, the sandbox denies HTTP references in `xsl:include` or `document()`.

## Dynamic Document Properties
Declare `xmlns:boomi="http://boomi.com/custom-function"` on `<xsl:stylesheet>` to enable two functions. Only dynamic document properties are reachable. To use another property type, copy its value into a DDP with a Set Properties step first.

```xml
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:boomi="http://boomi.com/custom-function">
  <xsl:template match="/">
    <out>
      <in><xsl:value-of select="boomi:get-ddp('DDP_IN')"/></in>
      <xsl:variable name="o" select="boomi:set-ddp('DDP_OUT', 'new value')"/>
      <xsl:value-of select="$o"/>
    </out>
  </xsl:template>
</xsl:stylesheet>
```

- `boomi:get-ddp('NAME')` returns the property's string value. An unset property returns an empty string, with no error.
- `boomi:set-ddp('NAME', 'value')` takes effect **only when its result is output with `xsl:value-of`**, as shown. If the variable is never referenced, the property is silently not set. The `xsl:value-of` writes nothing into the output.
- DDPs set before the step survive the transformation.
