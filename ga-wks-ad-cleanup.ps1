Add-PSSnapin Quest.ActiveRoles.ADManagement -ErrorAction SilentlyContinue
# Iterate the Users Text File
$computerlist = Get-content C:\cache\delete-computer-accounts.txt
Foreach($computername in $computerlist)
{
    Get-QADComputer $computername | Remove-QADObject -Force
}