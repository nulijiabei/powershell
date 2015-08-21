### Populate these variables please. ###
#$ExcelLog = $Env:USERPROFILE + '' + (Get-Date).ToString().Replace("/","-").Replace(":","") + " AD Workstation Cleanup.xlsx" # Full path to save Excel log to
$DisabledDn    = 'ou=Disabled,ou=Workstations,dc=ts,dc=;pc' # OU to place disabled accounts into
#$DisableAge = 60 # Age (in days) of computer account, to be disabled
#$DeleteAge = 30 # Age of computer account (<DisabledDate> + X) to delete computer accounts
$SccmServer = 'sccm1' # The server on which your SMS Provider component is installed
$BreakStuff = $false # If set to $true, the script WILL TAKE ACTION!
$Debug = $true # Enables additional logging to file and stdout
###  ### ############################# ###  ###

# Purpose Remove a Computer Account from AD
function RemoveFromAD ($tPcName)
{
# Using Quest Snap In
# If Accidental Delete Protection is on.
#Add-QADPermission -Account 'EVERYONE' -Rights 'Delete,DeleteTree' -ApplyTo 'ThisObjectOnly'
Remove-ADObject $tPCName
}


# Purpose: This function deletes a resource from the Configuration Manager database
function RemoveFromSccm($tPcName, $tSiteServer)
{
    $tSysQuery = "select * from SMS_R_System where Name = '$tPcName'"
    $tWmiNs = "rootsmssite_" + $Global:SccmSiteCode
    if ($Debug)
    {
        LogMessage "Site code is: $Global:SccmSiteCode" 1
        LogMessage $tSysQuery 1
        LogMessage "tSiteServer is: $tSiteServer" 1
        LogMessage "tWmiNs is: $tWmiNs" 1
    }
    $Resources = Get-WmiObject -ComputerName $tSiteServer -Namespace $tWmiNs -Query $tSysQuery

    if ($Resources -eq $null) { return; }

    foreach ($Resource in $Resources)
    {
        $AgentTime = $($Resource.AgentTime | Sort-Object | Select-Object -Last 1)
        $UserName = $Resource.LastLogonUserDomain + '' + $Resource.LastLogonUserName
        # Log the deleted SCCM resource to the Excel log
        WriteSccmDeletionEntry $Resource.ResourceID $Resource.Name $AgentTime $UserName
        # This line deletes records from the ConfigMgr database
        if ($BreakStuff)
        {
            # Delete the resource from the ConfigMgr site server
            $resource.Delete()
        }
    }
}

# Purpose: This function looks up the site code for the SMS Provider, given a server name
function GetSiteCode($tSiteServer)
{
    # Dynamically obtain SMS provider location based only on server name
    $tSiteCode = (Get-WmiObject -ComputerName $tSiteServer -Class SMS_ProviderLocation -Namespace rootsms).NamespacePath
    # Return only the last 3 characters of the NamespacePath property, which indicates the site code
    return $tSiteCode.SubString($tSiteCode.Length - 3).ToLower()
}

# This function logs a message to the console and a log file.
# Params:
#    $tMessage = A string representing the message to be logged to the file & console
#    $Severity = A integer from 1-3 representing the severity of the message: Info, Warning, Error
function LogMessage(${tMessage}, ${Severity})
{
    switch(${Severity})
    {
        1 {
            $LogPrefix = "INFO"
            $fgcolor = [ConsoleColor]::Blue
            $bgcolor = [ConsoleColor]::White
        }
        2 {
            $LogPrefix = "WARNING"
            $fgcolor = [ConsoleColor]::Black
            $bgcolor = [ConsoleColor]::Yellow
        }
        3 {
            $LogPrefix = "ERROR"
            $fgcolor = [ConsoleColor]::Yellow
            $bgcolor = [ConsoleColor]::Red
        }
        default {
            $LogPrefix = "DEFAULT"
            $fgcolor = [ConsoleColor]::Black
            $bgcolor = [ConsoleColor]::White
        }
    }

    if ($Debug)
    {
        Add-Content -Path "AD-Workstation-Cleanup.log" -Value "$((Get-Date).ToString()) ${LogPrefix}: ${tMessage}"
        Write-Host -ForegroundColor $fgcolor -BackgroundColor $bgcolor -Object "$((Get-Date).ToString()) ${LogPrefix}: ${tMessage}"
    }
}

function Main()
{
    Clear-Host
    LogMessage "Beginning workstation account cleanup script" 1

    # Retrieve SCCM site code from site server specified by user
    $Global:SccmSiteCode = GetSiteCode $SccmServer


    LogMessage "Completed workstation account cleanup script" 1
}

Main