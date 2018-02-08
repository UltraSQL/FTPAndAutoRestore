<#
====================================================================================
  File:     RestoreBackup.ps1
  Author:   Changyong Xu
  Version:  SQL Server 2014, PowerShell V4
  Comment:  Get full backup Files from FTP Server,and then restore them automately.
            You need to modify 3 parameters:
            #local folder where to put the backup files
            $LocalBackupFolder = "C:\XXXX\"
            #FTP folder at FTP server
            $FTPPath = "/BackupForTest/XXXX/"
            #local SQL Server instance name
            $InstanceName = "ALWAYSON3\TESTSTANDBY"
====================================================================================
#>

#import FTP client module
Import-Module PSFTP -DisableNameChecking
#import SQL Server module
Import-Module SQLPS -DisableNameChecking

$ErrorActionPreference = "Stop"
$Log = "$Home\Documents\FTP.log"

Try
{
    #create FTP connection
    $Server="ftp://10.190.240.220" 
    $User = "Administrator"
    $Key = (2,2,2,2,22,22,222,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,22)
    $Pwd = "76492d1116743f0423413b16050a5345MgB8AEwAQQBQAFgAUgB1AHYAWgBWAG8AdgAvAEwALwB4ADQAVQByAEsANwBWAGcAPQA9AHwAYQA1AGMAYgAwADcANABkADQAMQAxADUAYQA5AGQAYQBiADkAMgBmAGEANQA1AGEAZAA1AGEANABlADEANAA3ADUANQA1AGMANQAxAGYANQBmAGMAYwBjAGEAOQBjAGIAZABkAGIAZgAyADYAMgBjADkAMABiADgAMgBkADgAYwA=
    "
    $SecStr=ConvertTo-SecureString -String $Pwd -Key $Key;
    $Credential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $SecStr
    Set-FTPConnection -Credentials $Credential -Server $Server -Session MyTestSession -UsePassive
    $Session = Get-FTPConnection -Session MyTestSession

    #delete local files
    $LocalBackupFolder = "C:\XXXX\"
    Get-ChildItem -Path $LocalBackupFolder | ForEach-Object {Remove-Item -Path $_.FullName -Force}

    #get backup from FTP server
    $FTPPath = "/BackupForTest/XXXX/"
    Get-FTPChildItem -Session $Session -Path $FTPPath | Get-FTPItem -Session $Session -LocalPath $LocalBackupFolder 

    #restore database
    $InstanceName = "ALWAYSON3\TESTSTANDBY"
    $DBServer = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $InstanceName
    $RelocatePath = $DBServer.Settings.DefaultFile;
    $FullBackupFiles = Get-ChildItem $LocalBackupFolder

    foreach ($FullBackupFile in $FullBackupFiles)
    {
        $SmoRestore = New-Object Microsoft.SqlServer.Management.Smo.Restore
        $SmoRestore.Devices.AddDevice($FullBackupFile.FullName, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)

        #get the db name from backup File
        $DBRestoreDetails = $SmoRestore.ReadBackupHeader($DBServer)
        $DBName = $DBRestoreDetails.Rows[0].DatabaseName

        #get the File list
        $FileList = $SmoRestore.ReadFileList($DBServer)
        $RelocateFileList = @()

        foreach($File in $FileList)
        {
            $RelocateFile = Join-Path $RelocatePath (Split-Path $File.PhysicalName -Leaf)
            $RelocateFileList += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($File.LogicalName, $RelocateFile)
        }

        if($DBServer.Databases.Item($DBName))
        {
            $DBServer.KillAllProcesses($DBName)
            $DBServer.Databases.Item($DBName).Drop()
        }

        Restore-SqlDatabase `
        -ReplaceDatabase `
        -ServerInstance $InstanceName `
        -Database $DBName.ToString() `
        -BackupFile $FullBackupFile.FullName `
        -RelocateFile $RelocateFileList

        Write-Host "########### $DBName is restored successfully.###########" -ForegroundColor Green
    }
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    "The error message was $ErrorMessage" | Out-File $Log -Append
    Break
}
Finally
{
    $Time=Get-Date
    "$Time : This script is executed." | Out-File $Log -Append
}