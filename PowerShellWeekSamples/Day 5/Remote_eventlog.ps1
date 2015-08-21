$a = new-object -type system.diagnostics.eventlog -argumentlist system, atl-dc-01
$a.source = "Windows PowerShell Week"
$a.writeentry("This is just a test.","Information")
