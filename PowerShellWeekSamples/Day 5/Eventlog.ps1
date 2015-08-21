$a = new-object -type system.diagnostics.eventlog -argumentlist system
$a.source = "Windows PowerShell Week"
$a.writeentry("This is just a test.","Information")