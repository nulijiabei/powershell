foreach ($i in $args)
{get-wmiobject win32_bios -computername $i | select-object __Server, name }