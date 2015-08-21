# Globals for this Script.
$username = "u60890" # it's a Unix Credential for Splunk
$password = cat C:\Scripts\Credentials\u60890_splunk_password.txt | convertto-securestring
$splunk_credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
# Globals to Merge in the Include Files
$unique_title = "Splunk Error Events"
$users = "nathan.keogh@ga.gov.au" # List of users to email your report to (separate by comma)
$fromemail = "SplunkErrorEvents.WIN-Script1@ga.gov.au"
# Include our eMail Template file
#Include "C:\scripts\ps1\Check-Daily\include_GA_Notify_eMail.ps1"
# These Should be Common to all GA Midrange eMail Reports
$server = "exmail.ga.gov.au" #enter your own SMTP server DNS name / IP address here

$HTML_Report_HEAD = "
<html>
<head>
<title>GA MidRange - $unique_title</title>
<style>
<!--
body { font-family: Tahoma; font-size: 18px}

#report { width: 835px; }

table{
	border-collapse: collapse;
	border: none;
	font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
	color: black;
	margin-bottom: 10px;
}

    table td{
    font-family: Tahoma; 
    font-size: 18px
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
"


# Assemble the closing HTML for our report.
$HTML_Report_End = @"
</div>
</body>
</html>
"@

# The HTML Body that is needed for this Script
$HTML_Report_BODY = "
<body>
<H1 Align=`"Center`"><B>$unique_title Report at $(Get-Date)</B></H1>
<table BORDER=`"2`" CELLPADDING=`"5`" Align=`"Center`">
<tr>
	<td BGColor=White Align=center><b>Server Name</b></td>
	<td BGColor=White Align=center><b>Event Recorded</b></td>
	<td BGColor=White Align=center><b>Code</b></td>
	<td BGColor=White Align=center><b>Source</b></td>
</tr>"

# Script Specifics
Import-Module Splunk
# 2 Disable Valid SSL Cert Requirement
Disable-CertificateValidation
# Note Secure String is Tied to User Account.
#Read-Host -assecurestring | Convertfrom-Securestring | Out-File C:\Scripts\Credentials\u60890_splunk_password.txt
# Connect
Connect-Splunk -ComputerName 10.7.70.174 -Credential $splunk_credentials
# Look For Event Log Started EventID Most Common Cause is a Machine Restart
$splunk_search_query = 'index=windows source=wineventlog:Application "User=SYSTEM" "Type=Error" NOT "SourceName=McLogEvent" NOT "SourceName=UserEnv" earliest_time=-18h | table ComputerName,_time,EventCode,Type,SourceName,Message SORT ComputerName,EventCode'
Search-Splunk –Search 'index=windows source=wineventlog:Application "User=SYSTEM" "Type=Error" NOT "SourceName=McLogEvent" NOT "SourceName=UserEnv" earliest_time=-24h | table ComputerName,_time,EventCode,Type,SourceName,Message SORT ComputerName,EventCode' | Format-List ComputerName,Date,EventCode,SourceName,Message | Out-File "C:\Health\Splunk-Searches\errors-last-18-hours.txt" -encoding ascii -force
# Use a VBS Script to Strip the Splunk Search Return. its Argument is the File to Process. (it's output file goes to same folder)
$_,$(cscript.exe //nologo "C:\Scripts\VBS\strip-noisy-splunk-lines2.vbs" "C:\Health\Splunk-Searches\errors-last-18-hours.txt" $_) 
# Now we Take the Simple File and Make an Array for Adding to an eMail
# assume none (Optimist)
$reportingCount = 0

# a Tab Separated CSV file or .TSV file should still open in Excel
#ComputerName	EventDate	EventCode	SourceName	Message
$events_splunked = import-csv -path "C:\Health\Splunk-Searches\errors-last-18-hours.tsv" -delimiter "`t"
#$events_splunked | Out-GridView
foreach ($objEvent in $events_splunked) {
    $reportingCount ++
    $nowrap_message = $($objEvent.Message) -replace ":::", ""
    $Event_HTML += "<tr><td>$($objEvent.ComputerName)</td><td>$($objEvent.EventDate)</td><td>$($objEvent.EventCode)</td><td>$($objEvent.SourceName)</td></tr><tr><td colspan='4'>$nowrap_message</td></tr>"
}

# Append to the HTML BODY 
$HTML_Report_BODY += $Event_HTML
# Assemble the final report from all our HTML sections
$Entire_HTML = $HTML_Report_HEAD + $HTML_Report_BODY + $HTML_Report_End

# Finish our eMail Block Code Now
$todayString = Get-Date -uformat "%Y-%m-%d"
$Entire_HTML | Out-File "C:\Health\Reports\Splunk-Filtered-Errors\$todayString.html"
# Email our report out
# Only Send if 1 or more would be in the Report
if ($reportingCount -gt 0) {
send-mailmessage -from $fromemail -to $users -subject "$unique_title Report" -BodyAsHTML -body $Entire_HTML -priority Normal -smtpServer $server
}