if (-not (Get-PSSnapin Quest.ActiveRoles.ADManagement -ErrorAction SilentlyContinue)) 
{
Add-PSSnapin Quest.ActiveRoles.ADManagement
}
$Servers = Get-QADComputer | Select-Object Name
foreach ($Server in $Servers)
{ 
Get-WmiObject win32_service -ComputerName $Server | Where-Object {$_.StartName -like “*Service*”} | Select-Object SystemName, DisplayName, StartName
}