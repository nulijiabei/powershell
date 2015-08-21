#------- Get-SPServiceContext

function Get-SPServiceContext([Microsoft.SharePoint.Administration.SPServiceApplication]$profileApp)
{
    if($profileApp -eq $null)
    {
        #----- Get first User Profile Service Application
        $profileApp = @(Get-SPServiceApplication | ? { $_.TypeName -eq "User Profile Service Application" })[0]
    }  
return [Microsoft.SharePoint.SPServiceContext]::GetContext(
        $profileApp.ServiceApplicationProxyGroup, 
        [Microsoft.SharePoint.SPSiteSubscriptionIdentifier]::Default) 
}

$serviceContext= Get-SPServiceContext
$configManager = New-Object Microsoft.Office.Server.UserProfiles.UserProfileConfigManager($serviceContext)
if($configManager.IsSynchronizationRunning() -eq $false)
{
$configManager.StartSynchronization($true) 
Write-Host "Started Synchronizing"
}
else
{
Write-Host "Already Synchronizing"
}