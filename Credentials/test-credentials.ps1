#$cred_fname = "C:\Scripts\Credentials\u60890_local-admin-credentials.xml"
$cred_fname = "C:\Scripts\Credentials\adrap_local-admin-credentials.xml"

if (Test-Path "$cred_fname") {
	# read contents from existing file:
	$creds = [xml] (Get-Content "$cred_fname")
} else {
    write-output "Create the File Manually ..."
    break
}

# Parse the XML File
$cred_nodes = $creds.SelectNodes("/creds/cred")

# try all credentials entered or read from file against one host to test:
# this is Hardcoded for the Local Administrator Testing.
$hostname = read-Host "Enter a server name to perform a test run with all credentials. Enter nothing to skip this test."
foreach ($cred_node in $cred_nodes) {
    $full_login = $cred_node.SelectSingleNode("login").InnerText
    $full_login = "$hostname\$full_login"
    $variantID = $cred_node.SelectSingleNode("variantID").InnerText

    # get password from xml node and convert it to a SecureString:
    $pass = ConvertTo-SecureString $cred_node.SelectSingleNode("pwd").InnerText

    # create a new PSCredential object with login and password set:
    $credobj = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $full_login, $pass

    # try a WMI call for our test host using this credentials:
    try {
        $null = Get-WmiObject win32_BIOS -Computername $hostname -Credential $credobj
        "OK: got computer info from $hostname with credentials for $full_login VariantID is $variantID"
        # can't have more than one working credential so quit now.
        break
    }
    catch {
        "FAIL: no computer info from $hostname with credentials for $full_login VariantID is $variantID"
    }
}
