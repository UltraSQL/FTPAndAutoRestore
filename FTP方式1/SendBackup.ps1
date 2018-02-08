<#
====================================================================================
  File:     SendBackup.ps1
  Author:   Changyong Xu
  Version:  SQL Server 2014, PowerShell V4
  Comment:  Delete files on FTP Server,and then send full backup files to it.
            You need write backup file name to C:\FileConfig.ini,and modify 1 parameter:
            #FTP folder at FTP server
            $FTPPath = "/BackupForTest/XXXX/"
====================================================================================
#>

#import FTP client module
Import-Module PSFTP -DisableNameChecking

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

    #delete remote backup from FTP servver
    $FTPPath = "/BackupForTest/XXXX/"
    Get-FTPChildItem -Session $Session -Path $FTPPath | Remove-FTPItem -Session $Session

    #send backup to FTP Server
    $ConfigFile = "C:\FileConfig.ini"
    $FileList = Get-Content -Path $ConfigFile
    foreach ($File in $FileList)
    {
        if(!(Test-Path $File))
        {
            Write-Host "########### $File is not exits ##########" -ForegroundColor Red
            break
            Return
        }

        Add-FTPItem -Session $Session -Path $FTPPath -LocalPath $File
        Write-Host "########### $File sended to FTP Server.###########" -ForegroundColor Green
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
    "This script is executed at $Time" | Out-File $Log -Append
}