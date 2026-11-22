# Audit-ADAccounts.ps1 — AD lab Step 8: stale and privileged-account audit
# Run on DC01 only, in PowerShell as Administrator, after Step 3 (bulk onboarding).
# Reports, in plain tables, and saves the same output to audit-output.txt
# in the same folder (the findings table for the repo):
#   1. Accounts inactive 90+ days
#   2. Locked-out accounts
#   3. Accounts with password never expires
#   4. Members of privileged groups: Domain Admins, Enterprise Admins, Schema Admins
#   5. Disabled accounts still holding group memberships (entitlement creep)
# On a fresh lab most sections will be empty — that is the expected result,
# and the script says so instead of erroring.

[CmdletBinding()]
param()

Import-Module ActiveDirectory -ErrorAction Stop

$OutPath = Join-Path $PSScriptRoot "audit-output.txt"
"AD audit — vedhanlab.local — $((Get-Date).ToString('yyyy-MM-dd HH:mm'))" | Out-File $OutPath

function Show-Section {
    param([string]$Title, [object]$Rows, [string[]]$Properties)
    Write-Host ""
    Write-Host "=== $Title ==="
    "=== $Title ===" | Out-File $OutPath -Append
    if ($Rows) {
        $Rows | Select-Object $Properties | Format-Table -AutoSize | Out-String | Tee-Object -FilePath $OutPath -Append | Write-Host
    } else {
        Write-Host "None found."
        "None found." | Out-File $OutPath -Append
    }
}

# 1. Inactive 90+ days
$inactive = Search-ADAccount -AccountInactive -TimeSpan (New-TimeSpan -Days 90) -UsersOnly |
    Select-Object Name, SamAccountName, LastLogonDate, Enabled
Show-Section "1. Accounts inactive 90+ days" $inactive @("Name", "SamAccountName", "LastLogonDate", "Enabled")

# 2. Locked out
$locked = Search-ADAccount -LockedOut -UsersOnly |
    Select-Object Name, SamAccountName, LastLogonDate, Enabled
Show-Section "2. Locked-out accounts" $locked @("Name", "SamAccountName", "LastLogonDate", "Enabled")

# 3. Password never expires (Get-ADUser is more reliable here than Search-ADAccount)
$neverExpires = Get-ADUser -Filter 'PasswordNeverExpires -eq $true' -Properties PasswordNeverExpires, LastLogonDate |
    Select-Object Name, SamAccountName, PasswordNeverExpires, Enabled
Show-Section "3. Password never expires" $neverExpires @("Name", "SamAccountName", "PasswordNeverExpires", "Enabled")

# 4. Privileged groups
Write-Host ""
Write-Host "=== 4. Privileged group members ==="
"=== 4. Privileged group members ===" | Out-File $OutPath -Append
foreach ($group in @("Domain Admins", "Enterprise Admins", "Schema Admins")) {
    $members = Get-ADGroupMember -Identity $group -ErrorAction SilentlyContinue |
        Select-Object Name, SamAccountName, objectClass
    Write-Host "-- $group --"
    "-- $group --" | Out-File $OutPath -Append
    if ($members) {
        $members | Format-Table -AutoSize | Out-String | Tee-Object -FilePath $OutPath -Append | Write-Host
    } else {
        Write-Host "No members found."
        "No members found." | Out-File $OutPath -Append
    }
}

# 5. Disabled accounts still in groups
$disabledWithGroups = Get-ADUser -Filter 'Enabled -eq $false' -Properties MemberOf |
    Where-Object { $_.MemberOf.Count -gt 0 } |
    Select-Object Name, SamAccountName,
        @{Name = "Groups"; Expression = { ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=', '' }) -join '; ' } }
Show-Section "5. Disabled accounts still holding group memberships" $disabledWithGroups @("Name", "SamAccountName", "Groups")

Write-Host ""
Write-Host "Saved to: $OutPath"
Write-Host "Next: copy the findings into findings/audit-findings.md — one line per finding: what it is, why it matters, and the fix."
