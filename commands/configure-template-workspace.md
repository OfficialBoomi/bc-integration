---
description: Set up your local Boomi template folder and configure the command to spin up a new workspace profile
---

This command sets up your personal Boomi project template and generates the global command to configure a new workspace profile.

## Workflow

### Step 1: Get Template Location

Use the AskUserQuestion tool to ask where they'd like their Boomi template folder:

**Question:** "Where would you like your Boomi template folder to be stored?"
**Header:** "Template path"
**Options (in this order):**
1. **Current directory** - "Use this current working directory" - The directory they're running the command from
2. **~/boomi-template** - "Default location in your home directory"
3. **~/Desktop/boomi-template** - "On your Desktop for easy access"

The user can also select "Other" to provide a custom path.

### Step 2: Find the Plugin's Template Directory

Before copying, locate the `template/` directory inside the bc-integration plugin. Try these approaches in order:

1. **Derive from skill path** — Invoke the `boomi-integration` skill (or check if it's already loaded). The skill's base directory reveals the plugin filesystem path (e.g., `.../bc-integration/skills/boomi-integration` → plugin root is `.../bc-integration`). This works regardless of whether the plugin was installed from the marketplace or loaded via `--plugin-dir`.
2. **Standard plugin cache** — `~/.claude/plugins/cache/boomi-marketplace/bc-integration/*/template` (pick the latest version if multiple exist)
3. **Ask the user** — If neither approach finds a `template/` directory, ask: *"I couldn't auto-detect the bc-integration plugin location. Where did you extract or clone the plugin folder?"*

Store the discovered path as `PLUGIN_DIR` (the bc-integration root) for later use.

### Step 3: Copy Template to Workspace

**If the workspace folder doesn't exist:**
- Create the folder
- Copy all contents from `PLUGIN_DIR/template/` to their chosen location
- Inform them to set up `.env` with their credentials (copy from `.env.example`)

**If the folder already exists:**
- Perform a smart merge:
  - **PRESERVE**: `.env`, `.env.local`, `preferred_connections.md` (user's connection registry), any files they've added
  - **UPDATE**: Directory structure, `.gitignore`, `.env.example`, `README.md`, `CLAUDE.md`
  - **ASK** about conflicts if unsure
- Report what was updated vs preserved

### Step 4: Generate Global Command

Create `~/.claude/commands/freshies.md` with this content (substitute their template path):

```markdown
---
description: Create a new Boomi project from your personal template
allowed-tools: Bash
---

Scaffold a new Boomi project by copying the designated template into the current working directory.

## Pre-flight Checks

1. Verify the template exists at: {{TEMPLATE_PATH}}
2. Verify current directory is safe (not inside .git, not the template itself)

## Execution

Copy the entire template into the current directory and if git is available initialize a fresh git repo. If git is not available alert the user and carry on. The template is the source of truth — copy it here as-is:
\`\`\`bash
rsync -av --exclude='.git' --exclude='hook-logs' "{{TEMPLATE_PATH}}/" .
git init && git add . && git commit -m "Initial commit from template"
\`\`\`

## Post-Setup

Tell the user: 
If your .env file is setup, you are ready to build!

TIP: If you haven't already been prompted to trust the files in this directory, `/exit` and re-launch `claude` to accept/trust the quality-of-life permissions list
```

Replace `{{TEMPLATE_PATH}}` with the user's actual template path.

### Step 5: Confirm Setup

Tell the user:
- Their template is at: [path]
- The `/freshies` command is now available globally
- They can run `/freshies` from any empty directory to start a new Boomi project
- They can re-run `/bc-integration:configure-template-workspace` anytime to update their template

## Notes

- This command can be run multiple times to update the template
- The user's `.env` credentials are NEVER overwritten
- The generated `/freshies` command is independent of the plugin location
