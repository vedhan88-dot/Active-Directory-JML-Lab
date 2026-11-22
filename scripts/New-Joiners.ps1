# New-Joiners.ps1 — AD lab Step 3: bulk onboarding from CSV
# Run on DC01 only, in PowerShell as Administrator, AFTER Step 1 and Step 2 are done:
#   Step 1: Get-ADDomain returns vedhanlab.local
#   Step 2: OUs IT, HR, Finance, ServiceDesk exist, with groups GG-IT, GG-HR,
#           GG-Finance, GG-ServiceDesk, and the two hand-made users
#           rohan.verma (IT) and priya.sharma (HR) exist.
# Reads joiners.csv in the same folder. No password is stored in this script:
# it asks for one temporary password at run time and uses it for all 10 joiners.
# Re-running is safe: users already in AD are skipped, not duplicated.
# Log: joiners-log.txt in the same folder.

[CmdletBinding()]
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot "joiners.csv")
)

Import-Module ActiveDirectory -ErrorAction Stop

$Domain = "DC=vedhanlab,DC=local"
$UpnSuffix = "vedhanlab.local"

$OuMap = @{
    "IT"          = "OU=IT,$Domain"
    "HR"          = "OU=HR,$Domain"
    "Finance"     = "OU=Finance,$Domain"
    "ServiceDesk" = "OU=ServiceDesk,$Domain"
}
$GroupMap = @{
    "IT"          = "GG-IT"
    "HR"          = "GG-HR"
    "Finance"     = "GG-Finance"
    "ServiceDesk" = "GG-ServiceDesk"
}

# --- Pre-flight: stop with a clear message instead of failing halfway ---
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV not found: $CsvPath — copy joiners.csv next to this script and run again."
    exit 1
}
foreach ($ou in $OuMap.Values) {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'" -ErrorAction SilentlyContinue)) {
        Write-Error "OU not found: $ou — finish Step 2 (OUs and groups) first, then run this script."
        exit 1
    }
}
foreach ($group in $GroupMap.Values) {
    if (-not (Get-ADGroup -Identity $group -ErrorAction SilentlyContinue)) {
        Write-Error "Group not found: $group — finish Step 2 first, then run this script."
        exit 1
    }
}

$TempPassword = Read-Host "Enter ONE temporary password for all 10 joiners (you will write it down)" -AsSecureString
$LogPath = Join-Path $PSScriptRoot "joiners-log.txt"
$Created = 0; $Skipped = 0; $Failed = 0

Import-Csv $CsvPath | ForEach-Object {
    $username = $_.Username.Trim()
    $fullName = "$($_.FirstName.Trim()) $($_.LastName.Trim())"
    $ou = $OuMap[$_.Department.Trim()]
    $group = $GroupMap[$_.Department.Trim()]

    if (-not $ou) {
        "$((Get-Date).ToString('yyyy-MM-dd HH:mm')) FAILED $username — unknown Department '$($_.Department)'" | Out-File $LogPath -Append
        Write-Warning "FAILED $username — unknown Department '$($_.Department)'"
        $Failed++; return
    }

    if (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue) {
        "$((Get-Date).ToString('yyyy-MM-dd HH:mm')) ALREADY EXISTS $username ($fullName)" | Out-File $LogPath -Append
        Write-Host "Already exists, skipped: $username"
        $Skipped++; return
    }

    try {
        New-ADUser -Name $fullName `
            -GivenName $_.FirstName.Trim() -Surname $_.LastName.Trim() `
            -SamAccountName $username `
            -UserPrincipalName "$username@$UpnSuffix" `
            -Path $ou -Department $_.Department.Trim() -Title $_.Title.Trim() `
            -AccountPassword $TempPassword -Enabled $true `
            -ChangePasswordAtLogon $true -ErrorAction Stop

        Add-ADGroupMember -Identity $group -Members $username -ErrorAction Stop

        if ($_.Manager -and $_.Manager.Trim()) {
            $manager = $_.Manager.Trim()
            if (Get-ADUser -Identity $manager -ErrorAction SilentlyContinue) {
                Set-ADUser -Identity $username -Manager $manager -ErrorAction Stop
            } else {
                Write-Warning "$username created, but manager '$manager' not found in AD — manager left unset."
            }
        }

        "$((Get-Date).ToString('yyyy-MM-dd HH:mm')) CREATED $username ($fullName) in $($_.Department) / $group" | Out-File $LogPath -Append
        Write-Host "Created: $username ($fullName) — $($_.Department) / $group"
        $Created++
    }
    catch {
        "$((Get-Date).ToString('yyyy-MM-dd HH:mm')) FAILED $username — $($_.Exception.Message)" | Out-File $LogPath -Append
        Write-Warning "FAILED $username — $($_.Exception.Message)"
        $Failed++
    }
}

Write-Host ""
Write-Host "Done: $Created created, $Skipped already existed, $Failed failed. Log: $LogPath"
Write-Host "Verify with: Get-ADUser -Filter * | Measure-Object"
Write-Host "            Get-ADUser -Filter * -SearchBase 'OU=IT,DC=vedhanlab,DC=local'"
