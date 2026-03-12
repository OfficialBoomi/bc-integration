# bc-integration

A Claude Code plugin for Boomi platform development. It wraps the boomi-integration skill with plugin-level commands, agents, and workspace tooling.

## Installation

```bash
/plugin marketplace add OfficialBoomi/boomi-marketplace
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

