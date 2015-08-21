# http://mspowershell.blogspot.com.au/2007/12/send-smtpmail-update.html (v1 friendly)
# http://technet.microsoft.com/en-us/library/hh849925.aspx

$email_from = "TestingOnly.WIN-Script1@ga.gov.au"
#$email_to="GAAdmins@GA.Gov.au" # GA Admins is an Exchange Distribution List for MidRange
#$email_to="Nathan Keogh <nathan.keogh@ga.gov.au>","Angelo Pace <angelo.pace@ga.gov.au>" # Correct way to Multiple List Users (separate by comma and quote the whole recipient may also be "Nathan <nathan.keogh@ga.gov.au")
$email_to="Nathan Keogh <nathan.keogh@ga.gov.au>" # Correct way to Multiple List Users (separate by comma and quote the whole recipient may also be "Nathan <nathan.keogh@ga.gov.au")
#$email_cc="SysAdmin Mailbox <Systems.Administrator@ga.gov.au>"
$email_cc=""
#$email_bcc="Nathan K <nathan.keogh@gmail.com>"
$email_bcc=""
$email_priority="Low" # [ Low / Normal {default} / High ]
$email_subject="(Please Ignore) GA MidRange Test email"
# enter your own SMTP server DNS name / IP address here ... Note IP Address must be allowed to send from in Exchange Server Side
$email_SMTP_server = "exmail.ga.gov.au"
# -DeliveryNotificationOption [ None {default} / OnSuccess {Notify if the delivery is successful.}
# OnFailure: Notify if the delivery is unsuccessful.
# Delay: Notify if the delivery is delayed.
# Never: Never notify.
# -Credential<PSCredential> {default is current user}

# use an old report for illustration purposes
#$Report = Get-Content "C:\Scripts\PS1\Test\Sample-Report.html"
#$Type = Get-Content "C:\Scripts\PS1\Test\Sample-Report.html".GetType()
#Write-Warning $Type
#and ("test").GetType()

$Inline_HTML_Report = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>GA Test Email</title>
<style type="text/css">
<!--
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}
</style>
</head>
<body>
<h2>Test Email Please Ignore</h2>
</body>
</html>
"@

# Send the Mail (not checking the parameters are valid that is assumed.
# NOTE null or empty cc or bcc values will Error the Send-Mailmessage cmdlet

# Use CC and BCC
#Send-Mailmessage -from $email_from -to $email_to -cc $email_cc -bcc $email_bcc -subject $email_subject -BodyAsHTML -body $Inline_HTML_Report -priority $email_priority -smtpServer $email_SMTP_server

# Use CC
Send-Mailmessage -from $email_from -to $email_to -cc $email_cc -subject $email_subject -BodyAsHTML -body $Inline_HTML_Report -priority $email_priority -smtpServer $email_SMTP_server


# Just TO
Send-Mailmessage -from $email_from -to $email_bcc -subject $email_subject -BodyAsHTML -body $Inline_HTML_Report -priority $email_priority -smtpServer $email_SMTP_server


# This command sends an e-mail message with an attachment from User01 to two other users.
# It specifies a priority value of "High" and requests a delivery notification by e-mail when the e-mail messages are delivered or when they fail.
#PS C:\> send-mailmessage -from "User01 <user01@example.com>" -to "User02 <user02@example.com>", "User03 <user03@example.com>" -subject "Sending the Attachment" -body "Forgot to send the attachment. Sending now." -Attachments "data.csv" -priority High -dno onSuccess, onFailure -smtpServer smtp.fabrikam.com


# This command sends an e-mail message from User01 to the ITGroup mailing list with a copy (CC) to User02 and a blind carbon copy (BCC) to the IT manager (ITMgr).
# The command uses the credentials of a domain administrator and the UseSSL parameter.
#PS C:\> send-mailmessage -to "User01 <user01@example.com>" -from "ITGroup <itdept@example.com>" -cc "User02 <user02@example.com>" -bcc "ITMgr <itmgr@example.com>" -subject "Don't forget today's meeting!" -credential domain01\admin01 -useSSL
