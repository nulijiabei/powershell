# Functions for connecting to and working with Access databases
# Matt Wilson
# May 2009

function Connect-AccessDB ($global:dbFilePath) {
	
	# Test to ensure valid path to database file was supplied
	if (-not (Test-Path $dbFilePath)) {
		Write-Error "Invalid Access database path specified. Please supply full absolute path to database file!"
	}
	
	# TO-DO: Add check to ensure file is either MDB or ACCDB
	
	# Create a new ADO DB connection COM object, which will give us useful methods & properties such as "Execute"!
	$global:AccessConnection = New-Object -ComObject ADODB.Connection
	
	# Actually open the database so we can start working with its contents
	# Access 00-03 (MDB) format has a different connection string than 2007
	if ((Split-Path $dbFilePath -Leaf) -match [regex]"\.mdb$") {
		Write-Host "Access 2000-2003 format (MDB) detected!  Using Microsoft.Jet.OLEDB.4.0."
		$AccessConnection.Open("Provider = Microsoft.Jet.OLEDB.4.0; Data Source= $dbFilePath")
	}
	
	# Here's the check for if 2007 connection is necessary
	if ((Split-Path $dbFilePath -Leaf) -match [regex]"\.accdb$") {
		Write-Host "Access 2007 format (ACCDB) detected!  Using Microsoft.Ace.OLEDB.12.0."
		$AccessConnection.Open("Provider = Microsoft.Ace.OLEDB.12.0; Persist Security Info = False; Data Source= $dbFilePath")
	} 
}

function Open-AccessRecordSet ($global:SqlQuery) {

	# Ensure SQL query isn't null
	if ($SqlQuery.length -lt 1) {
		Throw "Please supply a SQL query for the recordset selection!"
	}
	
	# Variables used for the connection itself.  Leave alone unless you know what you're doing.
	$adOpenStatic = 3
	$adLockOptimistic = 3
	
	# Create the recordset object using the ADO DB COM object
	$global:AccessRecordSet = New-Object -ComObject ADODB.Recordset
	
	# Finally, go and get some records from the DB!
	$AccessRecordSet.Open($SqlQuery, $AccessConnection, $adOpenStatic, $adLockOptimistic)	
}

function Get-AccessRecordSetStructure {
	# TO-DO: Should probably test to ensure valid $accessRecordSet exists & has records
	
	# Cycle through the fields in the recordset, but only pull out the properties we care about
	Write-Output $AccessRecordSet.Fields | Select-Object Name,Attributes,DefinedSize,type
}
	
function Convert-AccessRecordSetToPSObject {
	# TO-DO: Should probably test to ensure valid $accessRecordSet exists & has records
	
	# Get an array of field names which we will later use to create custom PoSh object names
	$fields = Get-AccessRecordSetStructure
	
	# Move to the very first record in the RecordSet before cycling through each one
	$AccessRecordSet.MoveFirst()
		
	# Cycle through each RECORD in the set and create that record to an object
	do {
		# Create a SINGLE blank object we can use in a minute to add properties/values to
		$record = New-Object System.Object
		
		# For every FIELD in the DB, lookup the CURRENT value of that field and add a new PoSh object property with that name and value
		foreach ($field in $fields) {
			$fieldName = $field.Name   # This makes working with the name a LOT easier in Write-Host, etc.
			#Write-Host "Working with field: $fieldName"
			#Write-Host "Preparing to set value to: $($AccessRecordset.Fields.Item($fieldName).Value)"
			$record | Add-Member -type NoteProperty -name $fieldName -value $AccessRecordSet.Fields.Item($fieldName).Value
		}
		# Output the custom object we just created
		Write-Output $record
		
		# Tell the recordset to advance forward one before doing this again with another object
		$AccessRecordset.MoveNext()
		
	} until ($AccessRecordset.EOF -eq $True)

}

function Execute-AccessSQLStatement ($query) {
	$AccessConnection.Execute($query)
}

function Convert-AccessTypeCode ([string]$typeCode) {
	
	# Build some lookup tables for our Access type codes so we can convert values pretty easily
	$labelLookupHash = @{"AutoNumber"="3"; "Text"="202"; "Memo"="203"; "Date/Time"="7"; "Currency"="6"; "Yes/No"="11"; "OLE Object"="205"; "Byte"="17"; "Integer"="2"; "Long Integer"="3"; "Single"="4"; "Double"="5"}
	$codeLookupHash =  @{"3"="AutoNumber"; "202"="Text"; "203"="Memo"; "7"="Date/Time"; "6"="Currency"; "11"="Yes/No"; "205"="OLE Object"; "17"="Byte"; "2"="Integer"; "3"="Long Integer"; "4"="Single"; "5"="Double"}
	
	# Convert a value depending on what type of data was supplied
	if ($typeCode -match [regex]"^\d{1,3}$") {
		$valueFound = $codeLookupHash.$typeCode
		if ($valueFound) {
			Write-Output $valueFound
		} else { Write-Output "Unknown" }
	} else {
		$valueFound = $labelLookupHash.$typeCode
		if ($valueFound) {
			Write-Output $valueFound
		} else { Write-Output "Unknown" }
	}

}

function Close-AccessRecordSet {
	$AccessRecordSet.Close()
}

function Disconnect-AccessDB {
	$AccessConnection.Close()
}


# Connect-AccessDB "C:\fso\ConfigurationMaintenance.accdb"
# Open-AccessRecordSet "SELECT * FROM printers"
# $printersDB = Convert-AccessRecordSetToPSObject | Select-Object caption,driverName | Format-Table -AutoSize; $printersDB
# Close-AccessRecordSet
# Disconnect-AccessDB