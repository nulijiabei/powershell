$a = $args.length

if ($a -eq 0) {Write-warning "You must supply a folder name."; break}
    else {$strFolder = $args[0] + "\*.dll"}

$b = @()

$c = get-childitem $strFolder

foreach ($i in $c) 
    {$b += [system.diagnostics.fileversioninfo]::getversioninfo($i.fullname)}

$d = ($b  | where-object {$_.CompanyName -eq "Microsoft Corporation"})

cls

$d | format-table @{Label="DLL File";Expression={$_.FileName}},`
    @{Label="Company Name";Expression={($_.CompanyName)}},`
    @{Label="Version Number";Expression={$_.FileVersion}},`
    @{Label="File Size";Expression={"{0:N0}" -f (get-item $_.FileName).Length}} `
    -auto
