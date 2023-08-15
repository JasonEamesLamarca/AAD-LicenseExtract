# Office 365 Licensing reporting
# Jason Eames 2023
# ---------------------------------------------------------
# Extracts all accounts from AzureAD
# Checks one by one if they have licenses assigned
# If they do it captures what licenes and last logon time
# If no sign-in activity checks if it was just created
# Also extracts complementary data

$DateTime = Get-Date
$DateTimeString = $DateTime.ToString("yyyyMMddHHmmss")
$JustCreated=15 # Number of days to consider account has just been created
$UserLicenses = @() #This is our output, let's make sure it's empty
Write-Output((Get-Date -Format "HH:mm:ss") + " Gather SKUs (ETA 1sec)")
$SubscribedSkus = Get-AzureADSubscribedSku | Select-Object SkuId, SkuPartNumber
Write-Output((Get-Date -Format "HH:mm:ss") + " Gather Users (ETA 2min)")
$AllUsers = Get-AzureADUser -all $true  #Let's load every single account out there
# Practical hints for testing purposes:
#  add "| Get-Random -Count 100" to scope down for testing since process takes a long time in large environment
#  add "| Sort-Object {$_.ExtensionProperty.createdDateTime} -Descending" so recently created accounts apear first

$i = 0
$total = $AllUsers.Count

Write-Output((Get-Date -Format "HH:mm:ss") + " Gather Licenses (ETA 12h)")
foreach ($User in $AllUsers) {
    $i++
    $PercentComplete = [int]($i / $total * 100)
    Write-Progress -Activity "Retrieving user licenses" -Status "Processing user $($User.UserPrincipalName)" -PercentComplete $PercentComplete
    $DaysCreatedSince=([DateTime]$DateTime - [DateTime]$User.ExtensionProperty.createdDateTime)
    $UserDN=[string]$user.extensionproperty.onPremisesDistinguishedName
    $Licenses = Get-AzureADUserLicenseDetail -ObjectId $User.ObjectId
    if ($Licenses -ne $null) {
        # We are only interested on accounts that have license allocation, the rest are ignored
        $LicenseFriendlyNames = @() #This is our output, we need to clear it since each license will be added.
        foreach ($License in $Licenses) {
            foreach ($Sku in $SubscribedSkus) {
                if ($Sku.SkuId -eq $License.SkuId) {
                    $LicenseFriendlyNames += $Sku.SkuPartNumber
                }
            }
        }
        $signInLogs = Get-MgAuditLogSignIn -Filter "userId eq '$($user.Objectid)'" -Top 1 -OrderBy "createdDateTime desc"
        if ($signInLogs) {
            # Here user has signed-in at least once, let's make a note of it
            Write-Host "(UserID: $($user.Objectid)) Last sign-in time for user $($user.UserPrincipalName): $($signInLogs.createdDateTime)"
            $LastSignIn=[string]$signInLogs.createdDateTime
        } else {
            # User never signed-in, maybe the account was just created?
            If ($DaysCreatedSince.Days -ile $JustCreated) {
                Write-Host "(UserID: $($user.Objectid)) Was just created $($DaysCreatedSince.Days) days ago, user $($user.UserPrincipalName)"
                $LastSignIn="Just Created"
            } else {
            # Ok, no signs of life here, let's report this guy as inactive
            Write-Host "(UserID: $($user.Objectid)) No sign-in records found for user $($user.UserPrincipalName)"
            $LastSignIn="No Records"
            }
        }
        
        $LicenseFriendlyNames = $LicenseFriendlyNames | Sort-Object | Get-Unique
        $UserLicenseInfo = New-Object -TypeName PSObject -Property @{
            "UserPrincipalName" = $User.UserPrincipalName
            "DisplayName" = $user.DisplayName
            "Mail" = $User.Mail
            "Country" = $user.Country
            "OU" = $UserDN.Substring($UserDN.IndexOf(",OU=UnilabsGroup,DC=uni,DC=ad") - 2, 2)
            "DaysOld" = $DaysCreatedSince.Days
            "onPremisesDistinguishedName" = $UserDN
            "DirSyncEnabled" = $user.DirSyncEnabled
            "LastSignIn" = $LastSignIn
            "UserType" = $user.UserType
            "LicenseNames" = $LicenseFriendlyNames -join " "
        }
        $UserLicenses += $UserLicenseInfo
    } else {
         Write-Host "(UserID: $($user.Objectid)) No licenses found for user $($user.UserPrincipalName)"
    }
}

Write-Progress -Activity "Retrieving user licenses" -Status "Processing complete" -PercentComplete 100
Write-Output((Get-Date -Format "HH:mm:ss") + " Write File")
$UserLicenses | Export-Csv -Path $DateTimeString"_UserLicenses.csv" -Encoding UTF8 -NoTypeInformation 
Write-Output((Get-Date -Format "HH:mm:ss") + " End.")
