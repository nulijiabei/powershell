#gwmi win32_service -ComputerName . | where-object {$_.StartName -ne 'LocalSystem'} | sort StartMode | ft -auto SystemName,DisplayName,StartMode,State,PathName
Write-OutPut "Services Not Running as NT AUTHORITY\LocalService LocalSystem NT AUTHORITY\NetworkService NT AUTHORITY\NETWORK SERVICE NT AUTHORITY\LOCAL SERVICE"
$compArray = get-content C:\Health\Servers-Services.txt
foreach($strComputer in $compArray)
{
Write-OutPut "$strComputer Has these Non Standard Service Start Accounts"
# Filter the Where Object Many  Times (may not be Optimal but seems to Work.
Get-WMIObject Win32_Service -ComputerName $strComputer | Where-Object{$_.StartName -ne 'LocalSystem'} | Where-Object {$_.StartName -ne 'NT AUTHORITY\NetworkService'} | Where-Object{$_.StartName -ne 'NT AUTHORITY\LocalService'} | Where-Object{$_.StartName -ne 'NT AUTHORITY\NETWORK SERVICE'} | Where-Object{$_.StartName -ne 'NT AUTHORITY\LOCAL SERVICE'} | Sort-Object -Property Name | Format-Table -auto Name,StartName
}