# To Get the VM data with OS Name 
#Set-ExecutionPolicy Remotesigned -force 
# PS 2.0 Version Tested.
if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) { 
Add-PSSnapin VMware.VimAutomation.Core} 
$VC1 = "WIN-VCENTER"
$date = Get-Date -DisplayHint DateTime -Format "yyyy-M-d" 
Connect-VIServer -Server $VC1 -WarningAction SilentlyContinue
Get-VM | Select Name,PowerState,@{N="GuestOS";E={($_ | Get-VMGuest).OSFullName}}| Export-Csv -NoTypeInformation -Path C:\Health\vSphere\Report-$VC1-$Date.csv
Disconnect-VIServer -server $VC1 -Force -Confirm:$false