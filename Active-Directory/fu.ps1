#======================================================================================
# Script:        fu.ps1
#
# Purpose:       A command-line utility to lookup users in Active Directory.
#
# Usage:         fu <user account name>
#                  or
#                fu <first name> <last name>
#                  or
#                fu g=<group name> [/v] [/t] [/csv]
#                  or
#                fu s=<script name> [/v] [/t] [/csv]
#                  or
#                fu ou=<ou name> [/v] [/t] [/csv]
#
#                /v    Enables verbose mode - retrieves more details from AD.
#
#                /t    Uses tabs as column separators instead of spaces.
#
#                /csv  Writes extra-verbose details to a csv file.
#
# Requirements:  A Windows 2003 native mode domain.
#
# Author:        Jim Roberts
#
# Date:          29th December 08
#
# Notes:         If only one name is supplied as a parameter the script assumes this is a
#                username (SAMaccountname) and searches for that user.
#
#                For example:  fu bccajmrs    will return details of the 'bccajmrs' account.
#
#                If two names are supplied the script assumes that they are a first name
#                and a last name and searches for matching users.
#
#                For example:  fu joe bloggs   will search for users of this name.
#
#                The * wildcard is supported.
#                    fu john j*    will match John Jones and John James
#                    fu * smith    will match everyone with surname Smith
#                    fu bcc*jnjs   will match accounts bccajnjs and bccbjnjs
#
#                If a parameter starting with g= is supplied, the name after = is interpreted
#                as a group name and users in that group are retrieved.
#
#                If a parameter starting with s= is supplied, the name after = is interpreted
#                as a logon script name and users of that script are retrieved.
#
#                If a parameter starting with ou= is supplied, the name after = is interpreted
#                as an OU name and users in that group are retrieved.  For example:
#                           fu ou=admins
#                When an OU is nested inside another OU it is necessary to specify the complete
#                path in the form ou=<target ou>ou=<parent ou>ou=<parent ou> etc.  It is not
#                necessary to specify the domain.  For example:
#                           fu "ou=child,ou=parent"
#
#                Launch the script by adding an alias to your profile.
#                     set-alias fu \fu.ps1
#
# Versions:      2.0  - First version to include functionality to lookup by group, OU and script.
#                2.1  - Multiple changes:
#                        - Used .net format strings to format output
#                        - Used sort field of DirectorySearcher object
#                        - Used v 1.1 of getPosInt function
#                        - Used readArguments( ) v 1.1.
#                2.11  - Fixed bug in line saying how many users found.
#                        Added paging to help output.
#                2.2   - Fixed bug interpreting nested OUs from command line.
#                        See notes in code.
#                2.21  - Added code to stop lines wrapping when asking giving users
#                        list to users or groups to choose from.
#                2.22  - Fixed bug relating to renaming of temporary array.
#                2.23  - Added last logon time to user list when more than one user returned.
#                2.231 - Slight change to spacing of columns in picklist.
#                2.3   - Added lookup of account expiry date in names modes and CSV mode
#                        Made "Yes" for accounts disabled, locked-out or expired display
#                        in the warning colour.
#======================================================================================
$verNum = "2.3"    # Version of this script



#======================================================================================
#    C O M M O N    F U N C T I O N S
#======================================================================================



#=============================================================================
# Only used in debugging.  Dumps globals read from command line.
#============================================================================
Function Debug( )
  {
  Write-Host `n
  "------- DEBUG ------------------"
  "Script variables:"
  "  Help         = $Script:Help"
  "  getVer       = $Script:getVer"
  "  verbose      = $Script:verbose"
  "  Names:length = $($Script:Names.length)"
  "  Names = "
  for ( $i=0; $i -lt $Script:Names.Length; $i++ )
    {
    "        " + $Script:Names[ $i ]
    }
  "--------------------------------"
  Write-Host `n
}



#================================================================================================
# Powershell function to check the functional level of the current domain.
# This script looks up the 'lastlogontimestamp' attribute and this only exists in a Windows 2003
# native mode domain.
#================================================================================================
Function checkDomainLevel
  {
  $mode = $Script:domain.get("msDS-Behavior-Version")
  If ( $mode -lt 2 )
    {
    'This utility only works with domains with a'
    'functional level of "Windows 2003 native"'
    'or greater.  (This is because it reads the'
    'lastlogontimestamp attribute which is only'
    'present in domains at this level.)'
    exit # Break out of the script.
    }
  }



#=============================================================================
# Function to read and parse command line arguments.
# Sets the script Booleans and adds any other elements to the script
# $Names array
# Version 1.1  Converts all arguments to strings
#=============================================================================
function readArguments( )
  {
  If ( $Script:args.length -gt 0 )
    {
    foreach( $Token in $script:Args )
      {
      $Token = ([string]$Token).ToUpper()
      If( ($Token -eq "/?") -or ($Token -eq "-?") -or
          ($Token -eq "/H") -or ($Token -eq "-H") -or
          ($Token -eq "/HELP") -or ($Token -eq "-HELP")
        )
        { $Script:Help = $True }
      ElseIf( $Token -eq "/VER" )
        { $Script:getVer = $True }
      ElseIf( ($Token -eq "/V") -or ($Token -eq "-V") )
        { $Script:verbose = $True }
      ElseIf( ($Token -eq "/T") -or ($Token -eq "-T") )
        { $Script:useTabs = $True }
      ElseIf( ($Token -eq "/CSV") -or ($Token -eq "-CSV") )
        { $Script:csv = $True }
      Else
        {
        $Script:Names += $Token
        }
      }  # ForEach
    }  # If
  } # Function



#=============================================================================
# Trims lines to the current screen width before writing them to screen.
# This looses some information but improves readability.
#=============================================================================
function writeline
  {
  param(
    [string] $s = $(throw "Param 's' required in writeline.")
    )
  if ( $s.length -ge $script:screenwidth )
    {
    # If the line is wider than the screen trim it.
    $s = $s.substring( 0, $script:screenwidth )
    # The line is now exactly the same width as the screen so
    # if we write it normally we will get an extra blank line
    # beneath.  Suppress this with the -nonewline switch
    Write-Host $s -nonewline
    }
  else
    {
    Write-Host $s
    }
  }


