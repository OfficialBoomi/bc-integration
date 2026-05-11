# bc-integration

The official Boomi Companion — a Claude Code plugin for Boomi platform development. It wraps the boomi-integration skill with plugin-level commands, agents, and workspace tooling.

> **Important:** Boomi Companion is a publicly available developer offering, not an officially supported Boomi product. It is provided as-is and is not covered by Boomi support agreements or SLAs. Boomi curates and maintains this tool on a best-effort basis — treat it as a self-service resource. Boomi reserves the right to modify or discontinue it at any time without notice.

This project is licensed under the [BSD-2-Clause License](LICENSE). If you fork or modify this code, you should not use the name "Boomi" for your version.

## Documentation

For a full overview of Boomi Companion, including concepts, usage guidance, and additional resources, see the [Boomi Companion overview](https://developer.boomi.com/docs/BoomiCompanion/Boomi_companion_overview) on the Boomi Developer Portal.

## Related Plugins & Skills

Other plugins available in Boomi Companion:

| Plugin | Description |
|--------|-------------|
| [bc-marketplace](https://github.com/OfficialBoomi/bc-marketplace) | Skill for searching and installing Boomi Marketplace recipes |

The underlying skills are also available as standalone packages for use with other AI agents, or to fork and modify for your own needs:

| Skill | Description |
|--------|-------------|
| [boomi-integration](https://github.com/OfficialBoomi/boomi-integration) | Skill for building Boomi integrations |
| [boomi-marketplace](https://github.com/OfficialBoomi/boomi-marketplace) | Skill for searching and installing Boomi Marketplace recipes |

See the [Boomi Companion marketplace](https://github.com/OfficialBoomi/boomi-companion) for the complete registry.

## Feedback & Issues

Found a bug or have a feature idea? Email developer-offerings@boomi.com with a clear description, steps to reproduce, and any relevant error messages.

## Installation

```bash
/plugin marketplace add OfficialBoomi/boomi-companion
/plugin install bc-integration@boomi-companion
```

Or browse and install via `/plugin` interactively.

## Commands

| Command | Purpose |
|---------|---------|
| `/bc-integration:env-setup-guide` | Interactive Boomi credentials setup |
| `/bc-integration:configure-template-workspace` | Create a reusable project template |
| `/bc-integration:tidy-up` | Clean development artifacts |

After running `configure-template-workspace`, use `/freshies` from any empty directory to scaffold a new project.

## Credential Handling

**Platform configuration credentials** (`.env` file): Your `.env` stores the Boomi API token, account ID, environment IDs, and other platform config needed by the CLI tools. These are necessary for the agent to push, pull, deploy, and test on your behalf.

**How the agent interacts with `.env`**: The project settings and agent instructions steer the agent away from directly reading your `.env` file. The CLI tools load credentials internally — the agent invokes the tools without seeing the credential values. This is a default convenience buffer, not a hard security boundary. Be aware that:

- The `.env` file is a plaintext file on your machine
- The default deny rules in the template workspace `.claude/settings.json` guide the agent away from common file-reading paths, but a sufficiently motivated or creatively prompted agent could find indirect ways to access file contents

If you need stricter isolation, consider Claude Code's [sandboxing options](https://docs.anthropic.com/en/docs/claude-code/security) or OS-level file permissions.

