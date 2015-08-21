#region Variables and Arguments
$toemail="Nathan Keogh <nathan.keogh@ga.gov.au>","James Black <james.black@ga.gov.au>" # List of users to email your report to (separate by comma and quote the whole recipient may also be "Nathan <nathan.keogh@ga.gov.au")
$fromemail = "vSphereChecks.WIN-Script1@ga.gov.au"
$server = "exmail.ga.gov.au" #enter your own SMTP server DNS name / IP address here

$CurrentTime = Get-Date
$date = get-date -format dd-MM-yyyy
#endregion

# Assemble the HTML Header and CSS for our Report
$HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>GA Daily Check - C Drive 25+ percent free (ie check all)</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}

    table{
	border-collapse: collapse;
	border: none;
	font: 14pt Verdana, Geneva, Arial, Helvetica, sans-serif;
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

.Error {color:#FF0000;font-weight: bold;}
.Title {background: #0077D4;color: #FFFFFF;text-align:center;font-weight: bold;}
.Normal {}

</style>
</head>
<body>
<h2>VMware Consolidation Report $date</h2>
<table><tr class=""Title""><td colspan=""6""></td></tr><tr class="Title"><td>VM Name</td></tr>
"@

# Assemble the closing HTML for our report.
$HTMLEnd = @"
</table>
</body>
</html>
"@

$reportingCount = 0

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Connect to vSphere (NOTE all PowerCLI Code must be Peer Reviewed by the Virtualisation TEAM)
# NO MODIFY CODE IS APPROVED AT THIS TIME, only Query, Reporting Actions to be used.
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Add-PSSnapin VMware.VimAutomation.Core
$VC1 = "WIN-VCENTER"
Connect-VIServer -Server $VC1
#-WarningAction SilentlyContinue
# -user $username -password $password

# Get the Snapshots needing Consolidating.
$VMsWithSnaps = Get-VM | where {$_.ExtensionData.Runtime.consolidationNeeded} | Select Name 

Foreach ($snapshot in $VMsWithSnaps){
	$reportingCount++
	Write-Output "$snapshot.Name - Has Disks Needing Consolidation"
	$HTMLMiddle += "<tr><td>$($snapshot.Name)</td></tr>"
}

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Assemble the final report from all our HTML sections
$HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
# File Friendly TimeStamp Date Only
$todayString = Get-Date -uformat "%Y-%m-%d"
$HTMLmessage | Out-File "C:\Health\Reports\vSphere-Consolidation\Needing_$todayString.html"
# Email our report out
# Only Send if 1 or more would be in the Report
if ($reportingCount -gt 0) {
send-mailmessage -from $fromemail -to $toemail -subject "$reportingCount Disks Needing Consolidation" -BodyAsHTML -body $HTMLmessage -priority Low -smtpServer $server
}