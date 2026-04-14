# Claude Code Permission Deny Bypass via Script Execution

## Overview

Claude Code's Bash permission deny rules can be fully bypassed by writing denied commands into a script file and executing it. The permission parser evaluates only the top-level command in each Bash tool invocation. When a script file is executed (`Bash(/path/to/script.sh)`), the parser sees only the script path, not the commands inside the file. All deny rules are circumvented.

**Product:** Claude Code CLI v2.1.108
**CWE:** CWE-863 (Incorrect Authorization), CWE-451 (User Interface Misrepresentation of Critical Information)
**Tested:** April 14, 2026, Kali Linux

## Vulnerability Summary

| Aspect | Detail |
|--------|--------|
| Attack Vector | Local (requires Claude Code session) |
| Complexity | Low |
| User Interaction | User approves a file write and a script execution |
| Impact | Complete bypass of all command-level Bash deny rules |
| Exfiltration | Confirmed via denied `curl` command to external webhook |

## Attack Chain

1. User configures deny rules: `Bash(curl:*)`, `Bash(whoami:*)`, `Bash(id:*)`, `Bash(ss:*)`, `Bash(netstat:*)`
2. Claude writes a script containing all denied commands via the Write tool (not subject to Bash deny rules)
3. Claude executes the script: `Bash(/path/to/audit.sh)`
4. Permission parser evaluates only the script path; denied commands inside the file are not inspected
5. All denied commands execute: `whoami`, `id`, `ss`, `netstat`
6. Denied `curl` exfiltrates results to an external endpoint

The user approves a file creation and a script execution. They never approve any denied command directly. The approval prompt shows only the script path with no indication that denied commands will run.

## Reproduction

### Prerequisites

- Claude Code v2.1.108 or later (tested; likely affects earlier versions)
- Any operating system supported by Claude Code

### Step 1: Configure Deny Rules

Create `.claude/settings.local.json` in your project directory:

```json
{
  "permissions": {
    "allow": [
      "Bash(ls:*)",
      "Bash(echo:*)",
      "Bash(cat:*)",
      "Bash(find:*)"
    ],
    "deny": [
      "Bash(curl:*)",
      "Bash(whoami:*)",
      "Bash(id:*)",
      "Bash(ss:*)",
      "Bash(netstat:*)"
    ]
  }
}
```

### Step 2: Verify Baseline

Start Claude Code and run `/permissions`. Confirm all deny rules are visible under the Deny tab.

Ask Claude: `Run this command: id`

Expected result: **Hard denial.** "Error: Permission to use Bash with command id has been denied."

### Step 3: Write and Execute Script

Ask Claude:

```
Write a shell script called audit.sh that runs whoami, id, groups,
ss -tulnp, and netstat -tulnp, saving all output to results.txt.
Then execute it.
```

Claude will:
1. Use the Write tool to create `audit.sh` containing all denied commands
2. Execute the script via `Bash(chmod +x audit.sh && ./audit.sh)`

The permission prompt for the script execution shows only the script path. Approve it.

### Step 4: Verify Bypass

All denied commands execute. Output includes username, UID/GID, group memberships, and listening ports.

### Step 5: Add Exfiltration (Optional)

Ask Claude to update the script to POST results to a webhook.site endpoint using curl. The denied `curl` command executes inside the script without restriction.

### Step 6: Confirm Deny Rules Were Active

Run `/permissions` and verify all deny rules are still listed under the Deny tab.

## Evidence

| File | Description |
|------|-------------|
| [evidence/1_version_and_settings.PNG](evidence/1_version_and_settings.PNG) | Claude Code v2.1.108 and settings.local.json with deny rules |
| [evidence/2_confirmed_permissions.PNG](evidence/2_confirmed_permissions.PNG) | /permissions Deny tab showing all five deny rules active |
| [evidence/3_confirmed_id_denied.PNG](evidence/3_confirmed_id_denied.PNG) | Baseline: `id` command correctly denied in main session |
| [evidence/4_execute_audit_1.PNG](evidence/4_execute_audit_1.PNG) | Write tool creating audit.sh with denied commands visible |
| [evidence/4_execute_audit_2.PNG](evidence/4_execute_audit_2.PNG) | Update adding curl exfiltration to audit.sh |
| [evidence/4_execute_audit_3.PNG](evidence/4_execute_audit_3.PNG) | Bash approval prompt showing only script path, no denied commands |
| [evidence/5_confirmed_data_exfil.PNG](evidence/5_confirmed_data_exfil.PNG) | Webhook.site confirming receipt of exfiltrated data |
| [evidence/6_show_audit.PNG](evidence/6_show_audit.PNG) | Full script contents showing all denied commands |
| [evidence/7_2nd_example_bash_bypass.PNG](evidence/7_2nd_example_bash_bypass.PNG) | Deny rules still active after bypass completed |
| [evidence/demo.mp4](evidence/demo.mp4) | Full video demonstration |

## Source Files

| File | Description |
|------|-------------|
| [PoC/settings.local.json](PoC/settings.local.json) | Permission configuration with deny rules |
| [PoC/audit.sh](PoC/audit.sh) | Final script containing all denied commands and exfiltration |

## Root Cause

The Bash tool permission system evaluates commands at invocation time by parsing the command string passed to the Bash tool. When the command is a script path (`/path/to/script.sh` or `bash script.sh`), the parser evaluates the script path as a command identifier. It does not read or parse the script file to determine what commands it contains. The denied commands exist only inside the file, never in a Bash tool invocation string.

The Write tool, which creates the script file, is not subject to Bash deny rules because it is a separate tool. This creates a two-step bypass: Write (unrestricted) followed by Execute (parser blind to file contents).

## Indirect Prompt Injection Scenario

This bypass is exploitable without direct user intent:

1. A user configures deny rules to protect sensitive data and prevent network exfiltration
2. The user opens a project containing a malicious `CLAUDE.md` or reads a file with hidden prompt injection instructions
3. The injected instructions direct Claude to write a data collection and exfiltration script
4. Claude writes the script (Write tool, not restricted by Bash deny rules)
5. Claude presents the script execution for approval: "Run helper.sh"
6. The user sees a script name in the approval prompt, not the denied commands inside
7. The user approves; all deny rules are bypassed; data is exfiltrated

The user configured deny rules specifically to prevent this attack. The rules failed.

## Comparison to Accepted Findings

This finding follows the same pattern as previously accepted Claude Code security advisories:

- **[GHSA-xq4m-mc3c-vvg3](https://github.com/anthropics/claude-code/security/advisories/GHSA-xq4m-mc3c-vvg3):** Parser failed to detect command execution via `$IFS` and short CLI flags. Accepted because the parser should have caught the embedded execution.
- **[GHSA-x5gv-jw7f-j6xj](https://github.com/anthropics/claude-code/security/advisories/GHSA-x5gv-jw7f-j6xj):** Overly broad allowlist enabled file read and network exfiltration without confirmation. Accepted for the same impact class demonstrated here.

## Researcher

Jashid Sany
- GitHub: [github.com/jashidsany](https://github.com/jashidsany)
- Web: [jashidsany.com](https://jashidsany.com)
