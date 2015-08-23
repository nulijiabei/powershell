Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework

[xml]$XAML = @'
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Width="316" MinWidth="316" MaxWidth="316"
    Title="Local Admins Tool" SizeToContent="WidthAndHeight" FontSize="14" FontFamily="Consolas" Name="Window">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition MinWidth="100"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
            <RowDefinition Height="30"/>
            <RowDefinition Height="30"/>
            <RowDefinition Height="30"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Label Content="Computer: " Grid.Column="0" />
        <TextBox Grid.Column="1" Name="TextBoxComputer"/>
        <Label Content="Domain: " Grid.Column="0" Grid.Row="1"/>
        <ComboBox Grid.Column="1" Grid.Row="1" Name="ComboDomain">
            <ComboBox.Items>
                <ComboBoxItem Content="FOO"/>
                <ComboBoxItem Content="BAR"/>
                <ComboBoxItem Content="ALP"/>
                <ComboBoxItem Content="BET"/>
                <ComboBoxItem Content="GAM"/>
                <ComboBoxItem Content="DEL"/>
            </ComboBox.Items>
        </ComboBox>
        <StackPanel Grid.ColumnSpan="2" Grid.Row="2" Orientation="Horizontal">
            <Button Name="ButtonList" Content="Check" Width="100"/>
            <Button Name="ButtonAdd" Content="Add" Width="100"/>
            <Button Name="ButtonCancel" Content="Cancel" Width="100"/>
        </StackPanel>
        <ListBox Grid.ColumnSpan="3" Grid.Row="3" Name="AdminsList"/>
        
    </Grid>
</Window>
'@

$Reader = New-Object System.Xml.XmlNodeReader $XAML
$Dialog = [Windows.Markup.XamlReader]::Load($Reader)
foreach ($Name in ($XAML | Select-Xml '//*/@Name' | foreach { $_.Node.Value})) {
    New-Variable -Name $Name -Value $Dialog.FindName($Name) -Force
}

$AddScriptBlock = {
    if ($_.Key) {
        if ($_.Key -ne 'Enter') {
            return
        }
    }

    $ComputerName = $TextBoxComputer.Text.Trim()
    $AdminsList.Items.Clear()
    $AdminsList.Items.Add(
        (New-Object System.Windows.Controls.ListBoxItem -Property @{
            Content = "Adding admin account to: $ComputerName"
            FontWeight = 'Bold'
        })
    )

    if ($ComputerName -notmatch '^[a-z]{3}\d{6}$') {
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{
                Content = "Wrong computer name: $ComputerName"
                Foreground = 'Red'
            }
        ))
        return
    }

    $DomainName = $ComboDomain.SelectedItem.Content
    
    if (!$PredictDomain) {
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{
                Content = "Error: can't find workstation $ComputerName in AD!"
                Foreground = 'Red'
            }
        ))
        return
    }

    if (!$DomainName) {
        $DomainName = $PredictDomain
    }

    try {
        Invoke-Command -ComputerName Endpoints -ConfigurationName $PredictDomain -ScriptBlock {
            param ($Computer, $Domain)
            Add-LocalAdmin -ComputerName $Computer -Domain $Domain
        } -ArgumentList $ComputerName, $DomainName -ErrorAction Stop
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{
                Content = 'Done!'
                Foreground = 'Green'
            })
        )

    } catch {
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{
                Content = "Error: $_"
                Foreground = 'Red'
            }
        ))
    }
}

$TextChangedScriptBlock = {
    switch -Regex ($this.Text.Trim()) {
        '^[a-z]{3}\d{6}$' {
            $this.Background = 'LawnGreen'
            
            # And now we  can check domain and try to change ComboBox value...
            $Searcher = New-Object ADSISearcher -ArgumentList @(
                [ADSI]'GC://DC=domain,DC=local',
                "(&(objectClass=computer)(Name=$_))"
            )
            $Global:PredictDomain = $Searcher.FindOne().Path -replace 'GC.*?,DC=([^,]*),.*', '$1'
            $ComboDomain.Items | ForEach-Object {
                if ($_.Content -eq $PredictDomain) {
                    $ComboDomain.SelectedItem = $_
                }
            }
            if (!$Global:PredictDomain) {
                $ComboDomain.SelectedItem = $null
            }
            
        }
        ^$ {
            $this.Background = 'White'
            $Global:PredictDomain = $null
        }
        default {
            $this.Background = 'LightCoral'
            $Global:PredictDomain = $null
        }
    }

}

