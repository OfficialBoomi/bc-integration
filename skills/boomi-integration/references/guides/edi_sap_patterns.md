# EDI-SAP Integration Patterns

Generalizable patterns for integrations involving SAP IDocs and EDIFACT/X12. Use alongside `components/edi_profile_component.md`, `components/map_component.md`, and the trading partner's implementation guide / companion document for the target standard.

**Scope boundary:** Specific field-to-field mappings (e.g., which EDIFACT qualifier translates to which SAP code value) are message-type-specific and often installation-specific. This guide covers structural patterns and methodology only — for any given integration, obtain the client's mapping specification and build cross-reference tables from it.

## Contents

- IDoc Structure Basics
- EDI_DC40 Control Record
- IDoc Segment Hierarchy and Cardinality
- Z-Segment Extensions
- NAD Party Qualifier to SAP Partner Function
- Transformation Pattern: Qualifier-Driven Routing
- Transformation Pattern: Composite Decomposition
- Cross-Reference Table Design
- Validation Patterns

## IDoc Structure Basics

SAP IDocs (Intermediate Documents) are the data structure for SAP message exchange. Two formats in Boomi integrations:

| Format | Use When |
|--------|----------|
| IDoc XML | Modern SAP integrations, ALE/IDoc via SOAP/HTTP, Boomi for SAP |
| IDoc Flat File (positional) | Legacy interfaces, file-based IDoc extracts |

High-level structure:

```
IDoc
├── EDI_DC40 (Control Record) — mandatory metadata
├── E1xxx / E2xxx (Data Segments) — hierarchical segment groups
└── Status Records (outbound only)
```

### Segment Name Prefixes

| Prefix | Meaning |
|--------|---------|
| `E1` | Standard SAP segment, parent level |
| `E2` | Standard SAP segment, child level |
| `Z1`, `Z2` | Custom client-specific segment (installation-specific) |

## EDI_DC40 Control Record

Every IDoc begins with an EDI_DC40 control record. Key fields:

| Field | Purpose |
|-------|---------|
| `TABNAM` | Always `"EDI_DC40"` — the table name for the control record |
| `MANDT` | SAP client number (installation-specific, e.g. `100`, `140`) |
| `DOCNUM` | IDoc document number |
| `DOCREL` | SAP release version for IDoc (installation-specific, e.g. `700`, `731`) |
| `STATUS` | Processing status (e.g. `50`=IDoc added for outbound processing) |
| `DIRECT` | Direction (`1`=Outbound, `2`=Inbound) |
| `IDOCTYP` | Basic IDoc type (e.g. `ORDERS05`, `INVOIC02`) |
| `MESTYP` | SAP message type (e.g. `ORDERS`, `INVOIC`, `DESADV`) |
| `SNDPOR` / `RCVPOR` | Sender / receiver port |
| `SNDPRN` / `RCVPRN` | Sender / receiver partner number |
| `CREDAT` / `CRETIM` | Creation date (CCYYMMDD) / time (HHMMSS) |
| `REFINT` | External interchange reference (maps from UNB interchange control ref or ISA control number) |
| `STD` | EDI standard flag |

**MANDT and DOCREL are installation-specific** — do not hard-code in reusable Boomi maps. Treat as Dynamic Process Properties or extract from environment configuration.

## IDoc Segment Hierarchy and Cardinality

IDoc XML and flat-file exports describe segments with these attributes:

| Attribute | Meaning |
|-----------|---------|
| `LEVEL` | Nesting depth (`01`=header, `02`=item, `03`+=sub-item loops) |
| `STATUS` | `MANDATORY` or `OPTIONAL` |
| `LOOPMIN` | Minimum segment occurrences (`0`=optional, `1`+=mandatory) |
| `LOOPMAX` | Maximum segment occurrences (`1`=single, `9999`+=repeating) |
| `CHARACTER_FIRST` / `CHARACTER_LAST` | Field byte offsets (flat-file only) |

Mapping cardinality to Boomi EDI profile structure:

| LOOPMIN | LOOPMAX | Meaning | Boomi Profile Treatment |
|---------|---------|---------|-------------------------|
| 1 | 1 | Exactly one (mandatory single) | `mandatory="true"`, `maxUse="1"` |
| 0 | 1 | Zero or one (optional single) | `mandatory="false"`, `maxUse="1"` |
| 1 | 9999 | One or more (mandatory repeating) | Wrap in `EdiLoop` with `loopRepeat="-1"` |
| 0 | 9999 | Zero or more (optional repeating) | `EdiLoop` with `loopRepeat="-1"`, `mandatory="false"` |

## Z-Segment Extensions

Custom SAP installations add client-specific segments with a `Z` prefix. Integration guidance:

- Do not assume Z-segments exist on the target SAP system — they are installation-specific
- Use conditional mapping with defaults when sourcing from Z-segment fields that may not exist
- For inbound IDoc processing, Z-segment data may not be round-trippable to a different SAP system
- When designing a new interface, confirm which Z-segments are in scope with the SAP team before building profiles
- Document Z-segment assumptions in component descriptions so future maintainers understand the dependency

## NAD Party Qualifier to SAP Partner Function

The EDIFACT NAD qualifier (element 3035) maps to the SAP IDoc PARVW (Partner Function) field. The following mappings align with SAP standard partner functions in the SD module and are commonly applied:

| EDIFACT NAD | SAP PARVW | Role |
|-------------|-----------|------|
| `BY` | `AG` | Buyer (Sold-To — Auftraggeber) |
| `SE` | `LF` | Seller (Vendor — Lieferant) |
| `DP` | `WE` | Delivery party (Ship-To — Warenempfänger) |
| `IV` | `RE` | Invoicee (Bill-To — Rechnungsempfänger) |