#=============================================================================
# Writes a string to the console in the current warning colour.
#=============================================================================
function warn-host
  {
  param(
    [string] $s = $(throw "Param 's' required in warn-host.")
    )
    Write-Host $s -foregroundcolor $Host.PrivateData.WarningForeGroundColor
  }



#=============================================================================
# Interpret the command line arguments to ascertain what kind of search to do.
# Also populate key global variables containing search criteria.
#=============================================================================
Function establishSearchType
  {
  switch ( $script:Names.length )
    {
    1 {
      $arg = $script:Names[0]
      if ( $arg.startswith( "G=", $ignoreCase ) )
        {
        # Lookup group members
        $script:searchType = "LM"
        $script:groupName = $arg.substring( 2, $arg.length - 2 )
        }
      elseif ( $arg.startswith( "OU=", $ignoreCase ) )
        {
        # Lookup users in an OU
        $script:searchType = "OU"
        # For reasons I do not currently understand, when an argument
        # containing commas is input and processed by the readArguments( )
        # function the commas get turned into spaces.  The replacement
        # below puts them back as commas.  This is necessary to deal
        # with auguments such as ou=inner,ou=outer
        $script:OU = $arg.replace(" OU=",",OU=")
        }
      elseif ( $arg.startswith( "S=", $ignoreCase ) )
        {
        # Lookup users of a script
        $script:searchType = "SC"
        $script:scriptName = $arg.substring( 2, $arg.length - 2 )
        }
      else
        {
        # Find user by SAM name
        $script:searchType = "FU1"
        $script:samName = $arg
        $script:csv = $True  # Search for all attributes
        }
      }
    2 {
      # Find user by first and last name lookup
      $script:searchType = "FU2"
      $script:firstName = $script:Names[0]
      $script:lastName  = $script:Names[1]
      $script:csv = $True  # Search for all attributes
      }
    } # Switch
  }



#=============================================================================
# Writes help text to console.
# Note that there MUST be a space on each blank line for spacing to work
# properly.
#=============================================================================
Function giveHelp
  {
  $helpText = @"
 Script:        fu.ps1
 Purpose:       A command-line utility to lookup users in Active Directory.
 Usage:         fu <user account name>
                  or
                fu <first name> <last name>
                  or
                fu g=<group name> [/v] [/t] [/csv]
                  or
                fu s=<script name> [/v] [/t] [/csv]
                  or
                fu ou=<ou name> [/v] [/t] [/csv]
                /v    Enables verbose mode - retrieves more details from AD.
                /t    Uses tabs as column separators instead of spaces.
                /csv  Writes many details to a csv file.
 Requirements:  A Windows 2003 native mode domain.
 Author:        Jim Roberts
 Date:          29th December 08
 Version:       $verNum
 Notes:         If only one name is supplied as a parameter the script assumes this is a
                username (SAM account name) and searches for that user.
                For example:  fu bccajmrs    will return details of the 'bccajmrs' account.

                If two names are supplied the script assumes that they are a first name
                and a last name and searches for matching users.

                For example:  fu joe bloggs   will search for users of this name.

                The * wildcard is supported.
                    fu john j*    will match John Jones and John James
                    fu * smith    will match everyone with surname Smith
                    fu bcc*jnjs   will match accounts bccajnjs and bccbjnjs

                If a parameter starting with g= is supplied, the name after = is interpreted
                as a group name and users in that group are retrieved.

                If a parameter starting with s= is supplied, the name after = is interpreted
                as a logon script name and users of that script are retrieved.

                If a parameter starting with ou= is supplied, the name after = is interpreted
                as an OU name and users in that group are retrieved.  For example:
                           fu ou=admins
                When an OU is nested inside another OU it is necessary to specify the complete
                path in the form ou=<target ou>ou=<parent ou>ou=<parent ou> etc.  It is not
                necessary to specify the domain.  For example:
                           fu "ou=child,ou=parent"

                Launch the script by adding an alias to your profile.
                     Set-Alias fu \fu.ps1
"@
  Out-Host -paging -inputObject $HelpText
  }



#=============================================================================
# Accepts a string.  If the string is not empty it returns the string unaltered.
# If the string is empty it returns "<Blank>"
# Versions:
# 1.1  Actually returns "<Blank>" - Previous version erroneously returned an
#      empty string.  (Due to < and > being misinterpreted when script converted
#      to html for upload.)
#=============================================================================
Function blank
  {
  Param(
    [string] $var = $(throw "Param 'var' required in blank.")
    )
  If ( $var -eq "" -or $var -eq $Null )
    { "<Blank> " }
  else
    { $var }
  }



