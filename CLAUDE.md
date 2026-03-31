# bc-integration

This is a Claude Code plugin for Boomi platform development. It contains skills, commands, and agents. The intended audience of this CLAUDE.md document would be any user + AI combination that need to understand and potentially modify the plugin itself. 

## Installation

Users add the marketplace and install:
```bash
/plugin marketplace add git@bitbucket.org:officialboomi/boomi-marketplace.git
/plugin install bc-integration@boomi-marketplace
```

Alternatively they can navigate through the /plugin command within claude and add the repo/ plugins visually: `git@github.com:OfficialBoomi/boomi-marketplace.git`

Updates are generally automatically applied when opening a new Claude Code session, or can be manually added via the `/plugin` menu.

## Structure

```
.claude-plugin/plugin.json  # Manifest (required)
commands/                   # Slash commands (/bc-integration:command)
agents/                     # Custom agents
skills/                     # Agent skills (each oriented around a SKILL.md)
[There are other availbale plugin features like hooks, and mcp configs that may be used in the future]
```

## Development

Test locally:
```bash
claude --plugin-dir path-to-your-dev-copy-of-the-plugin/bc-integration
```

## Commands

- `/bc-integration:configure-template-workspace` - Sets up a template folder in the selected location and generates a global `/freshies` command.
- `/bc-integration:env-setup-guide` - Interactive Boomi credentials setup
- `/bc-integration:tidy-up` - Clean development artifacts

After running `configure-template-workspace`, users can invoke `/freshies` from any empty directory to scaffold a new Boomi project.

When `configure-template-workspace` is re-run in the template folder the AI merges updates intelligently, to keep their existing preferences while bringing in new updates from the plugin.

## Guidelines

- Keep contents minimal and focused
- Commands: generally user invoked, markdown files, filename becomes command name
- Skills: folders with SKILL.md, auto-invoked by context
- Agents: yaml/md definitions for specialized tasks, auto-invoked by context
- CLAUDE.local.md adds an additional layer of personalization outside the version control of the main plugin. E.g. a developer might use it to point Claude to local reference assets specific to their machine.

## Skill Repos

Skills (e.g. `skills/boomi-integration/`) live in this plugin repo as the source of truth. On push to main, the CI pipeline mirrors each skill out to its own standalone repo (via rsync) so the skill can also be consumed independently. There is no nested `.git` — just one repo tracking everything.
