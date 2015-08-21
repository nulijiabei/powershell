$hostname = 'win-wsusint1-prod'
#$Computer = 'pc-63660'

# Note Secure String is Tied to User Account.
# This was Cached by running this 1 Liner whilst logged in AS AGSO\ADRAP
#Read-Host -assecurestring | Convertfrom-Securestring | Out-File C:\Scripts\Credentials\adrap_LA_Variant1_password.txt
#Read-Host -assecurestring | Convertfrom-Securestring | Out-File C:\Scripts\Credentials\a68357_LA_Variant1_password.txt

$LA_Variant1_UserName = "Administrator"
$LA_Variant1_Password = Get-Content C:\Scripts\Credentials\a68357_LA_Variant1_password.txt | ConvertTo-SecureString
$LA_Variant1_FullLogin = "$hostname\$LA_Variant1_UserName"
$LA_Variant1_Credential = New-Object -typename System.Management.Automation.PSCredential -argumentlist $LA_Variant1_FullLogin,$LA_Variant1_Password

# TEST / Connect WMI Connection Ability
# try a WMI call for our test host using this credentials:
try {
	$null = Get-WmiObject win32_operatingSystem -Computername $hostname -Credential $LA_Variant1_Credential
	#"OK: got computer info from $hostname with credentials for $LA_Variant1_FullLogin"
    $Boottime = (Get-WmiObject win32_operatingSystem -computer $hostname -Credential $LA_Variant1_Credential -ErrorAction Continue).lastbootuptime
    $Boottime = [System.Management.ManagementDateTimeconverter]::ToDateTime($BootTIme)
	$Now = Get-Date
	$span = New-TimeSpan $BootTime $Now
	$Uptime = "{0} day(s) {1} hour(s) {2} min(s) $BootTime" -f $span.days, $span.hours, $span.minutes, $span.seconds
    Write-Output "$hostname has been up for $Uptime"
}
catch {
	"FAIL: no computer info from $hostname with credentials for $LA_Variant1_FullLogin"
}

#$Boottime = (Get-WmiObject win32_operatingSystem -computer $Computer -ErrorAction stop).lastbootuptime
#$Boottime = [System.Management.ManagementDateTimeconverter]::ToDateTime($BootTIme)