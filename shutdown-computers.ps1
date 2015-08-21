# generate the secure password only needs to be done once.
#read-host -assecurestring | convertfrom-securestring | out-file c:\01data\nathan-password.txt
$password = Get-Content c:\01data\nathan-password.txt | ConvertTo-SecureString
# Do RPC Server Connection Check / ICMP Check if it fails skip action/supress error

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

# DOWN BORG
$hostname = "borg"
$PingServer = Test-Connection -count 1 $hostname -quiet
if ($PingServer -eq $True)
{
write-host $hostname is UP
$credentials = New-Object -typename System.Management.Automation.PSCredential -argumentlist "BORG\nathan",$password
Stop-Computer -ComputerName "borg" -Credential $credentials -force
}
if ($PingServer -eq $False)
{
write-host $hostname is Already DOWN
}

# DOWN LEFTY
$hostname = "lefty"
$PingServer = Test-Connection -count 1 $hostname -quiet
if ($PingServer -eq $True)
{
write-host $hostname is UP
$credentials = New-Object -typename System.Management.Automation.PSCredential -argumentlist "lefty\nathan",$password
Stop-Computer -ComputerName "lefty" -Credential $credentials -force
}
if ($PingServer -eq $False)
{
write-host $hostname is Already DOWN
}
