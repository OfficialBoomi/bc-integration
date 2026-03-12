# Changelog

All notable changes are documented here.

## 0.5.7

- Add Trading Partner component reference (`trading_partner_component.md`) — classification, X12 partner info, AS2 configuration, DocumentTypes, tracked fields, API enforcement summary from runtime-validated experiments
- Add Trading Partner steps reference (`trading_partner_steps.md`) — TP Start/Send shapes, output paths with all 4 validated configurations, path execution order, inbound validation and error routing by standard, populated TradingPartners/MyCompanies structure
- Add Dragpoints and Output Path Wiring section to BOOMI_THINKING.md — `<dragpoints>` required on every shape, `toShape="unset"` convention, partial wiring support (all runtime-validated)
- Add Document Tracking section to BOOMI_THINKING.md — account-level custom tracked fields, CustomTrackedField API
- Add Trading Partner Start to process component decision table (`allowSimultaneous="true"`)
- Add cross-reference from start_step.md to trading_partner_steps.md
- Fix stale Contents entries in trading_partner_component.md

## 0.5.6

- Add Route step reference (`route_step.md`) — runtime-validated via toggle tests covering default path routing, first-match-wins evaluation (XML element order, not key attribute), case-sensitive equals, and per-document batch evaluation

## 0.5.5

- Add Exception step reference (`exception_step.md`) — runtime-validated via toggle tests covering `stopsingledoc` behavior and Try/Catch interaction

## 0.5.4

- Add `boomi-execution-query.sh` for querying execution records and downloading logs (supports all process types including WSS listeners)
- Decouple log download from `boomi-test-execute.sh` — now returns execution ID and status only
- Fix INPROCESS polling bug in `boomi-test-execute.sh` — script now re-polls on HTTP 200 with INPROCESS/STARTED status instead of treating any 200 as complete
- Add `valueType="current"` to Set Properties source value types (validated via runtime toggle test)
- Add subprocess execution visibility guidance to testing guide (parent logs contain subprocess output, no independent ExecutionRecord for parent-invoked subprocesses)
- Strengthen Groovy scripting guidance — scripting is a last resort, native Boomi components always preferred for UI maintainability
- Update cli_tool_reference.md and process_testing_guide.md with execution query workflow

## 0.5.3

- Fix CLAUDE.md skill repos section to accurately describe single-repo architecture (plugin is source of truth, CI mirrors skills out)
- Track skill-level .gitignore so it mirrors to standalone skill repo

## 0.5.2

- Add problem solving guide with tiered escalation framework for unknown/undocumented scenarios
- Add SKILL.md pointers from file index, development philosophy, and validation errors sections

## 0.5.1

- Consolidate boomi_gotchas.md into boomi_error_reference.md as a unified troubleshooting reference
- Update all cross-references across SKILL.md, README.md, and component/step docs

## 0.5.0

- Restructure skill directory layout: `boomi-reference/` → `references/`, `tools/` → `scripts/`
- Consolidate standalone guide files into `references/guides/`
- Normalize filenames to underscores for consistency
- Update SKILL.md and README.md to reflect new structure

## 0.4.3

- Add repeated segments/loops instance identifier guidance to EDI profile docs (use loopRepeat + tagLists, not separate definitions)

## 0.4.2

- Add nested skill repo safety instructions to CLAUDE.md (check skill repos before stash/checkout/reset)
- Fix stale implementing-boomi reference in dual-repo docs

## 0.4.1

- Gitignore skill-level .gitignore from plugin repo (dual-repo support)

## 0.4.0

- Rename plugin from boomi-core to bc-integration, skill from implementing-boomi to boomi-integration
- Generalize Claude-specific language throughout skill content for cross-platform compatibility (Cursor, Codex, etc.)
- Replace Flow MCP server references with generic Flow tooling guidance
- Add dual-repo architecture documentation and gitignore support for standalone skill repo
- Add CONTRIBUTING.md files for both plugin and skill
- Add boomi-undeploy.sh to README tools list
- Update template settings to reference connector-gen skill
- Fix typo in README

## 0.3.11

- Fix component origin stamp to persist in local XML files (previously only applied in-flight during create, lost on first push)
- Add Groovy sandbox note: scripts cannot make external network calls, use connector steps instead
- Add recursion depth guard guidance to process call step docs
- Add invalid valueType warning to notify step docs
- Expand REST connector step actionType to full valid set: GET, HEAD, POST, DELETE, PUT, PATCH, OPTIONS, TRACE

## 0.3.10

- Expand document splitting guidance: three prevention mechanisms (nested targets, tagLists, additionalElementValue) and combined EDI pattern for 1 doc per transaction set

## 0.3.9

- Fix incorrect autoGenOption guidance: hierarc1/hierarc2 DO auto-generate HL01/HL02 (do not map these fields)
- Add HL Loop Pattern example for 856 S/O/P/I nested structure with autoGenOption and additionalCriteria
- Add EDI dataType enum strictness warning with common invalid values
- Add isMappable="false" silent data loss warning to JSON profile docs

