# A succession of pop-ups to prompt for the new user name details 
$fname = new-object -comobject MSScriptControl.ScriptControl
$fname.language = "vbscript"
$mInitial = new-object -comobject MSScriptControl.ScriptControl
$mInitial.language = "vbscript"
$lname = new-object -comobject MSScriptControl.ScriptControl
$lname.language = "vbscript"
$fname.addcode("function getInput() getInput = inputbox(`"Please Provide First Name`",`"First Name`") end function" )
$mInitial.addcode("function getInput() getInput = inputbox(`"Please Provide Middle Initial`",`"Middle Initial`") end function" )
$lname.addcode("function getInput() getInput = inputbox(`"Please Provide Last Name`",`"Last Name`") end function" )
$strFirstName = $fname.eval("getInput")
$strMiddleInitial = $mInitial.eval("getInput")
$strLastName = $lname.eval("getInput")

# Grab the first letter of the first name and concatenate it with the last name to create username
$strUserName = $strFirstName.Substring(0,1) + $strLastName

# Set display name
$strDisplayName = $strFirstName + " " + $strMiddleInitial + ". " + $strLastName

# Set UPN
$strUpn = $strUserName + "@ham.sitel.co.nz"

# Set email address
$strEmail = $strFirstName + "." + $strLastName + "@ham.sitel.co.nz"

# Set SamID for legacy purposes
$strSamid = $strUserName

# Set conical name for user container
$strCNName = "OU=MyTestOU,DC=ham,DC=sitel,DC=co,DC=nz"

# Set conical name for user by concatenating the Display name with the CN Name for the user container
$strValue = "CN="+ $strDisplayName + "," + $strCNName

# Search AD for the existence of the username and push that value to #strSamAccount, If username doesn't exist, then $strSamAccount will be null.
$strSamAccount = get-adobject -value $strUserName

# Set up messagebox to display success or failure of user creation
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$MsgBox = [Windows.Forms.MessageBox]
$Button = [Windows.Forms.MessageBoxButtons]:K

# Create user function, after verifying that the $strUserName is unique. This function calls "dsadd #user" from the CLI 
# and then displays via pop-up the creation after checking that the account is unique. 
# Also sends an email to system guys to finish off configuration of user.
function CreateAccount
{
    # Verify that the account is unique by checking AD for the account using the display name.
    $displaynametest = Get-ADObject -Value $strdisplayname
    if($displaynametest.Displayname -eq $strdisplayname)
    {
        # Set up message box for pop up indicating there is a problem with an already existing account
        $Icon = [Windows.Forms.MessageBoxIcon]::Warning
        $MsgBox::Show("An account for " + $strDisplayName + " already exists. `n If you believe this is an error, please try again `
        `n", "Unsuccessful Acccount Creation", $Button, $Icon)
    }
    else
    {
        # Add user
        dsadd user $strValue -upn $strUpn -samid $strSamid -fn $strFirstName -mi $strMiddleInitial -ln $strLastName -display $strDisplayName  -email $strEmail -pwd PASSWORD -mustchpwd yes
        # Set up message box for pop up and display of user details
        $Icon = [Windows.Forms.MessageBoxIcon]::Information
        $MsgBox::Show("The windows account for " + $strDisplayName + " has been created. `n`n" + $strFirstName + "'s username is " + $strUserName + ". `n" `
        + $strFirstName + "'s email address is " + $strEmail + ". `n", "Successful Acccount Creation", $Button, $Icon)
        # Prompt with pop-up to populate 3 named groups
        $group1 = new-object -comobject MSScriptControl.ScriptControl
        $group1.language = "vbscript"
        $group2 = new-object -comobject MSScriptControl.ScriptControl
        $group2.language = "vbscript"
        $group3 = new-object -comobject MSScriptControl.ScriptControl
        $group3.language = "vbscript"
        $group1.addcode("function getInput() getInput = inputbox(`"Please provide group you want to add user to`",`"First Group`") end function" )
        $group2.addcode("function getInput() getInput = inputbox(`"Please Provide Second Group name you want to add user to`",`"Second Group`") end function" )
        $group3.addcode("function getInput() getInput = inputbox(`"Please Provide Second Group name you want to add user to`",`"Third Group`") end function" )
        $strFirstGroup = $group1.eval("getInput") > c:\groups.txt
        $strSecondGroup = $group2.eval("getInput") >> c:\groups.txt
        $strThirdGroup = $group3.eval("getInput") >> c:\groups.txt
        # Actual addition to add user to groups from c:\groups.txt
        $username = $strUserName
        $aryGroups = get-Content "c:\groups.txt"
        foreach ($groupname in $aryGroups)
        {
            $usermodname = get-ADObject -value $username
            $usermodname.distinguishedName
            dsquery group -samid $groupname | dsmod group -addmbr $usermodname.distinguishedName
        }
        $groups = dsquery user -name $strDisplayName | dsget user -memberof
        # Mail enable account that you just created.
        # Send email to IT to finish work around the new user to include mail enabling the account
        Send-SmtpMail -SMTPHost "hamxch02.ham.sitel.co.nz" -To "anatoli.yefimov@ham.sitel.co.nz" -From "anatoli.yefimov@ham.sitel.co.nz" -Subject "New Employee added to Domain by HR" `
        -Body "$strDisplayName has had an account created in AD by HR. 

Username is $strUserName. 

Current group membership is: $groups 

Please mail enable this account and set up OU location" 
        
    }
    
}

# If $strSamAccount.SamAccountName (username) doesn't exist than run CreatAccount function
if ($strSamAccount.samaccountname -ne $strUserName)
{
    CreateAccount
}
else
    {
    # If username was already in use, then a second letter from the first name is added to the username, samid and upn
        $strUserName = $strFirstName.Substring(0,2) + $strLastName
        $strSamAccount = get-adobject -value $strUserName
        $strEmail = $strFirstName + "." + $strLastName + "@ham.sitel.co.nz"
        $strSamid = $strUserName
        $strUpn = $strUserName + "@ham.sitel.co.nz"
    # If $strSamAccount.SamAccountName (username with second letter from first name) doesn't exist than run CreatAccount function
        if ($strSamAccount.samaccountname -ne $strUserName)
        {
            CreateAccount
        }
     else
        {
            # If username was already in use, then a third letter from the first name is added to the username, samid and upn
            $strUserName = $strFirstName.Substring(0,3) + $strLastName
            $strSamAccount = get-adobject -value $strUserName
            $strEmail = $strFirstName + "." + $strLastName + "@ham.sitel.co.nz"
            $strSamid = $strUserName
            $strUpn = $strUserName + "@ham.sitel.co.nz"
            # If $strSamAccount.SamAccountName (username with second and third letter from first name) doesn't exist than run CreatAccount function
            if ($strSamAccount.samaccountname -ne $strUserName)
            {
                CreateAccount
            }
            else
               {
                $Icon = [Windows.Forms.MessageBoxIcon]::Warning
                $MsgBox::Show("There was a problem with duplicate account names. Please contact IT! `n", "Warning!", $Button, $Icon)
               }
        }
    }