$ListScriptBlock = {

    if ($_.Key) {
        if ($_.Key -ne 'Enter') {
            return
        }
    }

    $AdminsList.Items.Clear()
    $ComputerName = $TextBoxComputer.Text
    if ($ComputerName -notmatch '^[a-z]{3}\d{6}$') {
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{
                Content = "Wrong computer name!"
                Foreground = 'Red'
            }
        ))
        return
    }

    if (!$PredictDomain) {
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{
                Content = "Error: can't find workstation $ComputerName in AD!"
                Foreground = 'Red'
            }
        ))
        return
    }

    try {
        $AdminsList.Items.Clear()
        $AdminsList.Items.Add("Administrators on computer $ComputerName :")
        Invoke-Command -ComputerName Endpoints -ConfigurationName $PredictDomain -ScriptBlock {
            param ($Computer)
            Get-LocalAdmin -ComputerName $Computer
        } -ArgumentList $ComputerName -ErrorAction Stop | ForEach-Object {
            $AdminsList.Items.Add($_)
        }
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{ 
                Content = "Done!"
                ForeGround = 'Green'
            }
        ))
    } catch {
        $AdminsList.Items.Add(
            (New-Object System.Windows.Controls.ListBoxItem -Property @{
                Content = "Error: $_"
                Foreground = 'Red'
            }
        ))
    }

}

$TextBoxComputer.Add_KeyDown($ListScriptBlock)
$ButtonAdd.Add_Click($AddScriptBlock)
$ButtonList.Add_Click($ListScriptBlock)
$TextBoxComputer.Add_TextChanged($TextChangedScriptBlock)
$ButtonCancel.Add_Click({$window.Close()})

$Dialog.Add_Loaded( {
    $this.TopMost = $true
})

$Dialog.ShowDialog() | Out-Null

