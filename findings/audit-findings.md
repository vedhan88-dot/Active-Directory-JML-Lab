# Audit findings — 17 Nov 2026, vedhanlab.local

Run on DC01 in PowerShell as Administrator. Fresh lab, so "none found" is the
expected result for most checks — the findings are that the controls worked.

## Results

| Check | Command | Result (17 Nov 2026) | Finding |
|---|---|---|---|
| Inactive 90+ days | `Search-ADAccount -AccountInactive -TimeSpan 90.00:00:00` | Not shown in the saved screenshot (scrolled off) — lab is 4 days old, no account can be 90 days inactive | No finding expected; re-run to confirm "none" before presenting |
| Locked out | `Search-ADAccount -LockedOut` | Not shown in the saved screenshot (scrolled off) | No finding expected; re-run to confirm "none" |
| Disabled accounts | `Search-ADAccount -AccountDisabled` | rahul.desai, nikhil.sharma — verified separately in Step 5: both Enabled False, OU=Disabled Users | PASS — leavers correctly disabled, not deleted |
| Password never expires | `Get-ADUser -Filter 'PasswordNeverExpires -eq $true'` | Administrator, Guest only (built-in accounts) — no lab user | PASS — no lab user bypasses password expiry |
| Domain Admins | `Get-ADGroupMember -Identity "Domain Admins"` | Administrator only | PASS — no extra privileged member |
| Enterprise Admins | `Get-ADGroupMember -Identity "Enterprise Admins"` | Administrator only | PASS |
| Schema Admins | `Get-ADGroupMember -Identity "Schema Admins"` | Administrator only | PASS |
| Disabled user groups — Rahul | `Get-ADPrincipalGroupMembership -Identity rahul.desai` | Domain Users only | PASS — GG-HR removed, no entitlement creep |
| Disabled user groups — Nikhil | `Get-ADPrincipalGroupMembership -Identity nikhil.sharma` | Domain Users only | PASS — GG-Finance removed |

## What each finding means

- **Disabled leavers with only Domain Users:** the leaver step worked.
  A disabled account keeping GG-HR / GG-Finance would still have access
  if it were re-enabled — that is entitlement creep, and it did not happen here.
- **Privileged groups = Administrator only:** no joiner was given admin rights
  by mistake during bulk onboarding.
- **Password never expires = built-ins only:** every lab user must change
  their temporary password at next logon and is subject to the 60-day
  password policy. Administrator / Guest are the built-in defaults, not
  lab users — do not "fix" them by changing built-in accounts.
- **Inactive / locked-out:** on a 4-day-old lab these should be empty.
  In a real environment, an inactive 90+ day account is a disable candidate,
  and a locked-out account is a check for brute-force attempts (Event 4625).

## Fix, if a check ever fails

- Inactive 90+ days → disable, move to Disabled Users, delete after 90 days.
- Locked out → check the lockout source, unlock only after verifying the user.
- Password never expires on a real user → clear the flag, force a change.
- Extra member in Domain/Enterprise/Schema Admins → remove immediately,
  check how they got in.
- Disabled account still in a department group → remove the group membership.
