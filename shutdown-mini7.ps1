# generate the secure password only needs to be done once.
#read-host -assecurestring | convertfrom-securestring | out-file c:\01data\nathan-password.txt
$password = Get-Content c:\01data\nathan-password.txt | ConvertTo-SecureString
# Do RPC Server Connection Check / ICMP Check if it fails skip action/supress error

function Invoke-Standby
{
    &"$env:SystemRoot\System32\rundll32.exe" powrprof.dll,SetSuspendState Standby
}
Set-Alias csleep Invoke-Standby


# DOWN MINI7
$hostname = "mini7"
$PingServer = Test-Connection -count 1 $hostname -quiet
if ($PingServer -eq $True)
{
write-host $hostname is UP
$credentials = New-Object -typename System.Management.Automation.PSCredential -argumentlist "MINI7\nathan",$password
Stop-Computer -ComputerName "mini7" -Credential $credentials -force
}
if ($PingServer -eq $False)
{
write-host $hostname is Already DOWN
}


 