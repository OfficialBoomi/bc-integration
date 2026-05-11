---
description: Set up your local Boomi template folder and configure the command to spin up a new workspace profile
---

This command sets up the user's personal Boomi project template (referred to as the **User Template** throughout this doc) and generates the global `/freshies` command for spinning up new workspaces from it.

The steps below locate the plugin's **Reference Template** and copy it into the **User Template** workspace location the user specifies.

## Workflow

### Step 1: Get Template Location

Use the AskUserQuestion tool to ask where they'd like their new User Template folder:

**Question:** "Where would you like your Boomi template folder to be stored?"
**Header:** "Template path"
**Options (in this order):**
1. **Current directory** - "Use this current working directory" - The directory they're running the command from
2. **~/boomi-template** - "Default location in your home directory"
3. **~/Desktop/boomi-template** - "On your Desktop for easy access"

The user can also select "Other" to provide a custom path.

### Step 2: Find the Reference Template Directory

Work through this checklist:

- [ ] Load the `boomi-integration` skill. The loader prints a line near the top of the output: `Base directory for this skill: <install-path>/bc-integration/skills/boomi-integration`.
- [ ] Strip the trailing `/skills/boomi-integration` from the base directory → that's the plugin root.
- [ ] Append `/template` to the plugin root → that's the Reference Template path.
- [ ] Verify the path exists with `ls <path>` before proceeding.

Example: base dir `~/bc/plugins/bc-integration/skills/boomi-integration` → Reference Template at `~/bc/plugins/bc-integration/template/`.

If the skill fails to load (uncommon) or the template path doesn't exist, ask the user where the bc-integration plugin is installed.

We will call this resolved path `PLUGIN_REFERENCE_TEMPLATE_DIR` going forward.

### Step 3: Copy Template to Workspace

**If the new User Template workspace folder doesn't exist:**
- Create the User Template folder
- Copy all contents from `PLUGIN_REFERENCE_TEMPLATE_DIR/` to their chosen location
- Inform them to set up `.env` with their credentials (copy from `.env.example`)

**If the folder already exists:**
- Perform a smart merge:
  - **PRESERVE**: `.env`, `.env.local`, `preferred_connections.md` (user's connection registry), any custom files or instructions they've added
  - **MERGE / UPDATE**: Directory structure, `.gitignore`, `.env.example`, `README.md`, `CLAUDE.md`
  - **ASK** about conflicts if unsure, err on the side of preserving anything that appears to be the user's custom content
- Report what was updated vs preserved

### Step 4: Generate Global Command

Create `~/.claude/commands/freshies.md` with this content:

```markdown
---
description: Create a new Boomi project from your personal template
allowed-tools: Bash
---

Scaffold a new Boomi project by copying the designated template into the current working directory.

## Pre-flight Checks

1. Verify the template exists at: {{USER_TEMPLATE_PATH}}
2. Verify current directory is safe (not inside .git, not the user's template workspace itself)

## Execution

Copy the entire template into the current directory. The template is the source of truth — copy it here as-is:
\`\`\`bash
rsync -av --exclude='.git' --exclude='hook-logs' "{{USER_TEMPLATE_PATH}}/" .
\`\`\`

## Post-Setup

Tell the user: 
If your .env file is setup, you are ready to build!

TIP: If permissions prompts feel frequent, `/exit` and relaunch — the workspace's quality-of-life permission settings only take effect after a fresh session.
```

Replace `{{USER_TEMPLATE_PATH}}` with the actual User Template path.

### Step 5: Confirm Setup

Tell the user:
- Their template is at: [path]
- The `/freshies` command is now available globally
- They can run `/freshies` from any empty directory to start a new Boomi project
- They can re-run `/bc-integration:configure-template-workspace` anytime to update their template

## Notes

- This command can be run multiple times to update the template
- The user's `.env` credentials are NEVER overwritten
- The generated `/freshies` command is independent of the plugin location.
- The User Template lives outside the plugin, so it isn't overwritten when plugin updates are pulled in.
- The user should occasionally re-run `/bc-integration:configure-template-workspace` to merge updates from the plugin's Reference Template into their User Template.
