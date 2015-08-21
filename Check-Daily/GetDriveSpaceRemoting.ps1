Function GetDriveSpace-Remoting
{
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Low")]
    param (
    [parameter(Mandatory=$true,HelpMessage="ComputerName(s)",ValueFromPipeline=$true)]
    [Object[]]$Identity
    )
    Process
    {
        Invoke-Command -ComputerName $Identity -ScriptBlock {$drives = Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}
            foreach($drive in $drives)
            {
                $NewObjectProperties = @{
                    DriveLetter=$drive.DeviceID;`
                    Label=($drive.VolumeName);`
                    DriveSizeMB=($drive.Size/1gb).ToString("0.00");`
                    FreeSpaceMB=($drive.freespace/1GB).tostring("0.00");`
                    PercentFree=((($drive.freespace/1GB)/($drive.size/1GB))*100).tostring("0.00")`
                }
                New-Object psobject -Property $NewObjectProperties
            }
        } -SessionOption (New-PSSessionOption -NoMachineProfile) -AsJob
 
    }
    End
    {
        While (Get-Job -State "Running")
        {
            $i = ((Get-Job).Count) - ((Get-Job -State "Running").count)
            $Progress = [int][Math]::Ceiling(($i / ((Get-Job).Count) * 100))
            Write-Progress -Activity "Waiting on $(((Get-Job -State "Running").count)) Jobs to finish" -PercentComplete $progress -Status "$($progress)% Complete" -Id 1;
        }
        $Results = Get-Job | % {Receive-Job $_ }
        $Results
    }
	<# 
    GetDriveSpace-Remoting -Identity SERVER01
 
        Returns Drive Space Info for SERVER01
 
        .EXAMPLE
        PS] C:\>Get-MailboxServer | GetDriveSpace-Remoting | FT
 
        Returns Drive Space Info for Exchange Mailbox Servers
 
        .EXAMPLE
        PS] C:\>GetDriveSpace-Remoting -Identity SERVER01, SERVER02 | FT -AutoSize
 
        Returns Drive Space Info for SERVER01 & SERVER02
 
        .NOTES
        Function Name : GetDriveSpace-Remoting
        Author : Dan Burgess
        Email: nerd@everydaynerd.com
        Script Requires:  Powershell 2.0 or higher and WinRM enabled on remote hosts
    #>
}

GetDriveSpace-Remoting -Identity SCCM1,WIN-VULMGMT1 | FT -AutoSize