Set-Location C:\temp
# ** set networking info

$nic = gwmi Win32_NetworkAdapterConfiguration | ? { ($_.Description -match "vmxnet3") -and ($_.MACAddress -ne $null) }
$nic

$nic.EnableStatic("10.4.64.61","255.255.255.0")
$NIC.SetGateways("10.4.64.254")
sleep 4

$nic.SetDNSServerSearchOrder(@("10.5.4.1","10.5.4.2","10.105.198.2"))
$DNSSuffixes = "ops.global.ad","na.global.ad","eu.global.ad"
invoke-wmimethod -Class win32_networkadapterconfiguration -Name setDNSSuffixSearchOrder -ArgumentList @($DNSSuffixes), $null
$nic.SetDNSDomain("ops.global.ad")
$nic.SetWINSServer("10.5.3.4","10.105.94.4")
$nic.WINSEnableLMHostsLookup=$false
ping 10.5.3.4
Write-Host -Object "`n*** Win2003- Uninstall load balancing and deselect Enable LMHosts lookup`n*** Win2008- deselect ipv6 and link-layer options ***`n`n*** Set OS boot delay to 3 seconds ***`n" -BackgroundColor Yellow -ForegroundColor Red


# ** various system options

$cddrive = Get-WmiObject -Class win32_volume -Filter "DriveType = 5" | Select-Object -First 1
$cddrive | Select-Object DriveLetter,DriveType | Format-Table -Autosize
Set-WmiInstance -InputObject $cddrive -Arguments @{DriveLetter="R:"} | Select-Object DriveLetter,DriveType | Format-Table -Autosize
Write-Host -Object "`n*** Format the D: drive if necessary ***`n" -BackgroundColor Yellow -ForegroundColor Red

$PhyMemMB = [int]((Get-WmiObject Win32_Computersystem).TotalPhysicalMemory / 1GB) * 1024
$PhyMemMB
(Get-WmiObject win32_PageFileUsage).AllocatedBaseSize
If ($PhyMemMB -le 2728)  {
	$CorrectPFSize = $PhyMemMB * 1.5 }
ElseIF ($PhyMemMB -ge 4096 ) {
	$CorrectPFSize = 4096 }
Else {
	$CorrectPFSize = $PhyMemMB }
$CorrectPFSize
$CurrentPFSettings = Get-WmiObject win32_pagefilesetting
$CurrentPFSettings.InitialSize = $CorrectPFSize
$CurrentPFSettings.MaximumSize = $CorrectPFSize
$CurrentPFSettings.Put()

[Environment]::SetEnvironmentVariable('Temp', 'C:\Temp', 'User')
[Environment]::SetEnvironmentVariable('Tmp', 'C:\Temp', 'User')

net localgroup administrators

# ^^ above is Win2003/2008, next section is Win2008 only


# ** various system options

reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
echo "Windows Registry Editor Version 5.00" > c:\temp\skiprearm.reg
echo "[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform]"  >> c:\temp\skiprearm.reg
echo '"SkipRearm"=dword:00000001'  >> c:\temp\skiprearm.reg
reg import c:\temp\skiprearm.reg
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"

tzutil /s "Eastern Standard Time_dstoff"

gpedit.msc

# ** join domain and reboot

netdom join (Get-Item env:COMPUTERNAME).Value /domain:ops.global.ad /userd:_cmonahan /passwordd:'' /reboot:120
# \/ below in Win2003/2008 can be pasted into a command windows after the server has joined the domain 
net localgroup administrators ops\servermgmt /add

sleep 90
exit

# netdom remove (Get-Item env:COMPUTERNAME).Value /domain:ops.global.ad /userd:_cmonahan /passwordd:'' /reboot