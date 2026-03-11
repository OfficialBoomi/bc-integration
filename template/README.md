# Template Boomi Implementation Workspace

This is a template directory to support programmatic Boomi development with Claude Code using the boomi-integration skill. It is distributed via the bc-integration plugin. 

The intended audience of this README.md document are the human users seeking more info about the template workspace.

## Setup & Usage

When a user has installed the bc-integration plugin they are provided a new command: `/bc-integration:configure-template-workspace` . Run that command in the directory you would like to use as your long term "workspace template." 

It will:
- Bring the standard template from the plugin into that chosen location
- Generate a global `/freshies` command that can be used from any empty directory to clone your template folder into that location.
- If your template workspace already exists the model will intelligently merge any updates in with your existing configurations and preferences.

If your `.env` file wasn't configured during project creation:

```bash
cp .env.example .env  # Edit with your platform credentials
```

Alternatively, ask claude to help you setup your .env variables (platform account ID, API key, etc). It can guide you through credential setup interactively.

## Directory Structure of the Template

**Component Development:**
- `active-development/` - Working directory for Boomi components and artifacts
  - Component folders: `processes/`, `profiles/`, `connections/`, `operations/`, `maps/`, `scripts/`, `document-caches/`
  - `feedback/` - Test execution results and logs
  - `.sync-state/` - Platform sync tracking (gitignored)

**Configuration:**
- `.env` - Platform credentials and runtime server settings (gitignored)
- `.claude/` - Claude Code settings and custom commands that you would like to be included in all new workspaces
  - `settings.local.json` - Permission presets
  - `commands/tidy-up` - Workspace cleanup command

Note: The `/freshies` logic should replicate anything in your template folder so it is not restricted to just the original sample assets. If, for example, you chose to add a folder of reference material or hooks to your template those would be included in all of your workspaces (this can be very useful).

**Common workflows:**
- Create a new project directory
- Launch claude and run `/freshies`
- Claude brings in your template workspace
- Prompt claude to build new assets or modify existing ones
- Workspace cleanup: Use `/tidy-up` to remove all development artifacts, or just `/freshies` spin up a new project workspace for the next project!
- Profit
