##############################################################################
#
# Author: Trevor Sullivan
#
# Date: October 28, 2009
#
# Lessons learned:
#
# 1. ADSI property names are lower case using DirectorySearcher or DirectoryEntry
# 2. Must explicitly cast 64-bit integers from AD
# 3. The Excel API is terrible (already knew that)
#
#
# Change Log:
#    2009-11-06
#        -Added: function to delete objects from SCCM (untested)
#        -Added: User variables at top of script to ease usage
#        -Added: function to auto-detect SCCM site code, based on server name
#        -Added: Windows Vista accounts to search criteria
#        -Fixed: Replaced -bxor operator with -bor to prevent computer accounts
#                from being re-enabled
#        -Fixed: Casted [void] from loading Excel Interop assembly to prevent
#                Assembly object from being written to pipeline
#
##############################################################################


### Populate these variables please. ###
$ExcelLog = $Env:USERPROFILE + '' + (Get-Date).ToString().Replace("/","-").Replace(":","") + " AD Workstation Cleanup.xlsx" # Full path to save Excel log to
$TargetDn = 'cn=computers,dc=ts,dc=loc' # Top-level distinguishedName 
$DisabledDn    = 'ou=Disabled,ou=Workstations,dc=ts,dc=;pc' # OU to place disabled accounts into
$DisableAge = 60 # Age (in days) of computer account, to be disabled
$DeleteAge = 30 # Age of computer account (<DisabledDate> + X) to delete computer accounts
$SccmServer    = 'sccm01' # The server on which your SMS Provider component is installed
$BreakStuff = $false # If set to $true, the script WILL TAKE ACTION!
$Debug = $false # Enables additional logging to file and stdout
###  ### ############################# ###  ###

function DisableOldAccounts(${TargetDn}, ${DisableAge} = 60)
{
    ${Computers} = GetComputerList ${TargetDn}

    foreach (${Computer} in ${Computers})
    {
        # PwdLastSet is a 64-bit integer that indicates the number of 100-nanosecond intervals since 12:00 AM January 1st, 1601
        # The FromFileTime method converts a 64-bit integer to datetime
        # http://www.rlmueller.net/Integer8Attributes.htm
        ${PwdLastSet} = [DateTime]::FromFileTime([Int64]"$(${Computer}.Properties['pwdlastset'])")
        ${CompAge} = ([DateTime]::Now - $PwdLastSet).Days
        if (${CompAge} -gt ${DisableAge})
        {
            LogMessage "$($Computer.Properties['cn']) age is ${CompAge}. Account will be disabled" 2
            WriteDisabledEntry $Computer.Properties['cn'].Item(0) $CompAge $Computer.Properties['distinguishedname'].Item(0) $DisabledDn
            DisableAccount $Computer.Properties['distinguishedname'].Item(0)
        }
        else
        {
            LogMessage "$($Computer.Properties['cn'].Item(0)) age is ${CompAge}, $($Computer.Properties['pwdlastset'].Item(0)), ${PwdLastSet}" 1
        }
    }
}

# Gets a full list of computer accounts from the target distinguishedName defined at the top of the script
function GetComputerList($TargetDn)
{
    # Define the LDAP search syntax filter to locate workstation objects.
    # See this link for info: http://msdn.microsoft.com/en-us/library/aa746475(VS.85).aspx
    ${tFilter} = '(&(objectClass=computer)(|(operatingSystem=Windows 2000 Professional)(operatingSystem=Windows XP*)(operatingSystem=*Vista*)(operatingSystem=Windows 7*)))'

    # Create a DirectorySearcher using filter defined above
    ${Searcher} = New-Object System.DirectoryServices.DirectorySearcher $tFilter
    # Set the search root to the distinguishedName specified in the function parameter
    ${Searcher}.SearchRoot = "LDAP://${TargetDn}"
    # Search current container and all subcontainers
    ${Searcher}.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
    # See this link for info on why this next line is necessary: http://www.eggheadcafe.com/software/aspnet/32967284/searchall-in-ad-ldap-f.aspx
    ${Searcher}.PageSize = 1000
    $Results = $Searcher.FindAll()
    LogMessage "Found $($Results.Count) computer accounts to evaluate for disablement" 1
    return $Results
}

