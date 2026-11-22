# JML Runbook — vedhanlab.local

Temporary password used for all lab users: `Temp@2026Lab`
(lab-only, with "User must change password at next logon" ticked).
The Administrator / DSRM password is not recorded here.

## Joiner — bulk onboarding (10 users)

Created by hand first: Rohan Verma (`rohan.verma`, IT, GG-IT),
Priya Sharma (`priya.sharma`, HR, GG-HR).

Then 10 joiners, from `scripts/joiners.csv`:

| User | Department | Group | Manager |
|---|---|---|---|
| Arjun Mehta (`arjun.mehta`) | IT | GG-IT | rohan.verma |
| Kavya Reddy (`kavya.reddy`) | IT | GG-IT | rohan.verma |
| Vikram Nair (`vikram.nair`) | IT | GG-IT | rohan.verma |
| Ananya Iyer (`ananya.iyer`) | HR | GG-HR | priya.sharma |
| Rahul Desai (`rahul.desai`) | HR | GG-HR | priya.sharma |
| Meera Joshi (`meera.joshi`) | HR | GG-HR | priya.sharma |
| Nikhil Sharma (`nikhil.sharma`) | Finance | GG-Finance | — |
| Divya Patel (`divya.patel`) | Finance | GG-Finance | — |
| Aditya Rao (`aditya.rao`) | ServiceDesk | GG-ServiceDesk | — |
| Ishita Gupta (`ishita.gupta`) | ServiceDesk | GG-ServiceDesk | — |

Example (one user — repeat per row, changing name / OU / group / manager):
```powershell
New-ADUser -Name "Arjun Mehta" -GivenName "Arjun" -Surname "Mehta" `
  -SamAccountName "arjun.mehta" `
  -UserPrincipalName "arjun.mehta@vedhanlab.local" `
  -Path "OU=IT,DC=vedhanlab,DC=local" -Department "IT" `
  -Title "IT Support Analyst" `
  -AccountPassword (ConvertTo-SecureString -AsPlainText "Temp@2026Lab" -Force) `
  -Enabled $true -ChangePasswordAtLogon $true
Add-ADGroupMember -Identity GG-IT -Members arjun.mehta
Set-ADUser -Identity arjun.mehta -Manager rohan.verma
```

Verify: `Get-ADUser -Filter * | Select-Object SamAccountName`
— must list 12 lab users (plus built-in Administrator, Guest, krbtgt).

## Mover — Priya Sharma, HR → IT

Check groups before:
```powershell
Get-ADPrincipalGroupMembership -Identity priya.sharma | Select-Object Name
```
Before: GG-HR (plus Domain Users). After: GG-IT, no GG-HR.

```powershell
Move-ADObject -Identity "CN=Priya Sharma,OU=HR,DC=vedhanlab,DC=local" `
  -TargetPath "OU=IT,DC=vedhanlab,DC=local"
Remove-ADGroupMember -Identity GG-HR -Members priya.sharma -Confirm:$false
Add-ADGroupMember -Identity GG-IT -Members priya.sharma
Set-ADUser -Identity priya.sharma -Department IT -Title "IT Support Analyst"
```

Verify after:
```powershell
Get-ADUser -Identity priya.sharma | Select-Object DistinguishedName, Department
Get-ADPrincipalGroupMembership -Identity priya.sharma | Select-Object Name
```
DistinguishedName must say `OU=IT`, groups must show GG-IT and NOT GG-HR.
Leaving GG-HR on would be entitlement creep — that is the check this step proves.

## Leaver — Rahul Desai and Nikhil Sharma

For each leaver, in order — disable, reset password, remove group, move:

```powershell
Disable-ADAccount -Identity rahul.desai
Set-ADAccountPassword -Identity rahul.desai -Reset `
  -NewPassword (ConvertTo-SecureString -AsPlainText "Temp@2026Lab" -Force)
Remove-ADGroupMember -Identity GG-HR -Members rahul.desai -Confirm:$false
Move-ADObject -Identity "CN=Rahul Desai,OU=HR,DC=vedhanlab,DC=local" `
  -TargetPath "OU=Disabled Users,DC=vedhanlab,DC=local"
```

Same for Nikhil Sharma, with GG-Finance and
`CN=Nikhil Sharma,OU=Finance,DC=vedhanlab,DC=local`.

Verify:
```powershell
Get-ADUser -Identity rahul.desai | Select-Object Enabled, DistinguishedName
Get-ADUser -Identity nikhil.sharma | Select-Object Enabled, DistinguishedName
Get-ADPrincipalGroupMembership -Identity rahul.desai | Select-Object Name
Get-ADPrincipalGroupMembership -Identity nikhil.sharma | Select-Object Name
```
Both: Enabled False, OU=Disabled Users, groups = Domain Users only.

**90-day rule:** disabled now, deleted after 90 days. Do not delete on day one.

## Group Policy (PowerShell shortcut — same result as the GUI)

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity vedhanlab.local `
  -MinPasswordLength 12 -MaxPasswordAge 60.00:00:00 -PasswordHistoryCount 5 `
  -LockoutThreshold 5 -LockoutDuration 00:30:00 -LockoutObservationWindow 00:30:00

New-GPO -Name "Lab-IT-ScreenLock"
New-GPLink -Name "Lab-IT-ScreenLock" -Target "OU=IT,DC=vedhanlab,DC=local"
Set-GPRegistryValue -Name "Lab-IT-ScreenLock" `
  -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
  -ValueName ScreenSaveActive -Type String -Value "1"
Set-GPRegistryValue -Name "Lab-IT-ScreenLock" `
  -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
  -ValueName ScreenSaveTimeOut -Type String -Value "600"
Set-GPRegistryValue -Name "Lab-IT-ScreenLock" `
  -Key "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" `
  -ValueName ScreenSaverIsSecure -Type String -Value "1"

New-GPO -Name "Lab-Disable-ControlPanel"
New-GPLink -Name "Lab-Disable-ControlPanel" -Target "OU=IT,DC=vedhanlab,DC=local"
Set-GPRegistryValue -Name "Lab-Disable-ControlPanel" `
  -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
  -ValueName NoControlPanel -Type DWord -Value 1
```

Verify: `Get-GPO -All | Select-Object DisplayName` then `gpupdate /force`.
