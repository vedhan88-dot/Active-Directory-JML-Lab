# Active Directory JML Lab — vedhanlab.local

Home lab, not employment. Built on a single domain controller (DC01) running
Windows Server 2022 Evaluation (180-day trial), 2 vCPU / 2 GB RAM / 32 GB disk,
on an Intel i3 / 8 GB laptop — one VM at a time.

Domain: `vedhanlab.local` | Server: `DC01` | All users are invented lab accounts.

## What this lab does

- **Joiner:** bulk onboarding of 10 users from CSV with PowerShell
  (`New-ADUser`, group assignment, temporary password, change at next logon)
- **Mover:** department change with entitlement-creep check
  (Priya Sharma, HR → IT, GG-HR removed, GG-IT added)
- **Leaver:** disable, revoke, move to Disabled Users OU, 90-day delete rule
  (Rahul Desai, Nikhil Sharma — both Enabled: False)
- **Group Policy:** password/lockout, screen lock, Control Panel lockdown
- **Audit:** stale, locked-out, password-never-expires, privileged-group and
  disabled-account checks — see `findings/audit-findings.md`

## Structure

- OUs (6): IT, HR, Finance, ServiceDesk, Disabled Users, Service Accounts
- Groups (5, Global + Security): GG-IT, GG-HR, GG-Finance, GG-ServiceDesk,
  GG-VPN-Users (GG-VPN-Users was not created in this run — see runbook note)
- Users (12 lab users): Rohan Verma, Priya Sharma, Arjun Mehta, Kavya Reddy,
  Vikram Nair, Ananya Iyer, Rahul Desai, Meera Joshi, Nikhil Sharma,
  Divya Patel, Aditya Rao, Ishita Gupta
  (plus built-in Administrator, Guest, krbtgt)

## Group Policy

| GPO | Scope | Setting |
|---|---|---|
| Default Domain Policy | vedhanlab.local | Min password length 12, max age 60 days, history 5, lockout after 5 invalid logons for 30 min, reset counter after 30 min |
| Lab-IT-ScreenLock | IT OU | Screen saver on, password protected, timeout 600 seconds |
| Lab-Disable-ControlPanel | IT OU | Prohibit access to Control Panel and PC settings |

Verified with `Get-GPO -All` and `gpupdate /force`.

## Step 7 — Windows client join + `gpresult`: completed 22 Nov 2026

CLIENT01 is a Windows 11 Pro VM (4096 MB RAM, 2 CPUs, 32 GB disk)
on the same NatNetwork as DC01 (DC01 10.0.2.15, CLIENT01 10.0.2.3,
gateway 10.0.2.1). The first CLIENT01 was deleted entirely on 22 Nov 2026
after a blank/black screen at install, and was rebuilt freshly from scratch
(EFI first, then TPM 2.0; the New VM picker could not see/select the ISO on
E:, so it was attached via Settings → Storage after the VM was created;
local account created via `start ms-cxh:localonly` — `oobe\bypassnro`
did not work on this build). CLIENT01 joined `vedhanlab.local` on
22 Nov 2026, logged in as `vedhanlab\rohan.verma`, and `gpresult /r`
(22 Nov 2026, 23:00:40, applied from WIN-RTB0SOP9VGS.vedhanlab.local)
shows Applied Group Policy Objects: **Lab-IT-ScreenLock** and
**Lab-Disable-ControlPanel**. See `screenshots/gpresult.png` and
`screenshots/control-panel-blocked.png`.

## What was skipped / is still in progress, honestly

- **GG-VPN-Users:** listed in the plan, not verified as created in this run.
  The 4 department groups (GG-IT, GG-HR, GG-Finance, GG-ServiceDesk) were
  verified in AD.

## How to reproduce

1. Install Windows Server 2022 Evaluation, promote to DC for a new forest.
2. Create the 6 OUs and 5 groups above, and 2 users by hand.
3. Run `scripts/New-Joiners.ps1` from the same folder as `scripts/joiners.csv`
   (PowerShell as Administrator, on the DC). It asks for one temporary
   password, creates the 10 users, and writes `joiners-log.txt`.
   Note: the first copy of this script on the lab VM was corrupted in
   transfer (parser errors on lines 45/109). The copy in this repo is the
   clean original. Do not open/edit a `.ps1` in Notepad before running it.
   In this lab run, the 10 users were in the end created by typed
   `New-ADUser` commands (same values as the CSV) after the script copy
   failed — see `runbook/JML-runbook.md`.
4. Follow `runbook/JML-runbook.md` for the mover and leaver.
5. Create the GPOs above, or use the PowerShell commands in the runbook.
6. Run the audit commands in `findings/audit-findings.md`.

## Files

```
README.md
runbook/JML-runbook.md
scripts/New-Joiners.ps1
scripts/joiners.csv
scripts/Audit-ADAccounts.ps1
screenshots/   — OU tree, GPO list, Get-ADUser list, audit output, gpresult, Control Panel blocked
findings/audit-findings.md
```
