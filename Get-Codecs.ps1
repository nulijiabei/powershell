[string[]]$key = "SOFTWARE\Classes\CLSID\{083863F1-70DE-11d0-BD40-00A0C911CE86}\Instance",
                 "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Drivers32"

function ModuleInfo([string]$path) {
  $item.SubItems.Add((gci $path).VersionInfo.CompanyName)
  $item.SubItems.Add((gci $path).VersionInfo.FileDescription)
}

function ItemsCount {
  $sbCount.Text = $lvPage1.Items.Count.ToString() + " item(s)"
}

$mnuScan_Click= {
  #clear both ListView before each scan
  $lvPage1.Items.Clear()
  $lvPage2.Items.Clear()

  <#
    Do not use Get-ChildItem cmdlet if you want quick scan!
  #>
  $reg = [Microsoft.Win32.Registry]::LocalMachine

  $rk = $reg.OpenSubKey($key[0])
  $rk.GetSubKeyNames() | % {
    #adding name of filters
    $name = $reg.OpenSubKey($($key[0] + "\" + $_))
    $item = $lvPage1.Items.Add($name.GetValue("FriendlyName"))
    $name.Close()
    #adding its CLSID
    $item.SubItems.Add($_)
    #adding path and additional info of filters
    $path = $reg.OpenSubKey($("SOFTWARE\Classes\CLSID\" + "\" + $_ + "\InprocServer32"))
    $item.SubItems.Add($path.GetValue(""))
    ModuleInfo($path.GetValue(""))
    $path.Close()
  }
  $rk.Close()

  $rk = $reg.OpenSubKey($key[1])
  $rk.GetValueNames() | % {
    $item = $lvPage2.Items.Add($_)

    #hypothetical directory
    $file = $rk.GetValue($_)
    if (-not (Test-Path $file)) {
      #another possible directory of driver
      $pos = [Environment]::SystemDirectory + "\" + $file
      if (Test-Path $pos) {
        $item.SubItems.Add($pos)
        ModuleInfo($pos)
      }
    }
    else {
      $item.SubItems.Add($file)
      ModuleInfo($file)
    }
  }
  $rk.Close()

  ItemsCount
}

$tcPage2_Enter= {
  $sbCount.Text = $lvPage2.Items.Count.ToString() + " item(s)"
}

#this is about form load function
$frmMain_Load= {
  try {
    $icon = [Drawing.Icon]::ExtractAssociatedIcon($($pshome + "\powershell.exe"))
    $pbImage.Image = $icon.ToBitmap()
  }
  catch {}
}

function frmMain_Show {
  Add-Type -AssemblyName System.Windows.Forms
  [Windows.Forms.Application]::EnableVisualStyles()

  $frmMain = New-Object Windows.Forms.Form
  $mnuMain = New-Object Windows.Forms.MainMenu
  $mnuFile = New-Object Windows.Forms.MenuItem
  $mnuScan = New-Object Windows.Forms.MenuItem
  $mnuExit = New-Object Windows.Forms.MenuItem
  $mnuHelp = New-Object Windows.Forms.MenuItem
  $mnuInfo = New-Object Windows.Forms.MenuItem
  $tabCtrl = New-Object Windows.Forms.TabControl
  $tcPage1 = New-Object Windows.Forms.TabPage
  $lvPage1 = New-Object Windows.Forms.ListView
  $chFName = New-Object Windows.Forms.ColumnHeader
  $chCLSID = New-Object Windows.Forms.ColumnHeader
  $chFPath = New-Object Windows.Forms.ColumnHeader
  $chFPubl = New-Object Windows.Forms.ColumnHeader
  $chFDesc = New-Object Windows.Forms.ColumnHeader
  $tcPage2 = New-Object Windows.Forms.TabPage
  $lvPage2 = New-Object Windows.Forms.ListView
  $chDName = New-Object Windows.Forms.ColumnHeader
  $chDPath = New-Object Windows.Forms.ColumnHeader
  $chDPubl = New-Object Windows.Forms.ColumnHeader
  $chDDesc = New-Object Windows.Forms.ColumnHeader
  $sbCount = New-Object Windows.Forms.StatusBar
  #
  #mnuMain
  #
  $mnuMain.MenuItems.AddRange(@($mnuFile, $mnuHelp))
  #
  #mnuFile
  #
  $mnuFile.MenuItems.AddRange(@($mnuScan, $mnuExit))
  $mnuFile.Text = "&File"
  #
  #mnuScan
  #
  $mnuScan.Shortcut = "F5"
  $mnuScan.Text = "&Scan"
  $mnuScan.Add_Click($mnuScan_Click)
  #
  #mnuExit
  #
  $mnuExit.Shortcut = "CtrlX"
  $mnuExit.Text = "E&xit"
  $mnuExit.Add_Click({$frmMain.Close()})
  #
  #mnuHelp
  #
  $mnuHelp.MenuItems.AddRange(@($mnuInfo))
  $mnuHelp.Text = "&Help"
  #
  #mnuInfo
  #
  $mnuInfo.Text = "About"
  $mnuInfo.Add_Click({frmAbout_Show})
  #
  #tabCtrl
  #
  $tabCtrl.Controls.AddRange(@($tcPage1, $tcPage2))
  $tabCtrl.Dock = "Fill"
  #
  #tcPage1
  #
  $tcPage1.Controls.AddRange(@($lvPage1))
  $tcPage1.Text = "DirectShow"
  $tcPage1.UseVisualStyleBackColor = $true
  $tcPage1.Add_Enter($tcPage1_Enter)
  #
  #lvPage1
  #
  $lvPage1.AllowColumnReorder = $true
  $lvPage1.Columns.AddRange(@($chFName, $chCLSID, $chFPath, $chFPubl, $chFDesc))
  $lvPage1.Dock = "Fill"
  $lvPage1.FullRowSelect = $true
  $lvPage1.GridLines = $false
  $lvPage1.MultiSelect = $false
  $lvPage1.ShowItemToolTips = $true
  $lvPage1.Sorting = "Ascending"
  $lvPage1.View = "Details"
  #
  #chFName
  #
  $chFName.Text = "Name"
  $chFName.Width = 110
  #
  #chCLSID
  #
  $chCLSID.Text = "CLSID"
  $chCLSID.Width = 241
  #
  #chFPath
  #
  $chFPath.Text = "Path"
  $chFPath.Width = 215
  #
  #chFPubl
  #
  $chFPubl.Text = "Publisher"
  $chFPubl.Width = 145
  #
  #chFDesc
  #
  $chFDesc.Text = "Description"
  $chFDesc.Width = 300
  #
  #tcPage2
  #
  $tcPage2.Controls.AddRange(@($lvPage2))
  $tcPage2.Text = "Drivers"
  $tcPage2.UseVisualStyleBackColor = $true
  $tcPage2.Add_Enter($tcPage2_Enter)
  #
  #lvPage2
  #
  $lvPage2.AllowColumnReorder = $true
  $lvPage2.Columns.AddRange(@($chDName, $chDPath, $chDPubl, $chDDesc))
  $lvPage2.Dock = "Fill"
  $lvPage2.FullRowSelect = $true
  $lvPage2.GridLines = $false
  $lvPage2.MultiSelect = $false
  $lvPage2.ShowItemToolTips = $true
  $lvPage2.Sorting = "Ascending"
  $lvPage2.View = "Details"
  #
  #chDName
  #
  $chDName.Text = "Name"
  $chDName.Width = 100
  #
  #chDPath
  #
  $chDPath.Text = "Path"
  $chDPath.Width = 210
  #
  #chDPubl
  #
  $chDPubl.Text = "Publisher"
  $chDPubl.Width = 145
  #
  #chDDesc
  #
  $chDDesc.Text = "Description"
  $chDDesc.Width = 300
  #
  #sbCount
  #
  $sbCount.SizingGrip = $false
  #
  #frmMain
  #
  $frmMain.ClientSize = New-Object Drawing.Size(573, 217)
  $frmMain.Controls.AddRange(@($tabCtrl, $sbCount))
  $frmMain.Menu = $mnuMain
  $frmMain.StartPosition = "CenterScreen"
  $frmMain.Text = "Codecs"

  [void]$frmMain.ShowDialog()
}

function frmAbout_Show {
  $frmMain = New-Object Windows.Forms.Form
  $pbImage = New-Object Windows.Forms.PictureBox
  $lblName = New-Object Windows.Forms.Label
  $lblCopy = New-Object Windows.Forms.Label
  $btnExit = New-Object Windows.Forms.Button
  #
  #pbImage
  #
  $pbImage.Location = New-Object Drawing.Point(16, 16)
  $pbImage.Size = New-Object Drawing.Size(32, 32)
  $pbImage.SizeMode = "StretchImage"
  #
  #lblName
  #
  $lblName.Font = New-Object Drawing.Font("Microsoft Sans Serif", 9, [Drawing.FontStyle]::Bold)
  $lblName.Location = New-Object Drawing.Size(53, 19)
  $lblName.Size = New-Object Drawing.Size(360, 18)
  $lblName.Text = "Codecs v1.00"
  #
  #lblCopy
  #
  $lblCopy.Location = New-Object Drawing.Point(67, 37)
  $lblCopy.Size = New-Object Drawing.Size(360, 23)
  $lblCopy.Text = "(C) 2012 Greg Zakharov gregzakh@gmail.com"
  #
  #btnExit
  #
  $btnExit.Location = New-Object Drawing.Point(135, 67)
  $btnExit.Text = "OK"
  #
  #frmMain
  #
  $frmMain.AcceptButton = $btnExit
  $frmMain.CancelButton = $btnExit
  $frmMain.ClientSize = New-Object Drawing.Size(350, 110)
  $frmMain.ControlBox = $false
  $frmMain.Controls.AddRange(@($pbImage, $lblName, $lblCopy, $btnExit))
  $frmMain.FormBorderStyle = "FixedSingle"
  $frmMain.ShowInTaskbar = $false
  $frmMain.StartPosition = "CenterScreen"
  $frmMain.Text = "About..."
  $frmMain.Add_Load($frmMain_Load)

  [void]$frmMain.ShowDialog()
}

frmMain_Show