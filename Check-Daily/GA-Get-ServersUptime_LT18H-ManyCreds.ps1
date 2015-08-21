<#
HardCoded Paths
Inline Style Sheet
#>

$users = "nathan.keogh@ga.gov.au" # List of users to email your report to (separate by comma)
$fromemail = "UptimeReports.WIN-Script1@ga.gov.au"
$server = "exmail.ga.gov.au" #enter your own SMTP server DNS name / IP address here


$Computers = Get-Content "C:\Health\TRIM-MasterList.txt"

# <td BGColor=Yellow Align=center><b>S. No</b></td>
$Report = "
<html>
<head>
<title>GA MidRange - Server Uptime Report</title>
<style>
body { font-family: Tahoma; font-size: 18px}
td { font-family: Tahoma; font-size: 18px}

td.ok { border-bottom: green solid thin; border-top: green solid thin; border-left: none; border-right: none; color:white; background-color:green; }
td.warning { color:white; background-color:blue; }
td.error { font-weight: bold; font-size: 24px; color:white; background-color:red; }
td.amber { font-weight: normal; color:white; background-color:orange; }

</style>
</head>
<body>
<H1 Align=`"Center`"><B>Server Uptime Report at $(Get-Date)</B></H1>
<table BORDER=`"2`" CELLPADDING=`"5`" Align=`"Center`">
<tr>
	<td BGColor=White Align=center><b>Server Name</b></td>
	<td BGColor=White Align=center><b>Can Connect</b></td>
	<td BGColor=White Align=center><b>Uptime Returns</b></td>
</tr>"
 
$Count=0
$SuccessComps = 0
$WarningComps = 0 # machines up for less than 1 day are suspicious
$UnreachableComps = 0
$FailedComps = 0
$FinalOutput = @()

foreach($Computer in $Computers) {
	$Count++
	$Computer = $Computer.Toupper()
	$OutputObj = New-Object -TypeName PSobject
	$OutputObj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Computer
	$Status = 0
	if(Test-Connection -Computer $Computer -count 1 -ea 0) {
		$OutputObj | Add-Member -MemberType NoteProperty -Name IsOnline -Value "TRUE"
		try {
            # Connect with Pass Through Credentials ie the Service Account.
			$Boottime = (Get-WmiObject win32_operatingSystem -computer $Computer -ErrorAction stop).lastbootuptime
			$Boottime = [System.Management.ManagementDateTimeconverter]::ToDateTime($BootTIme)
			$Now = Get-Date
			$span = New-TimeSpan $BootTime $Now
			$Uptime = "{0} day(s) {1} hour(s) {2} min(s) [$BootTime]" -f $span.days, $span.hours, $span.minutes, $span.seconds
			$OutputObj | Add-Member -MemberType NoteProperty -Name Uptime -Value $Uptime
	        # Check for Machines with Uptimes of less than 18 hours ie days = 0 and hours < 19
	        if ($span.days -eq 0 -and $span.hours -lt 19) {
		
		        $Status="warning"
		        $WarningComps++
	        } else {
		        $Status="ok"              
		        $SuccessComps++                
	        }
		} catch {
			$OutputObj | Add-Member -MemberType NoteProperty -Name Uptime -Value "FAILED TO GET"
			$Status="error"                              
			$FailedComps++
		}

	} else {
		$Status="amber"
		$OutputObj | Add-Member -MemberType NoteProperty -Name IsOnline -Value "FALSE"
		$OutputObj | Add-Member -MemberType NoteProperty -Name Uptime -Value ""
		$UnreachableComps++
	}
	
$FinalOutput +=$OutputObj
		
$OutputObj

# return the status as the Background Colour
$td_style=$Status
$Report += "<TR>
<TD class='$td_style'>$($OutputObj.ComputerName)</TD>
<TD class='$td_style'>$($OutputObj.IsOnline)</TD>
<TD class='$td_style'>$($OutputObj.Uptime)</TD>
</TR>"
	
}
$Report +="</table>
				<br>
				<h3>Report Summary:</h3>
				<table>
				<tr>
					<td>Total No. of Computers scanned</td>
					<td>: $Count</td>
				</tr>
	<tr>
				<td>No. Of computers online</td>
				<td>: $SuccessComps</td>
			 </tr>
	<tr>
				<td>Uptime Less than 18 hours</td>
				<td>: $WarningComps</td>
			 </tr>
			  <tr>
				<td>No. Of computers Offline</td>
				<td>: $UnreachableComps</td>
			 </tr>
			 <tr>
				<td>No. Of computers Failed to query</td>
				<td>: $FailedComps</td>
			 </tr>
			 </table>
	</body>
	</html>
				"			
$todayString = Get-Date -uformat "%Y-%m-%d"
$HTMLFile = "C:\Health\Reports\Uptime\Uptime_$todayString.html"
# Export the Daily Report
$Report | Out-File $HTMLFile -Force

# Send the Mail
# we send always even if all Machines are OK
send-mailmessage -from $fromemail -to $users -subject "GA MidRange Uptime Report" -BodyAsHTML -body $Report -priority Low -smtpServer $server