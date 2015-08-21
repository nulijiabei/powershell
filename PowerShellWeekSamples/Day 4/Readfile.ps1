$a = get-content "c:\scripts\test.txt"
foreach ($i in $a)
{get-wmiobject win32_bios -computername $i | select-object __Server, name }
