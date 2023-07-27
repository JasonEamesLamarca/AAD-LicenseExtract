
$DateTime = Get-Date
$DateTimeString = $DateTime.ToString("yyyyMMddHHmmss")

$UserLicenses = @()
Write-Output((Get-Date -Format "HH:mm:ss") + " Gather SKUs (ETA 1sec)")
$SubscribedSkus = Get-AzureADSubscribedSku | Select-Object SkuId, SkuPartNumber
Write-Output((Get-Date -Format "HH:mm:ss") + " Gather Users (ETA 2min)")
$AllUsers = Get-AzureADUser -all $true

$i = 0
$total = $AllUsers.Count

Write-Output((Get-Date -Format "HH:mm:ss") + " Gather Licenses (ETA 80min)")
foreach ($User in $AllUsers) {
    $i++
    $PercentComplete = [int]($i / $total * 100)
    Write-Progress -Activity "Retrieving user licenses" -Status "Processing user $($User.UserPrincipalName)" -PercentComplete $PercentComplete

    $Licenses = Get-AzureADUserLicenseDetail -ObjectId $User.ObjectId
    if ($Licenses -ne $null) {
        $LicenseFriendlyNames = @()
        foreach ($License in $Licenses) {
            foreach ($Sku in $SubscribedSkus) {
                if ($Sku.SkuId -eq $License.SkuId) {
                    $LicenseFriendlyNames += $Sku.SkuPartNumber
                }
            }
        }
        $LicenseFriendlyNames = $LicenseFriendlyNames | Sort-Object | Get-Unique
        $UserLicenseInfo = New-Object -TypeName PSObject -Property @{
            "UserPrincipalName" = $User.UserPrincipalName
            "DisplayName" = $user.DisplayName
            "Mail" = $User.Mail
            "Country" = $user.Country
            "CreatedDateTime" = $user.extensionproperty.createddatetime
            "onPremisesDistinguishedName" = $user.extensionproperty.onPremisesDistinguishedName
            "DirSyncEnabled" = $user.DirSyncEnabled
            "RefreshTokensValidFromDateTime" = $user.RefreshTokensValidFromDateTime
            "UserType" = $user.UserType
            "LicenseNames" = $LicenseFriendlyNames -join " "
        }
        $UserLicenses += $UserLicenseInfo
    }
}

Write-Progress -Activity "Retrieving user licenses" -Status "Processing complete" -PercentComplete 100
Write-Output((Get-Date -Format "HH:mm:ss") + " Write File")

$UserLicenses | Export-Csv -Path $DateTimeString"_UserLicenses.csv" -NoTypeInformation 
Write-Output((Get-Date -Format "HH:mm:ss") + " End.")
