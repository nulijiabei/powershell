#region Variables and Arguments
$users = "nathan.keogh@ga.gov.au" # List of users to email your report to (separate by comma)
$fromemail = "HealthCheck@ga.gov.au"
$server = "exmail.ga.gov.au" #enter your own SMTP server DNS name / IP address here
$list = $args[0] #This accepts the argument you add to your scheduled task for the list of servers. i.e. list.txt
$computers = get-content $list #grab the names of the servers/computers to check from the list.txt file.
# Set free disk space threshold below in percent (default at 10%)
$thresholdspace = 99
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
<html><head><title>GA Daily Check - C Drive 99 percent free (ie check all)</title>
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
<p>Drive(s) listed below have less than $thresholdspace % free space. Drives above this threshold will not be listed.</p>
"@

foreach ($computer in $computers) {

	# check for an Error Return and skip to next item in file.
    $CanWMIConnect = Check-WmiObject -NameSpace "root\cimv2" -WmiHost $computer
    if (!$CanWMIConnect) {
    	Write-Warning "Wmi Object is not Connecting on Host $computer"
        continue # skip to Next Item in File
    }

	$DiskInfo=Get-WMIObject -ComputerName $computer Win32_LogicalDisk | Where-Object{$_.DeviceID -eq "C:"} | Where-Object{ ($_.freespace/$_.Size)*100 -lt $thresholdspace} `
	| Select-Object SystemName, VolumeName, Name, @{n='Size (GB)';e={"{0:n2}" -f ($_.size/1gb)}}, @{n='FreeSpace (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}}, @{n='PercentFree';e={"{0:n2}" -f ($_.freespace/$_.size*100)}} | ConvertTo-HTML -fragment

    # Debug Output for Testing.
	#Write-Output for $computer $DiskInfo.Length -DiskInfo- $DiskInfo

#	if ($DiskInfo -ne "<table>\n</table>") {
	if ($DiskInfo.Length -gt 2) {
	    Write-Output "Addding $computer to Report"
#	if ($DiskInfo -match "<table>\n</table>") {
# Create HTML Report for the current System being looped through assuming it has something to Say about Disk Free Threshold Condition Being Met.
$CurrentSystemHTML = @"
<hr noshade size="1" width="100%">
<div id="report">
<p><h2>$computer Report</p></h2>
<table class="list">
</table>			
<table class="normal">$DiskInfo</table>
<br></br>
"@
} else {
    Write-Output "Not Addding $computer to Report"
    $CurrentSystemHTML = ""
}
	# Add the current System HTML Report into the final HTML Report body
	$HTMLMiddle += $CurrentSystemHTML
}

# Assemble the closing HTML for our report.
$HTMLEnd = @"
</div>
</body>
</html>
"@

# Assemble the final report from all our HTML sections
$HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
# Save the report out to a file in the current path
$HTMLmessage | Out-File ((Get-Location).Path + "\disk-c-99-check.html")
# Email our report out
#send-mailmessage -from $fromemail -to $users -subject "Systems Report" -Attachments $ListOfAttachments -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer $server
#send-mailmessage -from $fromemail -to $users -subject "Systems Report" -BodyAsHTML -body $HTMLmessage -priority Normal -smtpServer $server
