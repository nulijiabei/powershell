# Script: HTML_UptimeReport.ps1 
# Author: ed wilson, msft 
# Date: 08/06/2012 15:11:03 
# Keywords: Scripting Techniques, Web Pages and HTAs 
# comments: Get-Wmiobject, New-Object, Get-Date, Convertto-HTML, Invoke-Item 
# HSG-8-7-2012 
Param( 
  [string]$path = "C:\Health\Daily-Checks\uptime.html", 
  [array]$servers = @("dc1","dc3","proxy3") 
) 
 
Function Get-UpTime 
{ Param ([string[]]$servers) 
  Foreach ($s in $servers)  
   {  
     $os = Get-WmiObject -class win32_OperatingSystem -cn $s  
     New-Object psobject -Property @{computer=$s; 
       uptime = (get-date) - $os.converttodatetime($os.lastbootuptime)}}} 
 
# Entry Point *** 
 
Get-UpTime -servers $servers | ConvertTo-Html -As Table -body "<h1>Server Uptime Report</h1>The following report was run on $(get-date)" >> $path  
Invoke-Item $path 