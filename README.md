# bc-integration

A Claude Code plugin for Boomi platform development. It wraps the [boomi-integration skill](skills/boomi-integration/README.md) with plugin-level commands, agents, and workspace tooling.

## Installation

```bash
/plugin marketplace add git@bitbucket.org:officialboomi/boomi-marketplace.git
/plugin install bc-integration@boomi-marketplace
```

Or browse and install via `/plugin` interactively.

## Commands

| Command | Purpose |
|---------|---------|
| `/bc-integration:env-setup-guide` | Interactive Boomi credentials setup |
| `/bc-integration:configure-template-workspace` | Create a reusable project template |
| `/bc-integration:tidy-up` | Clean development artifacts |

After running `configure-template-workspace`, use `/freshies` from any empty directory to scaffold a new project.

## What's Included

- **Skill** — `skills/boomi-integration/` contains all Boomi reference docs, CLI scripts, and the core agent skill. See its [README](skills/boomi-integration/README.md) for details.
- **Commands** — slash commands for workspace setup and maintenance
- **Agents** — specialized agents for targeted tasks (e.g. canvas arrangement)
