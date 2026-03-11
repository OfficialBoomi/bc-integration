---
description: Interactive guide for setting up Boomi platform credentials
---

Guide the user through setup or re-setup of their `.env` file for Boomi platform access.

## Steps

1. **Check current state**:
   - Check if `.env` exists in the project
   - Check if `.env.example` exists as a template
   - Inform user of current state

2. **Ask user what they want**:
   - "What would you like to do?"
   - Options:
     - "Create/recreate .env file with Boomi credentials"
     - "Test connection to Boomi platform"
     - "Explain the credential fields"
     - "Do full setup"

3. **For credential setup**, collect:
   - `BOOMI_USERNAME` - Boomi platform email
   - `BOOMI_API_TOKEN` - API token from platform Settings > API Tokens
   - `BOOMI_ACCOUNT_ID` - Account ID from platform URL or Settings
   - `BOOMI_TARGET_FOLDER` - Folder GUID for component storage
   - `BOOMI_ENVIRONMENT_ID` - Environment for deployments
   - `BOOMI_TEST_ATOM_ID` - Atom for test executions

4. **Confirm completion**:
   - Verify .env was created
   - Offer to test the connection
   - Ask: "What would you like to build?"

## Notes

- Can be run multiple times for re-setup
- Warn before overwriting existing .env
- Use the boomi-integration skill's tools for connection testing when available