## 0.3.8

- Add standardized activity logging — `log_activity` in `boomi-common.sh` writes JSONL entries to `.activity-log/activity.jsonl` at project root
- All 8 platform scripts log operation results (success/fail) with context details
- Add `.activity-log/` to template `.gitignore`

## 0.3.7

- Add `boomi-undeploy.sh` for deployment removal (by ID or by component file)
- Fix `xml_attr()` in boomi-common.sh to handle multi-line XML correctly

## 0.3.6

- Add CHANGELOG.md with full version history
- Update CLAUDE.md guideline to include changelog reminder on version bumps

## 0.3.5

- Remove Python/uv instruction block from template CLAUDE.md
- Fix missing newline at end of template file

## 0.3.4

- Fix sed delimiter collision in `stamp_origin` description append — pipe delimiter conflicted with the separator being inserted before the origin tag, causing "bad flag" errors on components with non-empty descriptions

## 0.3.3

- Add python3 tool permission to template settings

## 0.3.2

- Fix invalid `local` keyword used outside a function in component-pull script

## 0.3.1

- Fix `${var,,}` bashism in component-pull causing shell errors
- Normalize API-error exit codes from 1 to 0 so platform responses flow to the AI (matching Python-era behavior)
- Exclude hook-logs from freshies/template rsync
- Update template settings for bash tools, fix SKILL.md path reference

## 0.3.0

- **Breaking:** Rewrite all CLI tools from Python to bash using curl + jq directly
- Eliminate requests, PyYAML, python-dotenv, and lxml dependencies
- Remove YAML config layer — tools source `.env` natively
- Profile-inspect remains Python (stdlib only)
- All docs updated to match new invocations

## 0.2.15

- Fix HTTP 204 treated as failure in log download — now retries like 202 while waiting for log ZIP generation

## 0.2.14

- Salesforce operation reference overhaul from experiment findings
- Add correct camelCase filter operator values and all 6 operation types
- Add Sorts element requirement (GUI white-screens without it — Gotcha #28)
- Mark developer.boomi.com and help.boomi.com as fetchable fallbacks

## 0.2.13

- Add collision-safe sync state naming using path-based filenames (`folder__name.json`)
- Add backward compatibility fallback to legacy stem-only state files
- Document standalone subprocess deployment requirement for isolated testing
- Add Salesforce INVALID_FIELD troubleshooting guide (fEnabled fix)
- Add Bitbucket Pipelines CI configuration

## 0.2.12

- Add centralized process options reference with start-step-aware defaults
- Add Gotcha #27 for listener processes with default options pitfall
- Cross-reference process options from all relevant step/component files

## 0.2.11

- Add experimentally-verified EDI profile structure guidance
- Replace generic Transaction example with canonical Header/Detail/Summary three-container skeleton
- Document N2 implied decimal shifting behavior (verified via platform experiments)
- Add sibling loop data corruption warning for flat peer loops

## 0.2.10

- Sanitize plugin for external sharing — replace dev account IDs, environment GUIDs, names, and project names with generic placeholders
- Soften unvalidated disclaimer and incomplete product status language

## 0.2.9

- Add flat file identity field Gotchas #25 and #26
- Gotcha #25: `mandatory="true"` on identity fields causes MANDATORY_ELEMENT_MISSING on map output
- Gotcha #26: Identity value trimming in data positioned profiles causes silent record loss
- Fix templates in flat_file_profile_component.md to use `mandatory="false"` on identity fields

## 0.2.8

- Add fallback discovery for plugin template directory
- `configure-template-workspace` now searches standard cache, common local folders, and WSL paths before prompting the user

## 0.2.7

- Auto-tag component descriptions with plugin origin on creation
- Add `_get_origin_tag()` and `_stamp_description()` helpers
- Tags both platform-bound XML and local file on create; idempotent

## 0.2.6

- Update guidelines wording with bold emphasis and commit-push-pr reference
- Remove nested validate-claim command from implementing-boomi skill (now a top-level command)

## 0.2.5

- Fix incorrect Decision step comparison types — remove invalid isempty/isnotempty/contains from decision_step.md
- Add correct empty-check pattern using equals with empty static value
- Correct JsonSlurper availability claim: it IS available in Boomi's Groovy 2.4 runtime
- Replace fragile regex JSON examples with clean JsonSlurper usage

## 0.2.4

- Organize and tidy pass for broader rollout
- Migrate plugin prefix references (boomi: to boomi-core:)
- Trim onboarding guide bloat, fix typos and stale references
- Remove phantom Gotcha #18, consolidate duplicate auth section

## 0.2.3

- Remove skill-feedback command

## 0.2.2

- Update all references to officialboomi/boomi-marketplace

## 0.2.1

- Rename plugin to boomi-core

## 0.2.0

- Initial commit to new home in OfficialBoomi workspace