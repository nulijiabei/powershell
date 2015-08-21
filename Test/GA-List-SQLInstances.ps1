Import-Module SQLPS -DisableNameChecking

#sql browser must be installed and running
#Start-Service "SQLBrowser"

$instanceName = "WIN-SQL1"
$managedComputer = New-Object 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer' $instanceName

#list server instances    
#   ServerProtocols    Parent   Urn Name    Properties UserData    State

$managedComputer.ServerInstances | Select ServerProtocols,Name,Urn | Format-Table -auto

# Return to the Prompt ?
pushd "C:\Scripts\PS1\Test"