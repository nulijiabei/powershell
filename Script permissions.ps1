<#
.SYNOPSIS

Applies permissions and roles to vSphere vApps

.DESCRIPTION

Applies permissions and roles to vSphere vApps

-VIServer (Optional, defaults to Development) {FQDN of VCentre Server}
-AppName (Required) {VApp Label}
-ADGroup (Optional) {Domain\Group_Object}
-Role (Optional) {vSphere Role, ReadOnly, Owner-Managed, Supplier-Managed}

.EXAMPLE
Grants the Owner-Managed vSphere role to MYDOM\MYGroup on the "Test VApp".

Create-Permissions -AppName "Test VApp" -ADGroup "MYDOM\MYGroup" -Role "Owner-Managed"


#>

#Author: Ant B 2012

Param(
[String]$VIServer = "<Default VC>",
[parameter(Mandatory=$true)][String]$AppName,
[parameter(Mandatory=$true)][string]$ADGroup,
[parameter(Mandatory=$true)][string]$Role
)
    
#Check for the VMware Snapin, load if it isn't already there.
if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
    Add-PsSnapin VMware.VimAutomation.Core
}

#Connect to VCentre
Connect-VIServer $VIServer


$authmgr = Get-View AuthorizationManager
$perm = New-Object Vmware.VIM.Permission
$perm.principal = $ADGroup
$perm.group = $true
$perm.propagate = $true
$perm.roleid = ($authmgr.Rolelist | where{$_.bosshog -eq $Role}).Roleid
$target = get-vapp | select name, Id | where{$_.Name -eq $AppName}

$authmgr.SetEntityPermissions($target.Id, $perm)

#Close our connection to VCentre
Disconnect-VIServer -Server * -Force -Confirm:$False