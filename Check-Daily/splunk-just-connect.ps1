# Globals for this Script.
$username = whoami
#write-output $username.Replace("agso\","")
#break
#$username = "u60890" # it's a Unix Credential for Splunk
$credsfile = "C:\Scripts\Credentials\"+$username.Replace("agso\","")+"_splunk_password.txt"
Write-Output $credsfile
$password = cat $credsfile | convertto-securestring
#$splunk_credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
$splunk_credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist "apace", $password
# Globals to Merge in the Include Files
$unique_title = "Splunk Restart Events"
# Script Specifics
Import-Module Splunk
# 2 Disable Valid SSL Cert Requirement
Disable-CertificateValidation
# Note Secure String is Tied to User Account.
#Read-Host -assecurestring | Convertfrom-Securestring | Out-File C:\Scripts\Credentials\u60890_splunk_password.txt
# Connect
Connect-Splunk -ComputerName 10.7.70.174 -Credential $splunk_credentials
# Look For Event Log Started EventID Most Common Cause is a Machine Restart
#Search-Splunk –Search 'index=windows source=wineventlog:Application "User=SYSTEM" "Type=Error" NOT "SourceName=McLogEvent" NOT "SourceName=UserEnv" earliest_time=-18h | table ComputerName,_time,EventCode,Type,SourceName,Message SORT ComputerName,EventCode' | Format-List ComputerName,Date,EventCode,SourceName,Message | Out-File "C:\Health\Splunk-Searches\whoami-errors-last-18-hours.txt" -encoding ascii -force
Search-Splunk –Search 'index=windows LogName=System EventCode=6005 earliest=-1d@d latest=now' | Format-List ComputerName,Date,EventCode,SourceName,Message | Out-File "C:\Health\Splunk-Searches\whoami-errors-last-18-hours.txt" -encoding ascii -force
#index=windows EventCode=6005 earliest=-1d@d latest=now
#Search-Splunk –Search 'index=windows source=wineventlog:Application "User=SYSTEM" "Type=Error" NOT "SourceName=McLogEvent" NOT "SourceName=UserEnv" earliest_time=-18h | table ComputerName,_time,EventCode,Type,SourceName,Message SORT ComputerName,EventCode' | Format-List