# Set description on computer account, disable it, and move it to the Disabled OU
function DisableAccount($dn)
{
#    LogMessage "DisableAccount method called with param: ${dn}" 1
    # Get a reference to the object at <distinguishedName>
    $comp = [adsi]"LDAP://${dn}"
    # Disable the account
#    LogMessage "userAccountControl ($($comp.Name)) is: $($comp.userAccountControl)"
    $comp.userAccountControl = $comp.userAccountControl.Value -bor 2
    # Write the current date to the description field
    if ($comp.Description -ne '') { LogMessage "Description attribute of ($comp.Name) is set to: $($comp.Description)" 2 }
    $comp.Description = "$(([DateTime]::Now).ToShortDateString())"

    # Uncomment these lines to write changes to Active Directory
    if ($BreakStuff)
    {
        [Void] $comp.SetInfo()
        $comp.psbase.MoveTo("LDAP://${DisabledDn}")
    }
}

# Parameter ($DeleteAge): Days from disable date to delete computer account
function DeleteDisabledAccounts($DeleteAge)
{
    # Get reference to OU for disabled workstation accounts
    ${DisabledOu} = [adsi]"LDAP://${DisabledDn}"

    ${Searcher} = New-Object System.DirectoryServices.DirectorySearcher '(objectClass=computer)'
    ${Searcher}.SearchRoot = ${DisabledOu}
    ${Searcher}.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
    # Page size is used to return result count > default size limit on domain controllers.
    # See: http://geekswithblogs.net/mnf/archive/2005/12/20/63581.aspx
    ${Searcher}.PageSize = 1000
    LogMessage "Finding computers to evaluate for deletion in container: ${DisabledDn}" 1
    ${Computers} = ${Searcher}.FindAll()

    foreach (${Computer} in ${Computers})
    {
        ${DisableDate} = [DateTime]::Parse(${Computer}.Properties['description'])
        trap {
            LogMessage "Couldn't parse date for $($Computer.Properties['cn'])" 3
            continue
        }
        ${CurrentAge} = ([DateTime]::Now - ${DisableDate}).Days
        if (${CurrentAge} -gt ${DeleteAge})
        {
            LogMessage "$(${Computer}.Properties['cn']) age is ${CurrentAge} and will be deleted" 2
            WriteDeletedEntry $Computer.Properties['cn'].Item(0) $CurrentAge $Computer.Properties['distinguishedname'].Item(0) "Note"
            if ($BreakStuff)
            {
                $DisabledOu.Delete('computer', 'CN=' + ${Computer}.Properties['cn'])
            }
            RemoveFromSccm ${Computer}.Properties['cn'] $SccmServer
        }
        else
        {
            LogMessage "$(${Computer}.Properties['cn']) age is ${CurrentAge} and will not be deleted" 1
        }
    }
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

function SetupExcel()
{
    LogMessage "Setting up Excel logging" 1
    [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Office.Interop.Excel")
    $Global:Excel = New-Object Microsoft.Office.Interop.Excel.ApplicationClass
    $Excel.Visible = $true
    $Global:Workbook = $Excel.Workbooks.Add()

    # Setup worksheet for deleted SCCM resource records
    $Global:SccmResourceLog = $Workbook.Worksheets.Item("Sheet3")
    $SccmResourceLog.Name = "SCCM Resources"
    $SccmResourceLog.Tab.ThemeColor = [Microsoft.Office.Interop.Excel.XlThemeColor]::xlThemeColorAccent3
    $SccmResourceLog.Cells.Item(1, 1).Value2 = "Date"
    $SccmResourceLog.Cells.Item(1, 2).Value2 = "Resource ID"
    $SccmResourceLog.Cells.Item(1, 3).Value2 = "Name"
    $SccmResourceLog.Cells.Item(1, 4).Value2 = "Last Agent Time"
    $SccmResourceLog.Cells.Item(1, 5).Value2 = "Username"
    $Global:tSccmResRow = 2

    # Setup worksheet for disabled accounts
    $Global:DisabledLog = $Workbook.Worksheets.Item("Sheet2")
    $DisabledLog.Tab.ThemeColor = [Microsoft.Office.Interop.Excel.XlThemeColor]::xlThemeColorAccent2
    $DisabledLog.Name = "Disabled"
    $DisabledLog.Cells.Item(1, 1).Value2 = "Date"
    $DisabledLog.Cells.Item(1, 2).Value2 = "Name"
    $DisabledLog.Cells.Item(1, 3).Value2 = "Age"
    $DisabledLog.Cells.Item(1, 4).Value2 = "Source Container"
    $DisabledLog.Cells.Item(1, 5).Value2 = "Destination Container"
    $Global:tDisabledRow = 2

    # Setup worksheet for deleted accounts log
    $Global:DeletedLog = $Workbook.Worksheets.Item("Sheet1")
    $DeletedLog.Tab.ThemeColor = [Microsoft.Office.Interop.Excel.XlThemeColor]::xlThemeColorAccent5
    $DeletedLog.Name = "Deleted"
    $DeletedLog.Cells.Item(1, 1).Value2 = "Date"
    $DeletedLog.Cells.Item(1, 2).Value2 = "Name"
    $DeletedLog.Cells.Item(1, 3).Value2 = "Age"
    $DeletedLog.Cells.Item(1, 4).Value2 = "DN"
    $DeletedLog.Cells.Item(1, 5).Value2 = "Note"
    $Global:tDeletedRow = 2
}

# Writes an entry to the global variable used to reference the log for disabled accounts
function WriteDisabledEntry([string] $tName, $tAge, [string] $tSourceDn, [string] $tDestinationDn)
{
    #LogMessage "Writing disabled computer to Excel log: $tName" 1
    #Write-Host "Value of tname is $tName"
    #Write-Host "Value of tage is $tAge"
    #Write-Host "Value of tsourcedn is $tSourceDn"
    #Write-Host "Value of tDestinationDn is $tDestinationDn"
    $tArrContainer = $tSourceDn.Split(",")
    $tContainer = [string]::Join(",", ($tArrContainer | select -Last ($tArrContainer.Length - 1)))
    $DisabledLog.Cells.Item($tDisabledRow, 1).Value2 = [DateTime]::Now.ToString()
    $DisabledLog.Cells.Item($tDisabledRow, 2).Value2 = $tName
    $DisabledLog.Cells.Item($tDisabledRow, 3).Value2 = $tAge
    $DisabledLog.Cells.Item($tDisabledRow, 4).Value2 = $tContainer
    $DisabledLog.Cells.Item($tDisabledRow, 5).Value2 = $tDestinationDn
    $Global:tDisabledRow++
}

# Writes an entry to the global variable used to reference the log for deleted accounts 
function WriteDeletedEntry($tName, $tAge, $tDN, $tNote)
{
    #LogMessage "Writing deleted computer to Excel log: $tName" 1
    #Write-Host "Value of tName is $tName"
    #Write-Host "Value of tAge is $tAge"
    #Write-Host "Value of tDN is $tDN"
    #Write-Host "Value of tNote is $tNote"
    $DeletedLog.Cells.Item($tDeletedRow,1).Value2 = [DateTime]::Now.ToString()
    $DeletedLog.Cells.Item($tDeletedRow,2).Value2 = $tName.ToString()
    $DeletedLog.Cells.Item($tDeletedRow,3).Value2 = $tAge.ToString()
    $DeletedLog.Cells.Item($tDeletedRow,4).Value2 = $tDN.ToString()
    $DeletedLog.Cells.Item($tDeletedRow,5).Value2 = $tNote.ToString()
    $Global:tDeletedRow++
    return
}

function WriteSccmDeletionEntry($tResourceId, $tName, $tLastAgentTime, $tUserName)
{
    $SccmResourceLog.Cells.Item($tSccmResRow, 1).Value2 = [DateTime]::Now.ToString()
    $SccmResourceLog.Cells.Item($tSccmResRow, 2).Value2 = $tResourceId
    $SccmResourceLog.Cells.Item($tSccmResRow, 3).Value2 = $tName
    $SccmResourceLog.Cells.Item($tSccmResRow, 4).Value2 = $tLastAgentTime
    $SccmResourceLog.Cells.Item($tSccmResRow, 5).Value2 = $tUserName
    $Global:tSccmResRow++
    return
}

function CloseExcel()
{
    # AutoFit the columns

    foreach ($tSheet in $Workbook.Worksheets)
    {
        $tSheet.Activate()
        [Void] $Excel.ActiveCell.CurrentRegion.Columns.AutoFit()
        [Void] $Excel.ActiveCell.CurrentRegion.Select()
        $Global:ListObject = $Excel.ActiveSheet.ListObjects.Add([Microsoft.Office.Interop.Excel.XlListObjectSourceType]::xlSrcRange, $Excel.ActiveCell.CurrentRegion, $null ,[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes)
        $ListObject.Name = "TableData"
        $ListObject.TableStyle = "TableStyleLight9"
    }

    LogMessage "Saving and closing Excel workbook" 1
    $Global:Workbook.SaveAs($ExcelLog)
    $Global:Excel.Quit()
}

function Main()
{
    Clear-Host
    LogMessage "Beginning workstation account cleanup script" 1

    # Retrieve SCCM site code from site server specified by user
    $Global:SccmSiteCode = GetSiteCode $SccmServer

    # Setup Excel logging
    SetupExcel

    # Delete accounts that have been disabled for X days
    DeleteDisabledAccounts $DeleteAge

    # Disable accounts that are older than X days
    DisableOldAccounts $TargetDn $DisableAge

    CloseExcel
    LogMessage "Completed workstation account cleanup script" 1
}

Main