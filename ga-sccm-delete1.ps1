$SCCMServer = "SCCM1" 
$sitename = "GA1" 

$computerlist = Get-content C:\Health\WKS\delete-computer-accounts.txt
Foreach($computername in $computerlist)
{   
    # Get the resourceID from SCCM 
    $resID = Get-WmiObject -computername $SCCMServer -query "select resourceID from sms_r_system     where name like `'$computername`'" -Namespace "root\sms\site_$sitename" 
    $computerID = $resID.ResourceID 
 
    if ($resID.ResourceId -eq $null) { 
        $msgboxValue = "No SCCM record for that computer" 
        } 
    else 
        { 
	$comp = [wmi]"\\$SCCMServer\root\sms\site_$($sitename):sms_r_system.resourceID=$($resID.ResourceId)"  
 
        # Output to screen 
        Write-Host "$computername with resourceID $computerID will be deleted" 
 
        # Delete the computer account 
        $comp.psbase.delete()
    } 
} # end ForEach