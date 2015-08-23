###########################################################################"
#
# NAME: Set-ADUserRandomPassword.ps1
#
# AUTHOR: Jan Egil Ring
# EMAIL: jan.egil.ring@powershell.no
#
# COMMENT: This script are used to set a random password for Active Directory users in a specified Organizational Unit. It stores the results in a csv-file.
#          The background for this script is a school domain needing to set random passwords for new users, and exporting the passwords to a csv-#          #          file to let the teachers disribute the first-time passwords.
#
# You have a royalty-free right to use, modify, reproduce, and
# distribute this script file in any way you find useful, provided that
# you agree that the creator, owner above has no warranty, obligations,
# or liability for such use.
#
# VERSION HISTORY:
# 1.0 22.08.2009 - Initial release
#
###########################################################################"

#Requires: Quest.ActiveRoles.ADManagement

#Creating system.random object used to generate random numbers
$random = New-Object System.Random
#Creating an array to store user information in
$CSV = @()
#Get users
Get-QADUser -SearchRoot "domain.local/MyUserOU" -SizeLimit 0 | ForEach-Object {
#Generate a random password for each user
$password = "pwd"+($random.Next(1000,9999))
#Set the password for each user
Set-QADUser $_ -UserPassword $password
#Select what user information we want to export to the csv-file and storing it in a variable
$exportdata = Get-QADUser $_ | Select-Object name,samaccountname,company,department
#Add the password as a member to $exportdata
Add-Member -InputObject $exportdata -MemberType NoteProperty -Name Password -Value $password
#Add the user information to the $CSV array
$CSV += $exportdata
}
#Exporting all users to the csv-file
$CSV | Export-Csv -Path "C:\export\passwordlist.csv" -Encoding unicode -NoTypeInformation