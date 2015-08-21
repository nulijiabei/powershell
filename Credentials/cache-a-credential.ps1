# Note Secure String is Tied to User Account.
Read-Host -assecurestring | Convertfrom-Securestring | Out-File C:\Scripts\Credentials\adrap_LA_Variant1_password.txt