**Other NAD qualifiers (FW, SU, AK, MA, UC, etc.) are often mapped differently per client configuration and per message type.** Do not assume a single universal mapping — confirm with the client's mapping specification.

## Transformation Pattern: Qualifier-Driven Routing

EDIFACT qualifier segments (DTM, NAD, RFF, MOA, QTY) carry different data meanings depending on their qualifier value. Do not map the whole segment to a single IDoc target — route by qualifier.

**Pattern:**
1. Use Boomi EDI profile instance identifiers (tagLists) on the qualifying loop so each qualifier value becomes a distinct named instance (see `components/edi_profile_component.md` tagLists section)
2. OR use Boomi Cross Reference Tables keyed on the qualifier value to look up target field names/values
3. OR use Route/Decision steps after profile parsing to send each qualifier variant to its own mapping branch

**Example segments requiring qualifier-driven routing:**

| EDIFACT Segment | Qualifier Element | IDoc Target Pattern |
|-----------------|-------------------|---------------------|
| DTM | DTM-C507-2005 (function qualifier) | Different date fields on IDoc (IDDAT on E1EDK03, etc.) — exact mappings are message-type-specific |
| NAD | NAD-3035 (party qualifier) | E1EDKA1 with PARVW value — see mapping table above for common cases |
| RFF | RFF-C506-1153 (reference qualifier) | E1EDK02/E1EDP02 with QUALF — mappings are message-type-specific |
| MOA | MOA-C516-5025 (amount qualifier) | E1EDS01 with SUMID — mappings are message-type-specific |
| QTY | QTY-C186-6063 (quantity qualifier) | E1EDP01 quantity fields — mappings are message-type-specific |

## Transformation Pattern: Composite Decomposition

EDIFACT composite elements pack multiple values into one element separated by component delimiters. IDoc fields are typically flat. Map the specific sub-element using `.N` notation — not the composite parent.

```
EDIFACT: BGM+220+PO12345+9
BGM01 = C002 composite
  BGM01.1 = "220"     ← Document name code (order)
  BGM01.2 = ""         ← Code list qualifier (unused)
  BGM01.3 = ""         ← Code list responsible agency
  BGM01.4 = ""         ← Document name
BGM02 = "PO12345"      ← Document/message number (simple element)
BGM03 = "9"            ← Message function (original)
```

Boomi profiles expose composite sub-elements as named child elements when configured with the `.N` notation. Mapping the composite parent to a single IDoc field concatenates all sub-components and loses structure.

**Same applies in reverse (IDoc → EDIFACT):** when building a composite EDIFACT element from multiple IDoc fields, set each sub-element individually.

## Cross-Reference Table Design

SAP-to-EDIFACT integrations nearly always require code translation. Build Boomi Cross Reference Tables (CRTs) for the following categories. See `components/cross_reference_table_component.md` for CRT component configuration.

**Common CRT categories:**

- Partner codes (EDIFACT NAD qualifier → SAP PARVW)
- Reference qualifiers (EDIFACT RFF qualifier → SAP EDK02/EDP02 QUALF)
- Monetary amount qualifiers (EDIFACT MOA qualifier → SAP EDS01 SUMID)
- Quantity qualifiers (EDIFACT QTY qualifier → SAP quantity field selectors)
- Date/time qualifiers (EDIFACT DTM qualifier → SAP IDDAT code on E1EDK03)
- Unit of measure codes (EDIFACT UOM → SAP MEINS/VRKME)
- Country codes, currency codes (usually ISO, often pass-through)
- Action/function codes (EDIFACT BGM function → SAP action field)

**Design principles:**
- Build each category as a separate CRT component — clearer intent, isolates changes, scopes lookups narrowly
- Direction matters — EDIFACT→SAP and SAP→EDIFACT may be separate CRTs even for the same category
- Expected values are rarely universal — build CRTs per customer mapping specification, not from assumed standards

## Validation Patterns

### IDoc Cardinality Validation

After mapping to or from IDoc, validate segment counts match `LOOPMIN`/`LOOPMAX` before sending:

- Add a Data Process (Groovy) step after the Map to count required segments and raise an exception if LOOPMIN is violated
- Use Boomi map tests to verify cardinality during development
- For critical segments, add a Decision step checking for presence before the outbound connector

### EDIFACT Qualifier Validation

When using Boomi EDI profile instance identifiers (tagLists):

- tagLists completeness — include all standard qualifier values, not just ones seen in sample data (see `components/edi_profile_component.md` Schema Validation Rules)
- Route unknown qualifier values to an error path via Decision steps or Route step defaults

### Length Constraint Enforcement

EDIFACT segments have stricter length limits than IDoc fields. Before outbound EDIFACT generation, validate mapped values fit the target's constraints. Common limits:

| EDIFACT Element | Typical Max | Source IDoc Field Concern |
|-----------------|-------------|---------------------------|
| Document reference (BGM02) | 35 chars | Usually safe |
| Free text (FTX C108) | 5 × 70 chars | Split long strings across multiple FTX repetitions |
| Line item number (LIN01) | 6 digits | May require re-sequencing if IDoc uses longer |
| Party name (NAD C080) | 5 × 35 chars | May require splitting across sub-elements |
| Street address (NAD C059) | 4 × 35 chars | May require splitting |

**Options for length handling:**
- Truncation via map functions (`substring`) — acceptable for free-text fields
- Error via Exception step — appropriate for identifiers where truncation loses meaning
- Split across sub-elements for multi-line fields (FTX, NAD-C080, NAD-C059)
