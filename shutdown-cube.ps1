# generate the secure password only needs to be done once.
#read-host -assecurestring | convertfrom-securestring | out-file c:\01data\nathan-password.txt
$password = Get-Content c:\01data\nathan-password.txt | ConvertTo-SecureString
# Do RPC Server Connection Check / ICMP Check if it fails skip action/supress error

# DOWN CUBE
$hostname = "CUBE"
$PingServer = Test-Connection -count 1 $hostname -quiet
if ($PingServer -eq $True)
{
write-host $hostname is UP
$credentials = New-Object -typename System.Management.Automation.PSCredential -argumentlist "CUBE\nathan",$password
Stop-Computer -ComputerName "cube" -Credential $credentials -force
}
if ($PingServer -eq $False)
{
write-host $hostname is Already DOWN
}

pause