# SIG # Begin signature block
# MIIj1wYJKoZIhvcNAQcCoIIjyDCCI8QCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVgPTlBoK1nvEkL+j1d3tsR3x
# 4o2ggh8FMIIETzCCA7igAwIBAgIEBydYPTANBgkqhkiG9w0BAQUFADB1MQswCQYD
# VQQGEwJVUzEYMBYGA1UEChMPR1RFIENvcnBvcmF0aW9uMScwJQYDVQQLEx5HVEUg
# Q3liZXJUcnVzdCBTb2x1dGlvbnMsIEluYy4xIzAhBgNVBAMTGkdURSBDeWJlclRy
# dXN0IEdsb2JhbCBSb290MB4XDTEwMDExMzE5MjAzMloXDTE1MDkzMDE4MTk0N1ow
# bDELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNlcnQgSGlnaCBBc3N1cmFu
# Y2UgRVYgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMbM
# 5XPm+9S75S0tMqbf5YE/yc0lSbZxKsPVlDRnogocsF9ppkCxxLeyj9CYpKlBWTrT
# 3JTWPNt0OKRKzE0lgvdKpVMSOO7zSW1xkX5jtqumX8OkhPhPYlG++MXs2ziS4wbl
# CJEMxChBVfvLWokVfnHoNb9Ncgk9vjo4UFt3MRuNs8ckRZqnrG0AFFoEt7oT61EK
# mEFBIk5lYYeBQVCmeVyJ3hlKV9Uu5l0cUyx+mM0aBhakaHPQNAQTXKFx01p8Vdte
# ZOE3hzBWBOURtCmAEvF5OYiiAhF8J2a3iLd48soKqDirCmTCv2ZdlYTBoSUeh10a
# UAsgEsxBu24LUTi4S8sCAwEAAaOCAW8wggFrMBIGA1UdEwEB/wQIMAYBAf8CAQEw
# UwYDVR0gBEwwSjBIBgkrBgEEAbE+AQAwOzA5BggrBgEFBQcCARYtaHR0cDovL2N5
# YmVydHJ1c3Qub21uaXJvb3QuY29tL3JlcG9zaXRvcnkuY2ZtMA4GA1UdDwEB/wQE
# AwIBBjCBiQYDVR0jBIGBMH+heaR3MHUxCzAJBgNVBAYTAlVTMRgwFgYDVQQKEw9H
# VEUgQ29ycG9yYXRpb24xJzAlBgNVBAsTHkdURSBDeWJlclRydXN0IFNvbHV0aW9u
# cywgSW5jLjEjMCEGA1UEAxMaR1RFIEN5YmVyVHJ1c3QgR2xvYmFsIFJvb3SCAgGl
# MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly93d3cucHVibGljLXRydXN0LmNvbS9j
# Z2ktYmluL0NSTC8yMDE4L2NkcC5jcmwwHQYDVR0OBBYEFLE+w2kD+L9HAdSYJhoI
# Au9jZCvDMA0GCSqGSIb3DQEBBQUAA4GBAC52hdk3lm2vifMGeIIxxEYHH2XJjrPJ
# VHjm0ULfdS4eVer3+psEwHV70Xk8Bex5xFLdpgPXp1CZPwVZ2sZV9IacDWejSQSV
# Mh3Hh+yFr2Ru1cVfCadAfRa6SQ2i/fbfVTBs13jGuc9YKWQWTKMggUexRJKEFhtv
# Srwhxgo97TPKMIIGbzCCBVegAwIBAgIQA4uW8HDZ4h5VpUJnkuHIOjANBgkqhkiG
# 9w0BAQUFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1
# cmVkIElEIENBLTEwHhcNMTIwNDA0MDAwMDAwWhcNMTMwNDE4MDAwMDAwWjBHMQsw
# CQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNlcnQxJTAjBgNVBAMTHERpZ2lDZXJ0
# IFRpbWVzdGFtcCBSZXNwb25kZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQDGf7tj+/F8Q0mIJnRfituiDBM1pYivqtEwyjPdo9B2gRXW1tvhNC0FIG/B
# ofQXZ7dN3iETYE4Jcq1XXniQO7XMLc15uGLZTzHc0cmMCAv8teTgJ+mn7ra9Depw
# 8wXb82jr+D8RM3kkwHsqfFKdphzOZB/GcvgUnE0R2KJDQXK6DqO+r9L9eNxHlRdw
# bJwgwav5YWPmj5mAc7b+njHfTb/hvE+LgfzFqEM7GyQoZ8no89SRywWpFs++42Pf
# 6oKhqIXcBBDsREA0NxnNMHF82j0Ctqh3sH2D3WQIE3ome/SXN8uxb9wuMn3Y07/H
# iIEPkUkd8WPenFhtjzUmWSnGwHTPAgMBAAGjggM6MIIDNjAOBgNVHQ8BAf8EBAMC
# B4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCCAcQGA1Ud
# IASCAbswggG3MIIBswYJYIZIAYb9bAcBMIIBpDA6BggrBgEFBQcCARYuaHR0cDov
# L3d3dy5kaWdpY2VydC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsG
# AQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABD
# AGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABh
# AGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQBy
# AHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBn
# ACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABs
# AGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABp
# AG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBl
# AGYAZQByAGUAbgBjAGUALjAfBgNVHSMEGDAWgBQVABIrE5iymQftHt+ivlcNK2cC
# zTAdBgNVHQ4EFgQUJqoP9EMNo5gXpV8S9PiSjqnkhDQwdwYIKwYBBQUHAQEEazBp
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUH
# MAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RENBLTEuY3J0MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3JsMDigNqA0hjJodHRwOi8vY3Js
# NC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNybDANBgkqhkiG
# 9w0BAQUFAAOCAQEAvCT5g9lmKeYy6GdDbzfLaXlHl4tifmnDitXp13GcjqH52v4k
# 498mbK/g0s0vxJ8yYdB2zERcy+WPvXhnhhPiummK15cnfj2EE1YzDr992ekBaoxu
# vz/PMZivhUgRXB+7ycJvKsrFxZUSDFM4GS+1lwp+hrOVPNxBZqWZyZVXrYq0xWzx
# FjObvvA8rWBrH0YPdskbgkNe3R2oNWZtNV8hcTOgHArLRWmJmaX05mCs7ksBKGyR
# lK+/+fLFWOptzeUAtDnjsEWFuzG2wym3BFDg7gbFFOlvzmv8m7wkfR2H3aiObVCU
# NeZ8AB4TB5nkYujEj7p75UsZu62Y9rXC8YkgGDCCBqcwggWPoAMCAQICEAi8iRJ7
# eZMavRDMJtoY/+kwDQYJKoZIhvcNAQEFBQAwczELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEyMDAG
# A1UEAxMpRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2UgQ29kZSBTaWduaW5nIENBLTEw
# HhcNMTIwMzE3MDAwMDAwWhcNMTMwMzIxMTIwMDAwWjB1MQswCQYDVQQGEwJQTDEb
# MBkGA1UECBMSWmFjaG9kbmlvcG9tb3Jza2llMREwDwYDVQQHEwhLb3N6YWxpbjEa
# MBgGA1UEChMRQmFydG9zeiBCaWVsYXdza2kxGjAYBgNVBAMTEUJhcnRvc3ogQmll
# bGF3c2tpMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4lBBMNWpH82J
# 81h5AQn2RPH3hFOYPZHHWI1rDKtrJ+x6fgGb1lsLprr+qzbtDqJ4i3PrdgPtHKV1
# KXhW4i6Xo4X+zmkcKaO9TTEKWt+78JxiITkdsmEoOcS88zH7zHoIODdJ250DFfIL
# ET3gwTf55ZWUi5o9HAnna6D3sl011piFWmmAIg7MjbB2AE9Tb+AB2A8Gxv6Gx7Ma
# 1SDY6KYoKh3BCnc5KQBuLtGmBOteT+11OdsEx0x9rEu/qhOQbhFOw/tEK7tk0har
# MoAyFnWX6C/Q2lnQMcwytYD5T1Ejngen0V6fRPeLX3lfrN6xR+T98n2qOPUEAWjt
# JmQ6e3cH6wIDAQABo4IDMzCCAy8wHwYDVR0jBBgwFoAUl0gD6xUIa7myWCPMlC7x
# xmXSZI4wHQYDVR0OBBYEFIishvEMffoxHqt0SZTyWs37Ck/3MA4GA1UdDwEB/wQE
# AwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzBpBgNVHR8EYjBgMC6gLKAqhihodHRw
# Oi8vY3JsMy5kaWdpY2VydC5jb20vaGEtY3MtMjAxMWEuY3JsMC6gLKAqhihodHRw
# Oi8vY3JsNC5kaWdpY2VydC5jb20vaGEtY3MtMjAxMWEuY3JsMIIBxAYDVR0gBIIB
# uzCCAbcwggGzBglghkgBhv1sAwEwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3
# LmRpZ2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUH
# AgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQBy
# AHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBj
# AGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAg
# AEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQ
# AGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBt
# AGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBj
# AG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBl
# AHIAZQBuAGMAZQAuMIGGBggrBgEFBQcBAQR6MHgwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBQBggrBgEFBQcwAoZEaHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0SGlnaEFzc3VyYW5jZUNvZGVTaWduaW5nQ0Et
# MS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQUFAAOCAQEArHBrvyCp8Sxm
# oEuhnD4ll2OZK/Ne6HnZeP5Dt7r10/TlUCDWV6L9q9rPSdn5/R8+lvmY2pDV37vX
# k6587Yv7tCsH/6hJYtkMs72aG7ti+yHmGpzYv1syialVgXcY8m/b599k7t710zwv
# hK7bRoT92Esi5xWtks+lkbA5K4WMwu152kXZ4sClolzPcEEUPxf7qk88+mUODDSg
# LbYNdZIL78sWbQEPpQt0RQIzcR28MNd0qD+CyTFhQAKp2S8/Acrwz3WZQqhse+HA
# zg7N1Vi6NHMjgXURzTPO3m2fHb6FIf0uYKlQx3bIhB2RbgtYabs7Ge80eM1YZ5aE
# IWsDUQXZgTCCBr8wggWnoAMCAQICEAgcV+5dcOuboLFSDHKcGwkwDQYJKoZIhvcN
# AQEFBQAwbDELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNlcnQgSGlnaCBB
# c3N1cmFuY2UgRVYgUm9vdCBDQTAeFw0xMTAyMTAxMjAwMDBaFw0yNjAyMTAxMjAw
# MDBaMHMxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNV
# BAsTEHd3dy5kaWdpY2VydC5jb20xMjAwBgNVBAMTKURpZ2lDZXJ0IEhpZ2ggQXNz
# dXJhbmNlIENvZGUgU2lnbmluZyBDQS0xMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAxfkj5pQnxIAUpIAyX0CjjW9wwOU2cXE6daSqGpKUiV6sI3HLTmd9
# QT+q40u3e76dwag4j2kvOiTpd1kSx2YEQ8INJoKJQBnyLOrnTOd8BRq4/4gJTyY3
# 7zqk+iJsiMlKG2HyrhBeb7zReZtZGGDl7im1AyqkzvGDGU9pBXMoCfsiEJMioJAZ
# Gkwx8tMr2IRDrzxj/5jbINIJK1TB6v1qg+cQoxJx9dbX4RJ61eBWWs7qAVtoZVvB
# P1hSM6k1YU4iy4HKNqMSywbWzxtNGH65krkSz0Am2Jo2hbMVqkeThGsHu7zVs94l
# ABGJAGjBKTzqPi3uUKvXHDAGeDylECNnkQIDAQABo4IDVDCCA1AwDgYDVR0PAQH/
# BAQDAgEGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMIIBwwYDVR0gBIIBujCCAbYwggGy
# BghghkgBhv1sAzCCAaQwOgYIKwYBBQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQu
# Y29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFS
# AEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBj
# AGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBu
# AGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAARQBWACAAQwBQ
# AFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAg
# AEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABp
# AGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwBy
# AGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBl
# AC4wDwYDVR0TAQH/BAUwAwEB/zB/BggrBgEFBQcBAQRzMHEwJAYIKwYBBQUHMAGG
# GGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBJBggrBgEFBQcwAoY9aHR0cDovL2Nh
# Y2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0SGlnaEFzc3VyYW5jZUVWUm9vdENB
# LmNydDCBjwYDVR0fBIGHMIGEMECgPqA8hjpodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRIaWdoQXNzdXJhbmNlRVZSb290Q0EuY3JsMECgPqA8hjpodHRw
# Oi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRIaWdoQXNzdXJhbmNlRVZSb290
# Q0EuY3JsMB0GA1UdDgQWBBSXSAPrFQhrubJYI8yULvHGZdJkjjAfBgNVHSMEGDAW
# gBSxPsNpA/i/RwHUmCYaCALvY2QrwzANBgkqhkiG9w0BAQUFAAOCAQEAggXpha+n
# TL+vzj2y6mCxaN5nwtLLJuDDL5u1aw5TkIX2m+A1Av/6aYOqtHQyFDwuEEwomwqt
# CAn584QRk4/LYEBW6XcvabKDmVWrRySWy39LsBC0l7/EpZkG/o7sFFAeXleXy0e5
# NNn8OqL/UCnCCmIE7t6WOm+gwoUPb/wI5DJ704SuaWAJRiac6PD//4bZyAk6ZsOn
# No8YT+ixlpIuTr4LpzOQrrxuT/F+jbRGDmT5WQYiIWQAS+J6CAPnvImQnkJPAcC2
# Fn916kaypVQvjJPNETY0aihXzJQ/6XzIGAMDBH5D2vmXoVlH2hKq4G04AF01K8Ui
# hssGyrx6TT0mRjCCBs0wggW1oAMCAQICEAb9+QOWA63qAArrPye7uhswDQYJKoZI
# hvcNAQEFBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZ
# MBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNz
# dXJlZCBJRCBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTIxMTExMDAwMDAwMFow
# YjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBD
# QS0xMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6IItmfnKwkKVpYBz
# QHDSnlZUXKnE0kEGj8kz/E1FkVyBn+0snPgWWd+etSQVwpi5tHdJ3InECtqvy15r
# 7a2wcTHrzzpADEZNk+yLejYIA6sMNP4YSYL+x8cxSIB8HqIPkg5QycaH6zY/2DDD
# /6b3+6LNb3Mj/qxWBZDwMiEWicZwiPkFl32jx0PdAug7Pe2xQaPtP77blUjE7h6z
# 8rwMK5nQxl0SQoHhg26Ccz8mSxSQrllmCsSNvtLOBq6thG9IhJtPQLnxTPKvmPv2
# zkBdXPao8S+v7Iki8msYZbHBc63X8djPHgp0XEK4aH631XcKJ1Z8D2KkPzIUYJX9
# BwSiCQIDAQABo4IDejCCA3YwDgYDVR0PAQH/BAQDAgGGMDsGA1UdJQQ0MDIGCCsG
# AQUFBwMBBggrBgEFBQcDAgYIKwYBBQUHAwMGCCsGAQUFBwMEBggrBgEFBQcDCDCC
# AdIGA1UdIASCAckwggHFMIIBtAYKYIZIAYb9bAABBDCCAaQwOgYIKwYBBQUHAgEW
# Lmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0w
# ggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgA
# aQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQA
# ZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcA
# aQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwA
# eQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkA
# YwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEA
# cgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIA
# eQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wCwYJYIZIAYb9bAMVMBIGA1UdEwEB/wQI
# MAYBAf8CAQAweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgw
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwHQYDVR0OBBYEFBUAEisTmLKZB+0e36K+
# Vw0rZwLNMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3
# DQEBBQUAA4IBAQBGUD7Jtygkpzgdtlspr1LPUukxR6tWXHvVDQtBs+/sdR90OPKy
# XGGinJXDUOSCuSPRujqGcq04eKx1XRcXNHJHhZRW0eu7NoR3zCSl8wQZVann4+er
# Ys37iy2QwsDStZS9Xk+xBdIOPRqpFFumhjFiqKgz5Js5p8T1zh14dpQlc+Qqq8+c
# dkvtX8JLFuRLcEwAiR78xXm8TBJX/l/hHrwCXaj++wc4Tw3GXZG5D2dFzdaD7eeS
# DY2xaYxP+1ngIw/Sqq4AfO6cQg7PkdcntxbuD8O9fAqg7iwIVYUiuOsYGk38KiGt
# STGDR5V3cdyxG0tLHBCcdxTBnU8vWpUIKRAmMYIEPDCCBDgCAQEwgYcwczELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEyMDAGA1UEAxMpRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2UgQ29k
# ZSBTaWduaW5nIENBLTECEAi8iRJ7eZMavRDMJtoY/+kwCQYFKw4DAhoFAKB4MBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYE
# FMbqJmtFnnZB2PoOXZkf3M3qjGomMA0GCSqGSIb3DQEBAQUABIIBAF9ziFL78vHk
# 85H10PiuQ5XwMnfuzzK4rQ6s7XjzBjHlRmlJwZNJhh6nGbJoGeKtVm5SM2ZeMvAF
# xBeY1W0ZqLVoaB+b6QTrmxY7ggZaMNeRyM0l5MX4Kw6ZrQdRSiwGrxHS+yQImdxb
# afiGSuBFLXCc4Kyd3ijv3lJ1QdKXOhe+mjvm4cNERg3pQOFJMw82mSaeK1yNMmpL
# +FDv7BNEgwvXBIDzDru8qbgAiE/WyxUEg/6ESL61SZ9zZImRKt242rycNRzs9NvM
# hOO/mUOMm5uzFM2cphVGviCwYMJvuGbqzzFXlfkZrCGD54CuO66Ho1nbNZvQTY6G
# XglCpiknTsahggIPMIICCwYJKoZIhvcNAQkGMYIB/DCCAfgCAQEwdjBiMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTECEAOL
# lvBw2eIeVaVCZ5LhyDowCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG
# 9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTEzMDMxNTIxMzU0MVowIwYJKoZIhvcNAQkE
# MRYEFKxkm8oCW6n0kttvDwaGmsrZfe0IMA0GCSqGSIb3DQEBAQUABIIBAJrw872t
# DgvDLC6J0hN2RPBgL2itMtPwxPKOzxSC2iYTsJv8JMrqJBwY1o8P/KipPDZm7tlv
# 7zUO2krH+WdOgYvIZRTYDsDntWog++/6rVf/2yO4/ysNn5gD5ptaNuKpy84/lMzw
# qEc0kDssWBkM9lBzWmqiiXKAGbnhvZvz93SfGZfCBhTJutipNCnJKVoXWbspxEYn
# de7D9ZlOATJ94f8R1W/Kr7oxE377MlRLDofXA7DJscS4mYOXH/o43PlEHRAFiNlO
# KYV3O90ygD2A1Dv4Hni1Agpz0y2xxYIJzd13R1sCEQS64wlApw6d2ucb9TWdEFnk
# vNOfNx11O3z0cR8=
# SIG # End signature block