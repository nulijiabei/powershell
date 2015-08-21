<#============================================================================
  File:     6464 - Ch02 - 02 - Discover SQL Server Services.ps1
  Author:   Donabel Santos (@sqlbelle | sqlmusings.com)
  Version:  SQL Server 2012, PowerShell V3
  Copyright: 2012
  ----------------------------------------------------------------------------

  This script is intended only as supplementary material to Packt's SQL Server 2012
  and PowerShell V3 book, and is downloadable from http://www.packtpub.com/
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================#>

Import-Module SQLPS

#replace KERRIGAN with your instance  name
$instanceName = "KERRIGAN" 
$managedComputer = New-Object 'Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer' $instanceName

#list services        
$managedComputer.Services | Select Name, Type, Status, DisplayName | Format-Table -AutoSize
