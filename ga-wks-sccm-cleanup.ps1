$SccmServer = 'sccm1' # The server on which your SMS Provider component is installed
$BreakStuff = $false # If set to $true, the script WILL TAKE ACTION!
$Debug = $true # Enables additional logging to file and stdout

# Purpose: This function deletes a resource from the Configuration Manager database
function RemoveFromSccm($tPcName)
{
    $tSysQuery = "select * from SMS_R_System where Name = '$tPcName'"
    $tWmiNs = "rootsmssite_" + 'GA1'
    if ($Debug)
    {
        LogMessage "Site code is: GA1" 1
        LogMessage $tSysQuery 1
        LogMessage "tSiteServer is: SCCM1" 1
        LogMessage "tWmiNs is: $tWmiNs" 1
    }
    $Resources = Get-WmiObject -ComputerName SCCM1 -Namespace $tWmiNs -Query $tSysQuery

    if ($Resources -eq $null) { return; }

    foreach ($Resource in $Resources)
    {
        $AgentTime = $($Resource.AgentTime | Sort-Object | Select-Object -Last 1)
        $UserName = $Resource.LastLogonUserDomain + '' + $Resource.LastLogonUserName
        # Log the deleted SCCM resource to the Excel log
        LogMessage "$Resource.ResourceID $Resource.Name $AgentTime $UserName" 1
        # This line deletes records from the ConfigMgr database
        if ($BreakStuff)
        {
            # Delete the resource from the ConfigMgr site server
            $resource.Delete()
        }
    }
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
        Add-Content -Path "SCCM-Workstation-Cleanup.log" -Value "$((Get-Date).ToString()) ${LogPrefix}: ${tMessage}"
        Write-Host -ForegroundColor $fgcolor -BackgroundColor $bgcolor -Object "$((Get-Date).ToString()) ${LogPrefix}: ${tMessage}"
    }
}

# Iterate the Users Text File
$computerlist = Get-content C:\cache\delete-computer-accounts.txt
Foreach($computername in $computerlist)
{
    RemoveFromSccm($computername)
}