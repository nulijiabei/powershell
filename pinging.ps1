#$ping = new-object system.net.networkinformation.ping
#$pingreturns = $ping.send('192.168.1.5')
#write-host $pingreturns
#Test-Connection lucky7
# Just return true/false
$hostname = "lucky7"
$PingServer = Test-Connection -count 1 $hostname -quiet
#write-host $hostname Connects is $PingServer
if ($PingServer -eq $True)
{
write-host $hostname is UP
}
if ($PingServer -eq $False)
{
write-host $hostname is DOWN
}

$hostname = "mini7"
$PingServer = Test-Connection -count 1 $hostname -quiet
#write-host $hostname Connects is $PingServer
if ($PingServer -eq $True)
{
write-host $hostname is UP
}
if ($PingServer -eq $False)
{
write-host $hostname is DOWN
}