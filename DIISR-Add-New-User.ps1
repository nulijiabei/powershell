[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") 

Function createmailbox{
	foreach($row in $dgDataGrid.rows){
		if ($row.Cells[0].Value -ne $null){
			$psSecurePasswordString = new-object System.Security.SecureString
			foreach($char in $row.Cells[5].Value.ToCharArray())
		        {
				$psSecurePasswordString.AppendChar($char)
			}
			$result = New-mailbox -UserPrincipalName $row.Cells[0].Value  -alias $row.Cells[4].Value -database $MBhash1[$msMailStoreDrop.SelectedItem.ToString()] `
			-Name $row.Cells[3].Value  -OrganizationalUnit $OUhash1[$ouOuNameDrop.SelectedItem.ToString()] -password $psSecurePasswordString `
			-FirstName $row.Cells[1].Value -LastName $row.Cells[2].Value -DisplayName $row.Cells[3].Value
			if($result -ne $null){
				[system.windows.forms.messagebox]::Show("Mailbox " + $result + " Created")
				}
			else{
				[system.windows.forms.messagebox]::Show("Error createing " + $row.Cells[0].Value + " check cmdline")
			}
			
		}
	}

}

$OUhash1 = @{ }
$MBhash1 = @{ }

$form = new-object System.Windows.Forms.form 
$form.Text = "DIISRTE - User Provision (PROTECTED)"
$form.size = new-object System.Drawing.Size(1024,768) 

$msTable = New-Object System.Data.DataTable

$msTable.TableName = "GroupName"
$msTable.Columns.Add("UPN-AccountName")
$msTable.Columns.Add("FirstName")
$msTable.Columns.Add("LastName")
$msTable.Columns.Add("DisplayName")
$msTable.Columns.Add("Alias")
$msTable.Columns.Add("Password")


# Add DataGrid View

$dgDataGrid = new-object System.windows.forms.DataGridView
$dgDataGrid.Location = new-object System.Drawing.Size(10,10) 
$dgDataGrid.size = new-object System.Drawing.Size(750,200)
$dgDataGrid.AutoSizeRowsMode = "AllHeaders"
$form.Controls.Add($dgDataGrid)

$dgDataGrid.DataSource = $msTable

# Add OU Drop Down
$ouOuNameDrop = new-object System.Windows.Forms.ComboBox
$ouOuNameDrop.Location = new-object System.Drawing.Size(100,260)
$ouOuNameDrop.Size = new-object System.Drawing.Size(230,30)
$ouOuNameDrop.Items.Add("/Users")
$OUhash1.Add("/Users","Users")
$root = [ADSI]''
$searcher = new-object System.DirectoryServices.DirectorySearcher($root)
$searcher.Filter = '(objectClass=organizationalUnit)'
$searcher.PropertiesToLoad.Add("canonicalName")
$searcher.PropertiesToLoad.Add("Name")
$searcher1 = $searcher.FindAll()
foreach ($person in $searcher1){ 
[string]$ent = $person.Properties.canonicalname
$OUhash1.Add($ent.substring($ent.indexof("/"),$ent.length-$ent.indexof("/")),$ent)
$ouOuNameDrop.Items.Add($ent.substring($ent.indexof("/"),$ent.length-$ent.indexof("/")))
}
$form.Controls.Add($ouOuNameDrop)


# Add OU DropLable
$ouOuNamelableBox = new-object System.Windows.Forms.Label
$ouOuNamelableBox.Location = new-object System.Drawing.Size(10,260) 
$ouOuNamelableBox.size = new-object System.Drawing.Size(100,20) 
$ouOuNamelableBox.Text = "OU Name"
$form.Controls.Add($ouOuNamelableBox) 

# Add Server Drop Down
$snServerNameDrop = new-object System.Windows.Forms.ComboBox
$snServerNameDrop.Location = new-object System.Drawing.Size(100,290)
$snServerNameDrop.Size = new-object System.Drawing.Size(130,30)
get-mailboxserver | ForEach-Object{$snServerNameDrop.Items.Add($_.Name)}
$snServerNameDrop.Add_SelectedValueChanged({
	$msMailStoreDrop.Items.Clear()
	get-mailboxdatabase -Server $snServerNameDrop.SelectedItem.ToString()| ForEach-Object{$msMailStoreDrop.Items.Add($_.Name)
	$MBhash1.add($_.Name,$_.ServerName + "\" + $_.StorageGroup.Name + "\" + $_.Name) 	
	}
})  
$form.Controls.Add($snServerNameDrop)

# Add Server DropLable
$snServerNamelableBox = new-object System.Windows.Forms.Label
$snServerNamelableBox.Location = new-object System.Drawing.Size(10,290) 
$snServerNamelableBox.size = new-object System.Drawing.Size(100,20) 
$snServerNamelableBox.Text = "ServerName"
$form.Controls.Add($snServerNamelableBox) 

# Add MailStore Drop Down
$msMailStoreDrop = new-object System.Windows.Forms.ComboBox
$msMailStoreDrop.Location = new-object System.Drawing.Size(100,320)
$msMailStoreDrop.Size = new-object System.Drawing.Size(130,30)
$form.Controls.Add($msMailStoreDrop)

# Add MailStore DropLable
$msMailStorelableBox = new-object System.Windows.Forms.Label
$msMailStorelableBox.Location = new-object System.Drawing.Size(10,320) 
$msMailStorelableBox.size = new-object System.Drawing.Size(100,20) 
$msMailStorelableBox.Text = "Mail-Store"
$form.Controls.Add($msMailStorelableBox) 

# Add Create Button

$crButton = new-object System.Windows.Forms.Button
$crButton.Location = new-object System.Drawing.Size(10,360)
$crButton.Size = new-object System.Drawing.Size(150,23)
$crButton.Text = "Add User"
$crButton.Add_Click({CreateMailbox})
$form.Controls.Add($crButton)

$form.topmost = $true
$form.Add_Shown({$form.Activate()})
$form.ShowDialog()
