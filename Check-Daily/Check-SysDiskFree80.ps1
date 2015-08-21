#$toemail="Nathan Keogh <nathan.keogh@ga.gov.au>" # List of users to email your report to (separate by comma and quote the whole recipient may also be "Nathan <nathan.keogh@ga.gov.au")
$toemail="Nathan Keogh <nathan.keogh@ga.gov.au>","Angelo Pace <angelo.pace@ga.gov.au>","Alex Contreras <alex.contreras@ga.gov.au>","Nicholas Nearchou <nicholas.nearchou@ga.gov.au>","Derick Cook <derick.cook@ga.gov.au>"
#$toemail="Nathan Keogh <nathan.keogh@ga.gov.au>","Angelo Pace <angelo.pace@ga.gov.au>","Alex Contreras <alex.contreras@ga.gov.au>","Nicholas Nearchou <nicholas.nearchou@ga.gov.au>","Derick Cook <derick.cook@ga.gov.au>"
#$toemail="Nathan Keogh <nathan.keogh@ga.gov.au>","Angelo Pace <angelo.pace@ga.gov.au>" # List of users to email your report to (separate by comma and quote the whole recipient may also be "Nathan <nathan.keogh@ga.gov.au")
$fromemail = "SysDisk20.WIN-Script1@ga.gov.au"
$server = "exmail.ga.gov.au" #enter your own SMTP server DNS name / IP address here
$list = "C:\Health\TRIM-Masterlist.txt" #This accepts the argument you add to your scheduled task for the list of servers. i.e. list.txt
#$list = "C:\Health\TRIM-MasterList-1-of-each-disk.txt" # to Test small set
$computers = get-content $list #grab the names of the servers/computers to check from the list.txt file.
# Set free disk space threshold below in percent (default at 10%)
$thresholdspace = 20
#$thresholdspace = 99 # to force a chack on every server
$ListOfAttachments = @()
$Report = @()
$CurrentTime = Get-Date
#endregion

# http://www.yusufozturk.info/windows-server/how-to-check-wmi-object-with-powershell.html
function Check-WmiObject
{
param (
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Wmi NameSpace. Example: root\virtualization')]
    [string]$NameSpace,
 
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Name of the Wmi Host. Example: Server01')]
    [string]$WMIHost
)
 
    $Success = "1";
    $CheckWmiObject = Get-WmiObject -Computer "$WMIHost" -Namespace "$NameSpace" -List -EA SilentlyContinue
    if (!$CheckWmiObject)
    {
        #Write-Error "Could not contact to Wmi Provider NameSpace $NameSpace on $WMIHost" 
    }
    else
    {
        #Write-Output "Wmi Provider NameSpace $NameSpace is available on $WMIHost"
        $Success
    }
}

# Assemble the HTML Header and CSS for our Report
$HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>GA Daily Check - C Drive 20+ percent free (ie check all)</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}
    #report { width: 835px; }

    table{
	border-collapse: collapse;
	border: none;
	font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
	color: black;
	margin-bottom: 10px;
}

    table td{
	font-size: 12px;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

    table th {
	font-size: 12px;
	font-weight: bold;
	padding-left: 0px;
	padding-right: 20px;
	text-align: left;
}

h2{ clear: both; font-size: 100%; font-weight:bold; color: orange; }

h3{
	clear: both;
	font-size: 115%;
	margin-left: 20px;
	margin-top: 30px;
}

p{ margin-left: 20px; font-size: 12px; }

table.list{ float: left; }

    table.list td:nth-child(1){
	font-weight: bold;
	border-right: 1px grey solid;
	text-align: right;
}

table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #CCCCCC; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px  grey solid; }
div.second{ margin-left: 30px; }
table{ margin-left: 20px; }
-->
</style>
</head>
<body>
<h2>Systems listed below have less than $thresholdspace % free space on C:</h2>
<div id="report">
<table class="normal">
<colgroup><col/><col/><col/><col/></colgroup><tr><th>HostName</th><th>Size (GB)</th><th>FreeSpace (GB)</th><th>`% Free</th></tr>
"@

$reportingCount = 0

foreach ($computer in $computers) {

	# check for an Error Return and skip to next item in file.
    $CanWMIConnect = Check-WmiObject -NameSpace "root\cimv2" -WmiHost $computer
    if (!$CanWMIConnect) {
    	Write-Warning "Wmi Object is not Connecting on Host $computer"
        continue # skip to Next Item in File
    }

    #$DiskInfo = Get-WMIObject -ComputerName $computer Win32_LogicalDisk | Where-Object{$_.DeviceID -eq "C:"} | Where-Object{ ($_.freespace/$_.Size)*100 -lt $thresholdspace} | Select-Object SystemName, @{n='Size (GB)';e={"{0:n2}" -f ($_.size/1gb)}}, @{n='FreeSpace (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}}, @{n='PercentFree';e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | ConvertTo-HTML -fragment
    $DiskInfo = Get-WMIObject -ComputerName $computer Win32_LogicalDisk | Where-Object{$_.DeviceID -eq "C:"} | Where-Object{ ($_.freespace/$_.Size)*100 -lt $thresholdspace} | Select-Object SystemName, @{n='Size (GB)';e={"{0:n2}" -f ($_.size/1gb)}}, @{n='Free Space (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}}, @{n='Percent Free';e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | ConvertTo-HTML -fragment

    # Debug Output for Testing.
	#Write-Output for $computer $DiskInfo.Length -DiskInfo- $DiskInfo
#	if ($DiskInfo -ne "<table>\n</table>") {
	if ($DiskInfo.Length -gt 2) {
	    Write-Output "Addding $computer to Report"
        $reportingCount ++
#	if ($DiskInfo -match "<table>\n</table>") {
# Create HTML Report for the current System being looped through assuming it has something to Say about Disk Free Threshold Condition Being Met.
	$CurrentSystemHTML = $DiskInfo
} else {
    Write-Output "Not Addding $computer to Report"
    $CurrentSystemHTML = ""
}
	# Add the current System HTML Report into the final HTML Report body
	$HTMLMiddle += $CurrentSystemHTML
}

# Assemble the closing HTML for our report.
$HTMLEnd = @"
</table>
</div>
</body>
</html>
"@
# Assemble the final report from all our HTML sections
$HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
# File Friendly TimeStamp Date Only
$todayString = Get-Date -uformat "%Y-%m-%d"
$HTMLmessage | Out-File "C:\Health\Reports\Is_C_80_Percent\c-80-check_$todayString.html"
# Email our report out
# Only Send if 1 or more would be in the Report
if ($reportingCount -gt 0) {
send-mailmessage -from $fromemail -to $toemail -subject "C: ($reportingCount) Less Than (20%+) Free Disk (Weekday Check)" -BodyAsHTML -body $HTMLmessage -priority Low -smtpServer $server
}