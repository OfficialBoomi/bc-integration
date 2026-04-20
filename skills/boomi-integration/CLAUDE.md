# boomi-integration Skill

## What This Is

The boomi-integration skill — a framework for AI coding agents to build Boomi integration processes programmatically. See `README.md` for full details.

## Development Notes

- The `SKILL.md` is the agent-facing entry point. The `README.md` is for humans.
- `references/` contains curated Boomi platform documentation — treat it as authoritative.
- `scripts/` contains CLI scripts the agent uses to interact with the Boomi platform API.
- Boomi platform API calls from scripts must go through the `boomi_api` helper in `scripts/boomi-common.sh` (non-platform HTTP — e.g. WSS endpoint testing — is exempt). It wraps `boomi_curl`, which injects `-A "$BOOMI_USER_AGENT"` (`boomi-companion/<version>`, from `../VERSION`), applies the SSL-verify flag, sets the timeout, and handles basic auth. `boomi_api` also captures the response into the globals `RESPONSE_CODE` and `RESPONSE_BODY` so callers don't need to roll their own output parsing. If `boomi_api` is missing something you need for a platform call, extend the helper rather than bypassing it.
- Keep changes minimal and focused. This skill is consumed by multiple platforms.
