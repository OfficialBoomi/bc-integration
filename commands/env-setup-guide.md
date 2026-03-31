---
description: Interactive guide for setting up Boomi platform credentials
---

Guide the user through setup or re-setup of their `.env` file for Boomi platform access.

## Steps

1. **Check current state**:
   - Ensure the `boomi-integration` skill is loaded (the `scripts/` directory comes from the skill)
   - Run `bash scripts/boomi-env-check.sh` to see which variables are SET vs UNSET
   - Run `bash scripts/boomi-folder-create.sh --test-connection` to test platform connectivity
   - Inform user of current state

2. **Ask user what they want**:
   - "What would you like to do?"
   - Options:
     - "Create/recreate .env file with Boomi credentials"
     - "Test connection to Boomi platform"
     - "Explain the credential fields"
     - "Do full setup"

3. **For credential setup**: 
- Have the user copy `.env.example` to a new file named `.env` using a text editor or IDE.
- Explain each value to the user, and instruct them where to find it. 
- Tell the user to paste each new value into their .env file and save.

You will not be able to write credentials into `.env` yourself due to default project settings.

- `BOOMI_USERNAME` - Boomi platform email
- `BOOMI_API_TOKEN` - "Go to Settings → Account Information and Setup → AtomSphere API Tokens. Generate a token."
- `BOOMI_ACCOUNT_ID` - "Find this in your platform URL after `/account/` or in Settings → Account Information"
- `BOOMI_TARGET_FOLDER` - Folder GUID for component storage (offer to create one after connection works)
- `BOOMI_ENVIRONMENT_ID` - "Go to Manage → Atom Management, select your environment, the ID is in the URL"
- `BOOMI_TEST_ATOM_ID` - "In the same Atom Management page, select your runtime — the atom ID is in the URL"



4. **Confirm completion**:
   - Run `bash scripts/boomi-folder-create.sh --test-connection` to verify
   - If success, ask: "What would you like to build?"
   - If failure, help troubleshoot based on the error message

## Notes

- Can be run multiple times for re-setup
- The agent helps users *find* credentials in the Boomi platform but does not write them to `.env` — the user edits the .env file themselves
- Use the boomi-integration skill's tools for connection testing when available
