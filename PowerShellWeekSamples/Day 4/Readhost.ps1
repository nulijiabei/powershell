$a = read-host "Please enter the computer name"
get-wmiobject win32_bios -computername $a 