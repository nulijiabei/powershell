<# 
   .Synopsis 
    This report runs against Active Directory to compare group membership changes. 
   .Description 
    Requires the Quest Active Directory Snapin to be loaded. 
   .Example 
    .\Get-ADGroupsReport.ps1 
   .Inputs 
    N/A 
   .OutPuts 
    N/A 
   .Notes 
    NAME: Get-ADGroupsReport.ps1 
#> 
#Requires -Version 2.0 
[CmdletBinding()] 
 Param  
   ( 
    [Alias("d")] 
    [String]$dir = "C:\Scripts\PS1\ADReports\Reports",  
    [String]$reportname = "report.txt", 
    [Alias("r")] 
    [String]$Root = 'agso.gov.au/Builtin/Domain Admins',
    [Alias("g")]  
    [String]$DomainGroup = "Domain Admins", 
    [String]$PreferredDC = "DC2"
   )#End Param 
 
Add-PSSnapin "Quest.ActiveRoles.ADManagement" -ErrorAction 0 
Connect-QADService -Service $PreferredDC 
 
$file = Join-Path -path $dir -childpath "$DomainGroup.xml" 
$attachment = Join-Path -path $dir -childpath $reportname 
if (test-path $file) 
   { 
    $PreviousAccess = Import-Clixml $file 
   } 
else 
    {Write-Host "No Previous file was available to compare for $DomainGroup"} 
     
$Group = Get-QADObject -SizeLimit 100 -SearchRoot $Root |  
Where-Object {$_.Name -eq $DomainGroup -and $_.Type -eq "group"} | 
ForEach-Object {Write-Host "There are" $_.AllMembers.count "members in the" $_.Name "group";$_} 
 
$CurrentAccess = $Group | ForEach-Object {$_.AllMembers} | 
ForEach-Object { 
        $Hash = @{  
            Name=(Get-QADObject -Identity $_).Name 
            Group=$DomainGroup} 
        New-Object PSObject -Property $Hash 
} 
$CurrentAccess | Export-Clixml $file 
 
if ($PreviousAccess) 
    { 
     $difference = Compare-Object -ReferenceObject $PreviousAccess -DifferenceObject $CurrentAccess -Property Name | 
     ForEach-Object {$_} 
     $differencetext = $difference | Format-Table -AutoSize | Out-String -width 280 
     $differencetext 
    } 
 
if ($difference) 
    { 
     $DifferenceObject = $Difference | ForEach-Object { 
     if ($_.SideIndicator -eq "<=") 
        { 
            $_ | Add-Member -MemberType NoteProperty -Name MemberChange -Value "Removed from Group" -Force 
            $_ | Add-Member -MemberType NoteProperty -Name DomainGroup -Value $DomainGroup -Force 
        } 
     elseif ($_.SideIndicator -eq "=>") 
        {      
            $_ | Add-Member -MemberType NoteProperty -Name MemberChange -Value "Added to Group" -Force 
            $_ | Add-Member -MemberType NoteProperty -Name DomainGroup -Value $DomainGroup -Force 
        } 
     $_ 
     } | Select-Object Name, MemberChange,DomainGroup 
      
     Send-HTMLEmail -InputObject $DifferenceObject -Subject "$DomainGroup - Change in Group Members!" -To Admin@domain.org 
    } 
 else 
    { 
     write-host "There are no changes in the $DomainGroup group" 
     write-host "" 
    }