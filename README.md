# bc-integration

The official Boomi Companion — a Claude Code plugin for Boomi platform development. It wraps the boomi-integration skill with plugin-level commands, agents, and workspace tooling.

This project is licensed under the [BSD-2-Clause License](LICENSE). If you fork or modify this code, you should not use the name "Boomi" for your version.

## Feedback & Issues

Found a bug or have a feature idea? Open an issue with a clear description, steps to reproduce, and any relevant error messages. 

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

## Credential Handling

**Platform configuration credentials** (`.env` file): Your `.env` stores the Boomi API token, account ID, environment IDs, and other platform config needed by the CLI tools. These are necessary for the agent to push, pull, deploy, and test on your behalf.

**How the agent interacts with `.env`**: The project settings and agent instructions steer the agent away from directly reading your `.env` file. The CLI tools load credentials internally — the agent invokes the tools without seeing the credential values. This is a default convenience buffer, not a hard security boundary. Be aware that:

- The `.env` file is a plaintext file on your machine
- The default deny rules in the template workspace `.claude/settings.json` guide the agent away from common file-reading paths, but a sufficiently motivated or creatively prompted agent could find indirect ways to access file contents

If you need stricter isolation, consider Claude Code's [sandboxing options](https://docs.anthropic.com/en/docs/claude-code/security) or OS-level file permissions.