#=============================================================================
# Powershell function which prompts for, and validates, a path and name for
# a file to save.
# Pressing <Enter> aborts.
# Returns path or "" if aborted or fails.
# Version: 1.1
# History: The original version of this function failed if the file already
#          existed and the user chose not to overwrite it.
#=============================================================================
Function getFileSavePath
  {
  Param(
    [string] $prompt = $(throw "Param 'prompt' required in getFilePath.")
    )
  $OK = $false
  do
    {
    $path = Read-Host $prompt

    # Exit if they just press
    if ( $path -eq "" ) { return "" }

    if ( Test-Path $path -isValid )
      {
      $folder = Split-Path $path
      if ( $folder -eq "" ) { $folder = ".\" }
      if ( Test-Path $folder )
        { $OK = $True }
      else
        { Write-Host "Folder does not exist." }
      }
   else
      { Write-Host "Path is not valid." }
    }
  until ( $OK )

  # If you get here the path entered is valid, so check if there is already
  # a file with this path name.
  if ( Test-Path $path )
    {
    $yn = getYN "File exists.  Overwrite? (Y/N)"
    if ( $yn -eq "N" )
      {
      # Escape the function and return an empty string
      return ""
      }
    }
  # Otherwise return the specified path
  $path
  }



#=============================================================================
# Powershell function to test if a file is open.
# Version 1.1  Powershell's current directory is set at the time you launch
#              Powershell.  You can view it by typing
#              [environment]::currentdirectory   Using CD to switch to another
#              location does not change this.  Your prompt may say
#              PS D:\code\ps> but your current directory will probably still
#              be something like "C:\Documents and Settings\jim".  Try it.
#              This is may be a problem when you use system.io.file as its
#              functions prepend the current directory to the front of
#              relative paths - and this will probably not be what you think
#              it is.  (Powershell's native file functions do not do this.)
#              Hence the workaround in v 1.1
#=============================================================================
function isFileOpen
  {
  Param(
    [string] $Path  = $(throw "Param 'path' required in isFileOpen.")
    )

  trap
    {
    # If trap is called - the openRead failed - so the file is already open
    # and we set a function variable to indicate this.
    # Due to Powershell's scope rules, the only mechanism (other than using
    # a global variable) I could find to have the trap function communicate
    # with its caller was to use set-variable with the -scope paramater.  This
    # enables it access a variable in the calling scope.
    Set-Variable -name alreadyOpen -value $True -scope 1
    continue
    }

  $alreadyOpen = $False

  # Verify file exists
  if ( !(Test-Path $path) )
    {
    Write-Host "'isFileOpen' called with non-existent file."
    exit
    }

  # If $path is relative, then prepend the
  # current location as shown by the Powershell prompt.
  if ( (Split-Path $path) -eq "" )
    {
    $path = Join-Path (Get-Location) $path
    }

  # Try to open the file - to see if an exception is thrown
  $f = [System.IO.File]::OpenRead( $path )

  # If we opened the file as part of our test, then close it again.
  if( !($alreadyOpen) )
    {
    $f.close()
    }
  $alreadyOpen
  }



#=============================================================================
# Powershell function to convert the last logon time as returned by Active
# Directory to a conventional time and date.
# The value returned by Active Direcory is expressed as the number of 100
# nanosecond intervals since 12:00 a.m. January 1, 1601.
#=============================================================================
Function CalculateLastLogon
  {
  param(
    [int64] $ticks = $(throw "Param 'ticks' required in CalculateLastLogon.")
    )
  $base = [DateTime] "1601-1-1"
  $span = [TimeSpan] $ticks
  $base + $ticks
  }



#=============================================================================
# Powershell function to extract the OU part from a distinguished name.
# Pass it the distinguished name, the common name (which will be removed
# from the front) and the domain object (whose name will be removed from the
# the end).  Also removes attribute type identifiers: OU= etc
#=============================================================================
Function DNtoOU
  {
  param(
    [string] $DN = $(throw "Param 'DN' required in DNtoOU."),
    [string] $CN = $(throw "Param 'CN' required in DNtoOU."),
    [System.DirectoryServices.DirectoryEntry] $Domain = $(throw "Param 'Domain' required in DNtoOU.")
    )
  # Get the distinguished name of the domain
  $domainName = [string]$Domain.distinguishedname

  # Chop it off the end of the distinguished name of the user
  $noDom = $DN.substring( 0, $DN.length - $domainName.length - 1 )

  # (Every comma in the CN is preceded with an \ in the DN
  #  so we need to count them then add the total to the length
  #  to be removed.)
  $regex = New-Object -typename System.Text.RegularExpressions.Regex -argumentlist ","
  $commaCount = $regex.Matches( $CN ).count

  $CNlength = $CN.length + $commaCount + 3 # Plus three for prefix

  # Now chop the CN off the front of the DN
  $OU = $noDom.substring( $CNlength, $noDom.length - $CNlength )

  # By now, if the object is in the root of the domain, $OU will be "",
  # otherwise it will still have a leading comma that needs to be removed.
  if ( $OU -eq "" )
    { "<None>" }
  else
    {
    # If there is a leading comma, remove it
    if ( $OU.substring(0,1) -eq "," )
      {
      $OU = $OU.substring( 1, $OU.length - 1 )
      }

    # Now cut out the OU= and CN=
    $OU = [System.Text.RegularExpressions.Regex]::Replace( $OU, "OU=" ,"")
    $OU = [System.Text.RegularExpressions.Regex]::Replace( $OU, "CN=" ,"")
    $OU
    }
  }



#=============================================================================
# Powershell function to get a positive integer in a specified range from the
# console.
# Ver 1.1   Modified to use range parameters.
#=============================================================================
Function GetPosInt
  {
  Param(
    [string] $prompt = $(throw "Param 'prompt' required in GetPosInt."),
    [int] $low  = $(throw "Param 'low' required in GetPosInt."),
    [int] $high = $(throw "Param 'high' required in GetPosInt.")
    )
  do
    {
    do
      { $a = Read-Host $prompt }
    until( $a -match "^\d*$" ) # Get a string of digits
    If( $a.length -eq 0 )      # If it's empty, return it
      { return $a }
    else
      {    $val = [int]$a }       # If not cast it to an integer
    }
  until ( ( $low -le $val ) -and ( $val -le $high ) )  # Check in range
  return $val
  }



#=============================================================================
# Powershell function to get a 'Y' or a 'N' from the console.
#=============================================================================
Function GetYN
  {
  Param(
    [string] $prompt = $(throw "Param 'prompt' required in GetYN.")
    )
  do
    {
    $c = (Read-Host $Prompt).ToUpper()
    }
  until( ($c -eq "Y") -or ($c -eq "N") )
  $c
  }



#=============================================================================
# Look through the data to establish the widest element in each columns - to
# allow columns of output to be vertically aligned.
#=============================================================================
function getColumnWidths
  {
  # re-initialise columns widths
  $script:longestSAM    = 0  # Holds width of inter-column padding
  $script:longestName   = 0  # Holds width of inter-column padding
  $script:longestOU     = 0  # Holds width of inter-column padding
  $script:longestPath   = 0  # Holds width of inter-column padding

  $i = 0
  foreach ( $user in $script:Users )
    {
    $sam = [string]$user.properties.samaccountname
    if ( $sam.length -gt $script:longestSAM ) { $script:longestSAM = $sam.length }

    if ( $verbose )
      {
      $Given = blank $user.Properties.givenname
      $sn = blank $user.Properties.sn
      $name = "$Given $sn"
      if ( $name.length -gt $script:longestName ) { $script:longestName = $name.length }

      $CN = $user.Properties.cn
      $DN = $User.Properties.distinguishedname
      $OU = DNtoOU $DN $CN $Script:domain
      if ( $OU.length -gt $script:longestOU ) { $script:longestOU = $OU.length  }

      $path = blank $($user.Properties.scriptpath)
      if ( $path.length -gt $script:longestPath) { $script:longestPath = $path.length  }
      }
    $i++
    } # for each
    $script:LongestNumber = ([string]$i).length
  }



#=============================================================================
# Define the set of attributes to be retrieved from Active Directory for
# each users depending on what kind of search will be performed.
#=============================================================================
function specifyAttributes
  {
  $script:attributes += @( "samaccountname", "givenname", "sn" )
  if ( $verbose -or $csv )
    {
    $script:attributes += @( "scriptpath", "useraccountcontrol", "cn", `
                             "distinguishedname", "lastlogontimestamp" )
    }
  if ( $csv )
    {
    $script:attributes += @( "profilepath", "homedrive", "homedirectory", `
                             "description", "whencreated", "lockouttime", `
                             "accountExpires" )
    }
  }



#=============================================================================
# Write user details to screen.
#=============================================================================
function writeOutput
  {
  # To test if user account is disabled.
  Set-Variable ADS_UF_ACCOUNTDISABLE 0x02 -option constant

  if ( ! $useTabs )
    {
    # Build format string
    $fs = "{0,$($longestNumber * -1)} {1,$($longestSAM * -1)}"
    if ( $verbose )
      {
      $fs = $fs + " {2,$($longestName * -1)} {3,$($longestOU * -1)} {4,$($longestPath * -1)} {5,-8}"
      } # if Verbose
    } # ! useTabs
  $i = 1
  foreach ( $user in $script:Users )
    {
    $sam = [string]$user.properties.samaccountname
    $Given = blank $user.Properties.givenname
    $sn = blank $user.Properties.sn
    $name = "$Given $sn"
    if ( $verbose )
      {
      $CN = $user.Properties.cn
      $DN = $User.Properties.distinguishedname
      $OU = DNtoOU $DN $CN $Script:domain
      $path = blank $($user.Properties.scriptpath)
      if ( $($user.Properties.useraccountcontrol) -Band $ADS_UF_ACCOUNTDISABLE )
        { $disabled = "Disabled" }
      else
        { $disabled = "Enabled" }
      $Ticks = $($User.Properties.lastlogontimestamp)
      $LLO = (CalculateLastLogon( $Ticks )).ToShortDateString()
      if ( $LLO -eq "01/01/1601" )
        { $LLO = "<Never>" }
      else
        { $LLO = [string]$LLO }
      if ( $useTabs )
        { "$i`t$sam`t$name`t$OU`t$path`t$disabled`t$LLO" }
      else
        { ([System.String]::Format( $fs, $i, $sam, $name, $OU, $path, $disabled)) + " " + $LLO }
      }
    else
      {
      if ( $useTabs )
        { "$i`t$sam`t$name" }
      else
        { ([System.String]::Format( $fs, $i, $sam)) + " " + $name }
      }
    $i++
    } # for each
  "=================="
  $count = $i - 1
  "$count user(s) found."
  }



#=============================================================================
# Writes the user details held in $script:Users to a CSV file specified
# in the parameter.
# (I wanted to write direct to an Excel spreadsheet, but in version 1 of
# Powershell this does not work for none US English installs of Office.)
# Version 1.1   Early versions of this function worked, but later versions
#               (copied from my other, slightly different scripts?) had a
#               major bug.  They outputted one line for each user, but every
#               line was identical to the last line.  To fix this I had to
#               call new-object once for each go around the loop.
#               (Previously I created just one object before the loop and
#               simply re-populated it each time.)
#=============================================================================
function writeToCSV
  {
  param(
    [string] $path = $(throw "Param 'path' required in writeToCSV.")
    )
  Write-Host "Working ..."

  # To test if user account is disabled.
  Set-Variable ADS_UF_ACCOUNTDISABLE 0x02 -option constant

  $i = 1
  # For each cannot be the start of a pipeline unless it is wrapper in $( .. )
  # Without this you get the "An empty pipe element is not permitted" error.
  $( foreach ( $user in $script:Users )
    {
    # The Powershell export-csv commandlet outputs the *OBJECTS* to the csv file.
    # Each object piped to the commandlet forms a line of the file and its
    # properties are used for the columns.  Because of this it is necessary to
    # put the user information into an object before exporting.
    $o = New-Object object
    Add-Member -in $o noteproperty SAM ([string]$user.properties.samaccountname) # Not sure why cast is needed - but it is.
    # Add-Member -in $o noteproperty status
    Add-Member -in $o noteproperty given (blank $user.Properties.givenname)
    Add-Member -in $o noteproperty sn (blank $user.Properties.sn)
    $CN = [string]$user.Properties.cn
    Add-Member -in $o noteproperty CN ([string]$user.Properties.cn)  # Not sure why cast is needed - but it is
    $DN = $User.Properties.distinguishedname
    $OU = DNtoOU $DN $o.CN $Script:domain
    Add-Member -in $o noteproperty OU $OU
    Add-Member -in $o noteproperty description (blank $($user.Properties.description))
    Add-Member -in $o noteproperty scriptpath (blank $($user.Properties.scriptpath))
    Add-Member -in $o noteproperty whencreated $($User.Properties.whencreated).ToShortDateString()
    $Ticks = $($User.Properties.lastlogontimestamp)
    $LLO = (CalculateLastLogon( $Ticks )).ToShortDateString()
    If( $LLO -eq "01/01/1601" )
      { $LLO= "<Never>" }
    else
      { $LLO = [string]$LLO }
    Add-Member -in $o noteproperty LLO $LLO
    $Ticks = $($User.Properties.accountexpires)
    if ( $Ticks -eq $script:neverSet -or $Ticks -eq 0 )
      { $Expires = "<Never>" }
    else
      { $Expires = (CalculateLastLogon( $Ticks )).ToShortDateString() }
    Add-Member -in $o noteproperty expires $Expires
    if ( $($user.Properties.useraccountcontrol) -Band $ADS_UF_ACCOUNTDISABLE )
      { $disabled = "Disabled" }
    else
      { $disabled = "Enabled" }
    Add-Member -in $o noteproperty disabled $disabled
    $Ticks = $($User.Properties.lockouttime)
    $LOT = (CalculateLastLogon( $Ticks )).ToShortDateString()
    if( $LOT -eq "01/01/1601" )
      { $Locked = "No" }
    else
      { $locked = "Yes" }
    Add-Member -in $o noteproperty locked $locked
    Add-Member -in $o noteproperty homedrive $($User.Properties.homedrive)
    Add-Member -in $o noteproperty homedir $($User.Properties.homedirectory)
    [void]$i++
    $o  # Output object to be consumed by following pipe to export-csv
    } ) | Export-Csv $path -NoTypeInformation
  }



#=============================================================================
# Get a file name (and path) from the console for a CSV file to take the
# output.
#=============================================================================
function getCSVpath
  {
  $path = getFileSavePath "Enter name for .csv file (<Enter> to quit)"
  if ( $path -eq "" )
    {
    return ""
    }
  if ( Test-Path $path )
    {
    # File already exists - so see if we can write to it.
    if ( isFileOpen( $path  ) )
      {
      Write-Host "Cannot open csv file.  Is it already open?"
      return ""
      }
    }
  return $path
  }



#======================================================================================
#    G R O U P   M E M B E R S H I P    F U N C T I O N S
#======================================================================================



#=============================================================================
# Top level function to find members in an active directory group
#=============================================================================
function findGroupMembers
  {
  param(
    [string] $group = $(throw "Param 'group' required in findGroupMembers.")
    )
  # Get the distinguished name fo the group.
  $groupDN = getGroupDN $group
  If ( $groupDN -eq "" )
    {
    Exit( 0 )
    }
  else
    {
    if ( ! $csv ) { displayGroupHeader $groupDN }
    addGroupMembersToArray $groupDN
    }
  }



#=============================================================================
# Takes the common name of an Active Directory group and returns the
# distinguished name.
#=============================================================================
function getGroupDN
  {
  param(
    [string] $groupName = $(throw "Param 'groupName' required in selectGroup.")
    )
  $groupAttributes   = @( "samaccountname", "cn", "distinguishedname", "description" )
  $pickList = @()

  # Create a new .net DirectorySearcher based on our domain
  $searcher = New-Object System.DirectoryServices.DirectorySearcher( $script:domain )
  # Specify the attributes to be returned
  $searcher.PropertiesToLoad.AddRange( $groupAttributes )
  # Set the filter property of the DirectorySearcher object
  $typeClause = "(objectclass=group)"
  $CNClause = "(cn=$groupName)"
  # Put it all together
  $searcher.filter = "(&$typeClause$CNClause)"
  $searcher.PageSize = 1000
  $sortOptions = New-Object System.DirectoryServices.sortoption
  $sortOptions.propertyname = "cn"
  $searcher.sort = $sortOptions

  $count = 0
  foreach ( $group In $searcher.findall() )
    {
    $count++
    $o = New-Object object
    $SAM = [string]$group.properties.samaccountname
    If ( $SAM.length -gt $longestSAM ) { $longestSAM = $SAM.length }
    Add-Member -in $o noteproperty SAM $SAM
    $CN = [string]$group.properties.cn
    If ( $CN.length -gt $longestCN )  { $longestCN = $CN.length }
    Add-Member -in $o noteproperty CN $CN
    $DN = $group.properties.distinguishedname
    $OU = DNtoOU $DN $CN $Script:Domain
    If ( $OU.length -gt $longestOU )  { $longestOU = $OU.length }
    Add-Member -in $o noteproperty DN $DN
    Add-Member -in $o noteproperty OU $OU
    $Descr = $group.properties.description
    Add-Member -in $o noteproperty desc $Descr
    # Add the object to the groups array
    $pickList += $o
    } # foreach
  switch( $count )
    {
    0 {
      Write-Host "No matching groups."
      ""
      }
    1 {
      $pickList[0].DN
      }
    default
      {
      # If there is a lot - does user want to list them all?
      if( $count -ge $threshold )
        {
        $Continue = GetYN( "$Count results returned.  Continue? (y/n)" )
        if( $Continue -eq "N" )
          {
          return ""
          }
      } # if
      $longestNum = ([string]$count).length
      # Build format string
      $fs = "{0,$($longestNum * -1)} {1,$($longestCN * -1)} {2,$($longestSAM * -1)} {3,$($longestOU * -1)}"
      # Write headers
      writeline ([System.String]::Format( $fs, "", "CN", "Pre-W2K", "OU" ))"Descr"
      writeline ([System.String]::Format( $fs, "", "==", "=======", "==" ))"====="
      # Iterate through the array
      $i = 1
      foreach( $o in $pickList )
        {
        writeline ([System.String]::Format( $fs, $i, $($o.CN), $($o.SAM), $($o.OU)))$($o.descr)
        $i++
        }
      $Choice = GetPosInt "Enter number to retrieve group details (Enter to exit)" 1 $count
      # write-host " "
      if( $choice -eq "" )
        {
        ""
        }
      else
        {
        ($pickList[$Choice-1]).DN
        }
      } # default
    } # Switch
  } # function



#=============================================================================
# Recursive function to add all members of an Active Directory group to a
# global array.
#=============================================================================
function addGroupMembersToArray
  {
  param(
    [string] $groupDN = $(throw "Param 'groupDN' required in addGroupMembersToArray.")
    )
  # Get the Directory Entry corresponding to the group distinguished name
  $group = New-Object System.DirectoryServices.DirectoryEntry ( "LDAP://" + $groupDN )

  # Find all users that are members of that group
  # Based on Kaplan & Dunn p. 349
  $userSearcher = New-Object System.DirectoryServices.DirectorySearcher( $group, "(sAMAccountType=805306368)" )
  $userSearcher.set_AttributeScopeQuery( "member" )
  $userSearcher.pagesize = 1000  # This is necessary to cope with big groups.
  $userSearcher.PropertiesToLoad.AddRange( $Attributes )
  foreach( $u in $userSearcher.FindAll() )
    {
    # Some users will be in both a group and separately in one or more
    # nested groups.  So we cannot just add everyone we find to the array.
    # We must check they have not already been added.
    # Unfortunately the -notcontains operator does not work with arrays of objects.
    # (Presumably the array containes only pointers and these are all different?)
    # So I cannot directly compare each new user with the current contents of the
    # $user array.  To work around this I add just the SAMaccountname to a global
    # hashtable.  (Initially I used an array for this, but replacing this with a
    # hashtable speeded processing dramatically.)
    $sam = [string]$u.properties.samaccountname # Not sure why explicit cast is necessary - BUT IT IS!
    if ( ! $script:userNamesHT.containskey( $sam ) )
      {
      $script:userNamesHT.Add( $sam, "" )
      $script:users += $u
      }
    }

  # Find all groups that are members of that group
  $groupSearcher = New-Object System.DirectoryServices.DirectorySearcher( $group, "(objectCategory=group)" )
  $groupSearcher.set_AttributeScopeQuery( "member" )
  $groupSearcher.pagesize = 1000
  [void]$groupSearcher.PropertiesToLoad.Add("distinguishedname")
  foreach( $group in $groupSearcher.FindAll() )
    {
    # Recurse
    addGroupMembersToArray $group.properties.distinguishedname
    }
  }



#=============================================================================
# Displays basic details of chosen group before listing members.
#=============================================================================
function displayGroupHeader
  {
  Param(
    [string] $GroupDN    = $(throw "Param 'targetGroupDN' required in displayGroupHeader.")
    )
  # Get the Directory Entry corresponding to the group distinguished name
  $group = New-Object System.DirectoryServices.DirectoryEntry ( "LDAP://" + $groupDN )
  $groupCN = [string]($group.cn) # Not sure why this cast is needed - but it is.
  $groupSAM = $group.samaccountname # Not sure why this cast is needed - but it is.
  $groupOU = DNtoOU $groupDN $groupCN $Script:domain
  $groupDesc = $group.description
  " "
  "Group name:   $groupCN"
  "Pre W2K name: $groupSAM"
  "OU:           $groupOU"
  "Description:  $groupDesc"
  "Members:"
  }



#======================================================================================
#    O U   M E M B E R S H I P    F U N C T I O N S
#======================================================================================



#=============================================================================
# Top level function to find users in a given OU
#=============================================================================
function findOUMembers
  {
  param(
    [string] $OU = $(throw "Param 'OU' required in findOUmembers.")
    )
  if ( ( OUExists $script:domain $OU ) -eq $null )
    {
    "Cannot connect to this OU."
    exit
    }
  loadOUUsersIntoArray $OU
  }




#=============================================================================
# Pass it objects representing the domain and a path to an OU
# (e.g. ou=inner,ou=outer) then if that OU exists it returns an object
# representing the OU, else it returns $Null.
#=============================================================================
function OUExists
  {
  param(
    [System.DirectoryServices.DirectoryEntry] $domain = $(throw "Param 'domain' required in domainExists."),
    [string] $OU = $(throw "Param 'OU' required in domainExists.")
    )
  # Build the distinguished name of the target OU
  $OUDN = "$OU,$($domain.distinguishedName)"
  # Try connecting to it.
  $objOU = [adsi]"LDAP://$OUDN"
  # If the OU exists and you connect, you get back a valid object
  # representing the OU.  If it does not, I am not sure what you
  # get back - it seems not even to be $null.  Its properties DO
  # however seem to be $null - so test one of them.
  if ( $objOU.distinguishedName -eq $null )
    { $null }
  else
    { $objOU }
  }



#=============================================================================
# Sets up the directory searcher that is used for the look ups.
#=============================================================================
Function loadOUUsersIntoArray
  {
  param(
    [string] $OU = $(throw "Param 'OU' required in findOUmembers.")
    )
  # Get an OU object for our domain
  $OUDN = "$OU,$($domain.distinguishedName)"
  $objOU = [adsi]"LDAP://$OUDN"
  # Create a new .net DirectorySearcher based on our domain
  $script:searcher = New-Object System.DirectoryServices.DirectorySearcher( $objOU )
  # Specify the attributes to be returned
  $script:searcher.PropertiesToLoad.AddRange( $script:Attributes )
  $script:Searcher.PageSize = 1000
  # Set the filter property of the DirectorySearcher object
  $script:searcher.filter = "(&(objectClass=user)(objectcategory=person))"

  # Call the findall() method of the DirectorySearcher object the return the result.
  # The return type will be of type SearchResultCollection which has a property
  # called count
  $script:Users = $script:searcher.findall()
  $Count = $script:Users.Count
  if( $Count -eq 0 )
    {
    "Cannot find any users in this OU."
    exit
    }
  }



#======================================================================================
#    S C R I P T    U S E R    F U N C T I O N S
#======================================================================================


#=============================================================================
# Top level function to find users of an active directory logon script.
#=============================================================================
function findScriptUsers
  {
  param(
    [string] $script = $(throw "Param 'script' required in findScriptUsers.")
    )
  # Create a new .net DirectorySearcher based on our domain
  $script:searcher = New-Object System.DirectoryServices.DirectorySearcher( $script:domain )
  # Specify the attributes to be returned
  $script:searcher.PropertiesToLoad.AddRange( $script:Attributes )
  $script:Searcher.PageSize = 1000
  # Set the filter property of the DirectorySearcher object
  $script:searcher.filter = "(&(objectClass=user)(objectcategory=person)(scriptpath=$script))"

  # Call the findall() method of the DirectorySearcher object the return the result.
  # The return type will be of type SearchResultCollection which has a property
  # called count
  $script:Users = $script:searcher.findall()
  $Count = $script:Users.Count
  if( $Count -eq 0 )
    {
    "Cannot find any users of this script."
    exit
    }
  }



#======================================================================================
#    N A M E   S E A R C H    F U N C T I O N S
#======================================================================================



#=============================================================================
# Initialises the .net Directory Search object that is used to look up users
# by name.
#=============================================================================
function initialiseFUsearcher
  {
  # Create a new .net DirectorySearcher based on our domain
  $script:FUsearcher = New-Object System.DirectoryServices.DirectorySearcher( $script:domain )
  # Specify the attributes to be returned
  $script:FUsearcher.PropertiesToLoad.AddRange(( $script:attributes ))
  # This makes it perform better (?)
  $script:FUSearcher.PageSize = 1000
  # Create a global sortOption object
  $script:sortOptions = New-Object System.DirectoryServices.sortoption
  # Search the sort field for the searcher
  $script:sortOptions.propertyname = "samaccountname"
  $script:FUsearcher.sort = $script:sortOptions
  }



#=============================================================================
# Search for a user specified by SAM account name
#=============================================================================
Function configureSearchByAccountName
  {
  param(
    [string] $SAMName = $(throw "Param 'SAMName' required in configureSearchByAccountName.")
    )

  # Build the filter property of the DirectorySearcher object
  # Object must be a user and a person
  $typeClause = "(objectClass=user)(objectcategory=person)"
  # We are searching for a SAM account name
  $SAMClause = "(sAMAccountName=$SAMName)"
  # Also check for matches on common name (our AD is a mess!)
  $CNClause = "(cn=$SAMName)"
  # Put it all together
  $script:FUsearcher.filter = "(&$typeClause(|$SAMclause$CNClause))"
  # Call the findall() method of the DirectorySearcher object then return the result.
  # The return type will be of type SearchResultCollection which has a property
  # called count.
  ListUsers( $script:FUsearcher.findall() )
  }



#=============================================================================
# Search for a user specified by first name and last name
#=============================================================================
Function configureSearchByFirstLast
  {
  param(
    [string] $first = $(throw "Param 'first' required in configureSearchByFirstLast."),
    [string] $last  = $(throw "Param 'last' required in configureSearchByFirstLast.")
    )
  # Set the filter property of the DirectorySearcher object
  # Object must be a user and a person
  $typeClause = "(objectClass=user)(objectcategory=person)"
  # search by given name and surnmane
  $configureSearchByFirstLastClause = "(&(givenname=$first)(sn=$last))"
  # Also check for matches on common name (our AD is a mess!)
  $CNClause = "(cn=$first $last)"
  # Put it all together
  $script:FUsearcher.filter = "(&$typeClause(|$configureSearchByFirstLastClause$CNClause))"
  # Call the findall() method of the DirectorySearcher object then return the result.
  # The return type will be of type SearchResultCollection which has a property
  # called count
  ListUsers( $script:FUsearcher.findall() )
  }



#=============================================================================
# When a user name lookup returns more than one user, this function presents
# them to the user and has him select the one for whom he wished to retrieve
# details.
#=============================================================================
Function ListUsers
  {
  param(
    [System.DirectoryServices.SearchResultCollection] $users = $(throw "Param '$users' required in ListUsers.")
    )
  $Count = $Users.Count
  switch( $Count )
    {
    0 { "No matching users" }
    1 { # Just one user returned
      DisplayUserDetails( $Users[ 0 ] )
      }
    default # Multiple users returned
      {
      # If there is a lot - does user want to list them all?
      if( $count -ge $threshold )
        {
        $Continue = GetYN( "$Count results returned.  Continue? (y/n)" )
        if( $Continue -eq "N" ) { exit }
      } # if
      # Declare an array to hold them
      $pickList= @()
      # Iterate through the collection
      Foreach( $User in $Users )
        {
        $o = New-Object object
        Add-Member -in $o noteproperty SAM ([string]$user.properties.samaccountname)
                                          # Not sure why cast is needed - but it is.
        $l = $o.SAM.length
        If( $l -gt $LongestSAM ) { $LongestSAM = $l }
        $given = blank $user.properties.givenname
        $sn = blank $user.properties.sn
        Add-Member -in $o noteproperty name "$given $sn"
        $l = $o.name.length
        If( $l -gt $Longestname ) { $Longestname = $l }
        $cn = [string]$user.properties.cn
        $dN = [string]$user.properties.distinguishedname
        Add-Member -in $o noteproperty OU (DNtoOU $DN $CN $Script:Domain)
        $Ticks = $($User.Properties.lastlogontimestamp)
        $LLO = (CalculateLastLogon( $Ticks )).ToShortDateString()
        If( $LLO -eq "01/01/1601" )
          { $LLO = "<Never>" }
        Add-Member -in $o noteproperty LLO $LLO
        $pickList+= $o
        } # foreach
      $longestNumber = ([string]$pickList.length).length
      $i = 1
      # Build format string
      $fs = "{0,$($longestNumber * -1)}  {1,$($longestSAM * -1)}  {2,$($longestName * -1)}  {3,-10}"
      # Write headers
      writeline (([System.String]::Format( $fs, "", "User", "Name", "LLO"))+"  OU")
      writeline (([System.String]::Format( $fs, "", "====", "====", "==="))+"  ==")
      # Iterate through the array
      foreach( $o in $pickList)
        {
        writeline (([System.String]::Format( $fs, $i, $o.sam, $o.name, $o.LLO))+"  $($o.OU)")
        $i++
        }
      $Choice = GetPosInt "Enter user number to retrieve details (Enter to exit)" 1 $count
      if( $Choice -ne "" )
        {
        # Look up selected user
        configureSearchByAccountName $pickList[$choice - 1].SAM
        }
      } # default
    } # switch
  } # function



#=============================================================================
# Pass it user object and it will print out interesting attributes.
# Beware - attribute names must be entirely in lower case.
#=============================================================================
Function DisplayUserDetails
  {
  param(
    [System.DirectoryServices.SearchResult] $user = $(throw "Param 'user' required in DisplayUserDetails.")
    )
  " "
  # Note that attribute names must all be in lowercase
  Set-Variable ADS_UF_ACCOUNTDISABLE 0x02 -option constant
  $Given = $user.Properties.givenname
  $sn = $User.Properties.sn
  "First & last:       $(blank( $Given )) $(blank( $sn ))"
  $SAM = $User.Properties.samaccountname
  "SAM name:           $SAM"
  $CN = $User.Properties.cn
  $DN = $User.Properties.distinguishedname
  "CN:                 $CN"
  $OU = DNtoOU $DN $CN $Script:Domain
  "OU:                 $OU"
  $Descr = $User.Properties.description
  "Description:        $(blank( $Descr ))"
  Write-Host "Disabled:           " -noNewLine
  if ( $($User.Properties.useraccountcontrol) -Band $ADS_UF_ACCOUNTDISABLE )
    { warn-host "Yes" }
  else
    { "No" }
  #-----------------------------------------
  $Ticks = $($User.Properties.lockouttime)
  $LOT = (CalculateLastLogon( $Ticks )).ToShortDateString()
  Write-Host "Locked out:         " -noNewLine
  if( $LOT -eq "01/01/1601" )
    { "No" }
  else
    { warn-host "Yes" }
  #-----------------------------------------
  $Ticks = $($User.Properties.accountexpires)
  #"Ticks = $Ticks"
  if ( $Ticks -eq $script:neverSet -or $Ticks -eq 0 )
    { Write-Host "Expires:            <Never>" }
  else
    {
    $Expires = CalculateLastLogon( $Ticks )
    Write-Host "Expires:            " -NoNewLine
    If( $Expires -le (Get-Date) )
      { warn-host $Expires.ToShortDateString() }
    else
      { $Expires.ToShortDateString() }
    }
  #-----------------------------------------
  $Ticks = $($User.Properties.lastlogontimestamp)
  $LLO = (CalculateLastLogon( $Ticks )).ToShortDateString()
  If( $LLO -eq "01/01/1601" )
    { "Last log on:        <Never>" }
  else
    { "Last log on:        $LLO" }
  $Script = $($User.Properties.scriptpath)
  "Logon script:       $(blank( $Script ))"
  $PP =  $($User.Properties.profilepath)
  "Profile path:       $(blank( $PP ))"
  $HomeDrive = $($User.Properties.homedrive)
  $HomeDir = $($User.Properties.homedirectory)
  If( $HomeDrive -eq $Null )
    { "Home dir:           $(blank( $HomeDir ))" }
  else
    { "Home dir:           $HomeDrive = $(blank( $HomeDir ))" }
  "Group memberships:"
  ListGroups( $($user.properties.distinguishedname)  )
  " "
  }



#=============================================================================
# Pass it the distinguished name of a user and it will print the groups he
# belongs to.  I got this algorithm from http://abhishek225.spaces.live.com
#=============================================================================
Function ListGroups
  {
  param(
    [string] $dn = $(throw "Param 'dn' required in ListGroups.")
    )

  $names = @()

  $user = [ADSI]"LDAP://$dn"
  $user.psbase.refreshCache(@("TokenGroups"))
  $secirc = New-Object System.Security.Principal.IdentityReferenceCollection
  foreach($sidByte in $user.TokenGroups)
    {
    $secirc.Add((New-Object System.Security.Principal.SecurityIdentifier $sidByte,0))
    }
  $fullNames = $secirc.Translate([System.Security.Principal.NTAccount])
  foreach( $name in $fullNames )
    {
    $str = [string]$name
    $group = $str.Split( "\" )
    $names += $group[1]
    }
  foreach ( $group in $names | sort )
    {
    "  $group"
    }
  }



#================================================================================================
#   M A I N    P R O G R A M
#================================================================================================
# Script scope variables
$Help    = $False     # Has the user asked for help?
$getVer  = $False     # As the user asked for script version number?
$useTabs = $False     # User tab character as separator?
$verbose = $False     # Is verbose output requested?
$csv     = $False     # Output as a csv file?
$Names       = @()    # Array to hold names entered on command line
$Users       = @()    # Array to hold user details return by AD query
$userNamesHT = @{}    # Some users will be members of more than one group nested within the
                      # same parent group, so when recursively searching for members of a
                      # group we must check for this to avoid counting some users more than
                      # once.  (Initially I used an array for this.  On my test data set it
                      # took 1m 19s to complete.  I then tried a hashtable.  The same test
                      # took 3 seconds.)
$attributes  = @()    # Array to hold the list of attributes to be retrieved from Active Directory
$domain  = [adsi]""   # Bind to the root of the domain
$searchType = ""      # What kind of search?  By group, OU, etc?
$groupName  = ""      # Name of group to find members of.
$OU         = ""      # Name of OU to find users in.
$scriptName = ""      # Name of script to find users of.
$samName    = ""      # Account name of user to search for.
$firstName  = ""      # First name of user to serach for.
$lastName   = ""      # Last name of user to search for.
$CSVpath    = ""      # Path of CSV file to write output to.

$neverSet   = 9223372036854775807 # Value in an account expires field that has never been set.
$longestNumber   = 0  # Holds width of inter-column padding
$longestSAM      = 0  # Holds width of inter-column padding
$longestName     = 0  # Holds width of inter-column padding
$longestOU       = 0  # Holds width of inter-column padding
$longestPath     = 0  # Holds width of inter-column padding
$longestCN       = 0  # Holds width of inter-column padding
$screenwidth     = $host.ui.rawui.maxwindowsize.width   # How many columns
$screenheight    = $host.ui.rawui.maxwindowsize.height  # How many rows


# How many to list before asking for confirmation?
Set-Variable threshold 10 -option constant

# Controls operation of string search functions
$ignoreCase = [System.StringComparison]::CurrentCultureIgnoreCase


#clear-host
checkDomainLevel
readArguments
#debug


If( $Help )
  {
  GiveHelp
  exit
  }
if ( $getVer )
  {
  "Version $verNum"
  exit
  }

if ( ( $Names.length -lt 1 ) -or ( $Names.length -gt 2 ) )
  {
  GiveHelp
  }
else
  {
  establishSearchType
  specifyAttributes
  if ( $searchType -eq "FU1" )
    {
    initialiseFUsearcher
    configureSearchByAccountName $samName
    }
  elseif ( $searchType -eq "FU2" )
    {
    initialiseFUsearcher
    configureSearchByFirstLast $firstName $lastName
    }
  else
    {
    switch ( $searchType )
      {
      "LM" { findGroupMembers $groupName }
      "OU" { findOUMembers    $OU }
      "SC" { findScriptUsers  $scriptName }
      default
        { "Internal error: Unknown search type" }
      } # switch
    if ( $csv )
      {
      $csvPath = getCSVPath
      if ( $csvPath -eq "" )
        {
        exit
        }
      else
        {
        writeToCSV $csvPath
        }
      }
    else
      {
      # Normal and verbose modes
      getColumnWidths
      writeOutput
      }
    }
  }

