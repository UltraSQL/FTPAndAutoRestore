Function Set-FTPConnection
{
    <#
	.SYNOPSIS
	    Set config to ftp Connection.

	.DESCRIPTION
	    The Set-FTPConnection cmdlet creates a Windows PowerShell configuration to ftp server. When you create a ftp connection, you may run multiple commands that use this config.
		
	.PARAMETER Credential
	    Specifies a user account that has permission to access to ftp location.
			
	.PARAMETER Server
	    Specifies the ftp server you want to connect. 
			
	.PARAMETER EnableSsl
	    Specifies that an SSL connection should be used. 
			
	.PARAMETER ignoreCert
	    If you use SSL connection you may ignore certificate error. 
			
	.PARAMETER KeepAlive
	    Specifies whether the control connection to the ftp server is closed after the request completes.  
			
	.PARAMETER UseBinary
	    Specifies the data type for file transfers.  
			
	.PARAMETER UsePassive
	    Behavior of a client application's data transfer process. 

	.PARAMETER Session
	    Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'.
	
	.EXAMPLE

		Set-FTPConnection -Credentials userName -Server myftpserver.com
		
	.EXAMPLE

		$Credentials = Get-Credential
		Set-FTPConnection -Credentials $Credentials -Server ftp://myftpserver.com -EnableSsl -ignoreCert -UsePassive

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
        Get-FTPChildItem
	#>    

	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="Low"
    )]
    Param(
		[parameter(Mandatory=$true)]
		[Alias("Credential")]
		$Credentials, 
		[parameter(Mandatory=$true)]
		[String]$Server,
		[Switch]$EnableSsl = $False,
		[Switch]$ignoreCert = $False,
		[Switch]$KeepAlive = $False,
		[Switch]$UseBinary = $False,
		[Switch]$UsePassive = $False,
		[String]$Session = "DefaultFTPSession"
	)
	
	Begin
	{
		if($Credentials -isnot [System.Management.Automation.PSCredential])
		{
			$Credentials = Get-Credential $Credentials
		}
	}
	
	Process
	{
        if ($pscmdlet.ShouldProcess($Server,"Connect to FTP Server")) 
		{	
			if(!($Server -match "ftp://"))
			{
				$Server = "ftp://"+$Server	
				Write-Debug "Add ftp:// at start: $Server"				
			}
			
			Write-Verbose "Create FtpWebRequest object."
			[System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($Server)
			$Request.Credentials = $Credentials
			$Request.EnableSsl = $EnableSsl
			$Request.KeepAlive = $KeepAlive
			$Request.UseBinary = $UseBinary
			$Request.UsePassive = $UsePassive
			$Request | Add-Member -MemberType NoteProperty -Name ignoreCert -Value $ignoreCert
			$Request | Add-Member -MemberType NoteProperty -Name Session -Value $Session

			$Request.Method = [System.Net.WebRequestMethods+FTP]::ListDirectoryDetails
			Try
			{
				[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$ignoreCert}
				$Response = $Request.GetResponse()
				$Response.Close()
				
				if((Get-Variable -Scope Global -Name $Session -ErrorAction SilentlyContinue) -eq $null)
				{
					Write-Verbose "Create global variable: $Session"
					New-Variable -Scope Global -Name $Session -Value $Request
				}
				else
				{
					Write-Verbose "Set global variable: $Session"
					Set-Variable -Scope Global -Name $Session -Value $Request
				}
				
				Return $Response
			}
			Catch
			{
				Write-Error $_.Exception.Message -ErrorAction Stop 
			}
		}
	}
	
	End{}				
}

Function Get-FTPConnection
{
    <#
	.SYNOPSIS
	    Get config to ftp Connection.

	.DESCRIPTION
	    The Get-FTPConnection cmdlet create a list of registered PSFTP sessions.
		
	.PARAMETER Session
	    Specifies a friendly name for the ftp session.
	
	.EXAMPLE

		Get-FTPConnection
		
	.EXAMPLE

		Get-FTPConnection -Session DefaultFTPS*

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
        Set-FTPConnection
	#>    

	[OutputType('PSFTP.Session')]
	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="Low"
    )]
    Param(
		[String]$Session
	)
	
	Begin{}
	
	Process
	{
		if($Session)
		{
			$Variables = Get-Variable -Scope Global | 
			Where-Object {$_.value -is [System.Net.FtpWebRequest] -and $_.Name -like $Session}
		}
		else
		{
			$Variables = Get-Variable -Scope Global | Where-Object {$_.value -is [System.Net.FtpWebRequest]}
		}
		
		$Sessions = @()
		$Variables | ForEach{
			$CurrentSession = Get-Variable -Scope Global -Name $_.Name -ErrorAction SilentlyContinue -ValueOnly
		
			if($Sessions -notcontains $CurrentSession)
			{
				$Sessions += $_.Value
			}
		}

		$Sessions.PSTypeNames.Clear()
		$Sessions.PSTypeNames.Add('PSFTP.Session')
		
		Return $Sessions
	}
	
	End{}				
}

Function Get-FTPChildItem
{
	<#
	.SYNOPSIS
		Gets the item and child items from ftp location.

	.DESCRIPTION
		The Get-FTPChildItem cmdlet gets the items from ftp locations. If the item is a container, it gets the items inside the container, known as child items. 
		
	.PARAMETER Path
		Specifies a path to ftp location or file. 
			
	.PARAMETER Session
		Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'.
		
	.PARAMETER Recurse
		Get recurse child items.

	.PARAMETER Depth
		Define depth of  folder in recurse mode. Autoenable recurse mode.

	.PARAMETER Filter
		Specifies a filter parameter to return only this objects that have proper name. This parameter allow to use of wildcards. Defalut value is *.	
		
	.EXAMPLE
		PS P:\> Get-FTPChildItem -path ftp://ftp.contoso.com/folder


		   Parent: ftp://ftp.contoso.com/folder

		Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		--- -----     --  ----   -----  ----   ------------        ----
		d   rwxr-xr-x 3   ftp    ftp           2012-06-19 12:58:00 subfolder1
		d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder2
		-   rw-r--r-- 1   ftp    ftp    1KB    2012-06-15 12:49:00 textitem.txt

	.EXAMPLE
		PS P:\> Get-FTPChildItem -path ftp://ftp.contoso.com/folder -Filter "subfolder*"


		   Parent: ftp://ftp.contoso.com/folder

		Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		--- -----     --  ----   -----  ----   ------------        ----
		d   rwxr-xr-x 3   ftp    ftp           2012-06-19 12:58:00 subfolder1
		d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder2	

	.EXAMPLE
		PS P:\> Get-FTPChildItem -path folder -Recurse


		   Parent: ftp://ftp.contoso.com/folder

		Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		--- -----     --  ----   -----  ----   ------------        ----
		d   rwxr-xr-x 3   ftp    ftp           2012-06-19 12:58:00 subfolder1
		d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder2
		-   rw-r--r-- 1   ftp    ftp    1KB    2012-06-15 12:49:00 textitem.txt


		   Parent: ftp://ftp.contoso.com/folder/subfolder1

		Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		--- -----     --  ----   -----  ----   ------------        ----
		d   rwxr-xr-x 2   ftp    ftp           2012-06-19 12:58:00 subfolder11
		-   rw-r--r-- 1   ftp    ftp    21KB   2012-06-19 09:20:00 test.xlsx
		-   rw-r--r-- 1   ftp    ftp    14KB   2012-06-19 11:27:00 ziped.zip


		   Parent: ftp://ftp.contoso.com/folder/subfolder1/subfolder11

		Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		--- -----     --  ----   -----  ----   ------------        ----
		-   rw-r--r-- 1   ftp    ftp    14KB   2012-06-19 11:27:00 ziped.zip


		   Parent: ftp://ftp.contoso.com/folder/subfolder2

		Dir Right     Ln  User   Group  Size   ModifiedDate        Name
		--- -----     --  ----   -----  ----   ------------        ----
		-   rw-r--r-- 1   ftp    ftp    1KB    2012-06-15 12:49:00 textitem.txt
		-   rw-r--r-- 1   ftp    ftp    14KB   2012-06-19 11:27:00 ziped.zip

	.EXAMPLE
		PS P:\> $ftpFile = Get-FTPChildItem -path /folder/subfolder1/test.xlsx
		PS P:\> $ftpFile | Select-Object Parent, Name, ModifiedDate

		Parent                                  Name                                    ModifiedDate
		------                                  ----                                    ------------
		ftp://ftp.contoso.com/folder/subfolder1 test.xlsx                               2012-06-19 09:20:00
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
		Set-FTPConnection
	#>	 

	[OutputType('PSFTP.Item')]
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="Low"
	)]
	Param(
		[parameter(ValueFromPipelineByPropertyName=$true,
			ValueFromPipeline=$true)]
		[String]$Path = "",
		$Session = "DefaultFTPSession",
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[Switch]$Recurse,	
		[Int]$Depth = 0,		
		[String]$Filter = "*"
	)
	
	Begin
	{
		if($Session -isnot [String])
		{
			$CurrentSession = $Session
		}
		else
		{
			$CurrentSession = Get-Variable -Scope Global -Name $Session -ErrorAction SilentlyContinue -ValueOnly
		}
		
		if($CurrentSession -eq $null)
		{
			Write-Warning "Add-FTPItem: Cannot find session $Session. First use Set-FTPConnection to config FTP connection."
			Break
			Return
		}	
	}
	
	Process
	{
		Write-Debug "Native path: $Path"
		
		if($Path -match "ftp://")
		{
			$RequestUri = $Path
			Write-Verbose "Use original path: $RequestUri"
			
		}
		else
		{
			$RequestUri = $CurrentSession.RequestUri.OriginalString+"/"+$Path
			Write-Verbose "Add ftp:// at start: $RequestUri"
		}
		$RequestUri = [regex]::Replace($RequestUri, '/$', '')
		$RequestUri = [regex]::Replace($RequestUri, '/+', '/')
		$RequestUri = [regex]::Replace($RequestUri, '^ftp:/', 'ftp://')
		Write-Verbose "Remove additonal slash: $RequestUri"

		if($Depth -gt 0)
		{
			$CurrentDepth = [regex]::matches($RequestUri,"/").count
			if((Get-Variable -Scope Script -Name MaxDepth -ErrorAction SilentlyContinue) -eq $null)
			{
				New-Variable -Scope Script -Name MaxDepth -Value ([Int]$CurrentDepth +$Depth)
			}
		
			Write-Verbose "Auto enable recurse mode. Current depth / Max Depth: $CurrentDepth / $($Script:MaxDepth)"
			$Recurse = $true
		}

		
		if ($pscmdlet.ShouldProcess($RequestUri,"Get child items from ftp location")) 
		{	
			if((Get-FTPItemSize $RequestUri -Session $Session -Silent) -eq -1)
			{
				Write-Verbose "Path is directory"
				$ParentPath = $RequestUri
			}
			else
			{
				Write-Verbose "Path is file. Delete last file name to get parent path."
				$LastIndex = $RequestUri.LastIndexOf("/")
				$ParentPath = $RequestUri.SubString(0,$LastIndex)
			}
						
			[System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($RequestUri)
			$Request.Credentials = $CurrentSession.Credentials
			$Request.EnableSsl = $CurrentSession.EnableSsl
			$Request.KeepAlive = $CurrentSession.KeepAlive
			$Request.UseBinary = $CurrentSession.UseBinary
			$Request.UsePassive = $CurrentSession.UsePassive
			
			$Request.Method = [System.Net.WebRequestMethods+FTP]::ListDirectoryDetails
			Write-Verbose "Use WebRequestMethods: $($Request.Method)"
			Try
			{
				$mode = "Unknown"
				[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$CurrentSession.ignoreCert}
				$Response = $Request.GetResponse()
				
				[System.IO.StreamReader]$Stream = New-Object System.IO.StreamReader($Response.GetResponseStream(),[System.Text.Encoding]::Default)

				$DirList = @()
				$ItemsCollection = @()
				Try
				{
					[string]$Line = $Stream.ReadLine()
					Write-Debug "Read Line: $Line"
				}
				Catch
				{
					$Line = $null
					Write-Debug "Line is null"
				}
				
				While ($Line)
				{
					if($mode -eq "Compatible" -or $mode -eq "Unknown")
					{
						$null, [string]$IsDirectory, [string]$Flag, [string]$Link, [string]$UserName, [string]$GroupName, [string]$Size, [string]$Date, [string]$Name = `
						[regex]::split($Line,'^([d-])([rwxt-]{9})\s+(\d{1,})\s+([.@A-Za-z0-9-]+)\s+([A-Za-z0-9-]+)\s+(\d{1,})\s+(\w+\s+\d{1,2}\s+\d{1,2}:?\d{2})\s+(.+?)\s?$',"SingleLine,IgnoreCase,IgnorePatternWhitespace")

						if($IsDirectory -eq "" -and $mode -eq "Unknown")
						{
							$mode = "IIS6"
						}
						elseif($mode -ne "Compatible")
						{
							$mode = "Compatible" #IIS7/Linux
						}
						
						if($mode -eq "Compatible")
						{
							$DatePart = $Date -split "\s+"
							$NewDateString = "$($DatePart[0]) $('{0:D2}' -f [int]$DatePart[1]) $($DatePart[2])"
							
							Try
							{
								if($DatePart[2] -match ":")
								{
									$Month = ([DateTime]::ParseExact($DatePart[0],"MMM",[System.Globalization.CultureInfo]::InvariantCulture)).Month
									if((Get-Date).Month -ge $Month)
									{
										$NewDate = [DateTime]::ParseExact($NewDateString,"MMM dd HH:mm",[System.Globalization.CultureInfo]::InvariantCulture)
									}
									else
									{
										$NewDate = ([DateTime]::ParseExact($NewDateString,"MMM dd HH:mm",[System.Globalization.CultureInfo]::InvariantCulture)).AddYears(-1)
									}
								}
								else
								{
									$NewDate = [DateTime]::ParseExact($NewDateString,"MMM dd yyyy",[System.Globalization.CultureInfo]::InvariantCulture)
								}
							}
							Catch
							{
								Write-Verbose "Can't parse date: $Date"
							}							
						}
					}
					
					if($mode -eq "IIS6")
					{
						$null, [string]$NewDate, [string]$IsDirectory, [string]$Size, [string]$Name = `
						[regex]::split($Line,'^(\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}[AP]M)\s+<*([DIR]*)>*\s+(\d*)\s+(.+).*$',"SingleLine,IgnoreCase")
						
						if($IsDirectory -eq "")
						{
							$IsDirectory = "-"
						}
					}
					
					Switch($Size)
					{
						{[int64]$_ -lt 1024} { $HFSize = $_+"B"; break }
						{[System.Math]::Round([int64]$_/1KB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1KB,0))+"KB"; break }
						{[System.Math]::Round([int64]$_/1MB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1MB,0))+"MB"; break }
						{[System.Math]::Round([int64]$_/1GB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1GB,0))+"GB"; break }
						{[System.Math]::Round([int64]$_/1TB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1TB,0))+"TB"; break }
						{[System.Math]::Round([int64]$_/1PB,0) -lt 1024} { $HFSize = [String]([System.Math]::Round($_/1PB,0))+"PB"; break }
					} 
					
					if($IsDirectory -eq "d" -or $IsDirectory -eq "DIR")
					{
						$HFSize = ""
					}
					
					if($ParentPath -match "\*|\?")
					{
						$LastIndex = $ParentPath.LastIndexOf("/")
						$ParentPath = $ParentPath.SubString(0,$LastIndex)
						$ParentPath.Trim() + "/" + $Name.Trim()
					}
					
					$LineObj = New-Object PSObject -Property @{
						Dir = $IsDirectory
						Right = $Flag
						Ln = $Link
						User = $UserName
						Group = $GroupName
						Size = $HFSize
						SizeInByte = $Size
						OrgModifiedDate = $Date
						ModifiedDate = $NewDate
						Name = $Name.Trim()
						FullName = $ParentPath.Trim() + "/" + $Name.Trim()
						Parent = $ParentPath.Trim()
					}
					
					$LineObj.PSTypeNames.Clear()
					$LineObj.PSTypeNames.Add('PSFTP.Item')
			
					if($Recurse -and ($LineObj.Dir -eq "d" -or $LineObj.Dir -eq "DIR"))
					{
						$DirList += $LineObj
					}
					
					
					if($LineObj.Dir)
					{
						if($LineObj.Name -like $Filter)
						{
							Write-Debug "Filter accepted: $Filter"
							$ItemsCollection += $LineObj
						}
					}
					$Line = $Stream.ReadLine()
					Write-Debug "Read Line: $Line"
				}
				
				$Response.Close()
				
				if($Recurse -and ($CurrentDepth -lt $Script:MaxDepth -or $Depth -eq 0))
				{
					$RecurseResult = @()
					$DirList | ForEach-Object {
						Write-Debug "Recurse is active and go to: $($_.FullName)"
						$RecurseResult += Get-FTPChildItem -Path ($_.FullName) -Session $Session -Recurse -Filter $Filter -Depth $Depth
						
					}	

					$ItemsCollection += $RecurseResult
				}	
				
				if($ItemsCollection.count -eq 0)
				{
					Return 
				}
				else
				{
					Return $ItemsCollection | Sort-Object -Property @{Expression="Parent";Descending=$false}, @{Expression="Dir";Descending=$true}, @{Expression="Name";Descending=$false} 
				}
			}
			Catch
			{
				Write-Error $_.Exception.Message -ErrorAction Stop 
			}
		}
		
		if($CurrentDepth -ge $Script:MaxDepth)
		{
			Remove-Variable -Scope Script -Name CurrentDepth 
		}		
	}
	
	End{}
}

Function Get-FTPItem
{
    <#
	.SYNOPSIS
	    Send specific file from ftop server to location disk.

	.DESCRIPTION
	    The Get-FTPItem cmdlet download file to specific location on local machine.
		
	.PARAMETER Path
	    Specifies a path to ftp location. 

	.PARAMETER LocalPath
	    Specifies a local path. 
		
	.PARAMETER RecreateFolders
		Recreate locally folders structure from ftp server.

	.PARAMETER BufferSize
	    Specifies size of buffer. Default is 20KB. 
		
	.PARAMETER Session
	    Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'.
		
	.PARAMETER Overwrite
	    Overwrite item in local path. 
		
	.EXAMPLE
		PS P:\> Get-FTPItem -Path ftp://ftp.contoso.com/folder/subfolder1/test.xlsx -LocalPath P:\test
		226 File send OK.

		PS P:\> Get-FTPItem -Path ftp://ftp.contoso.com/folder/subfolder1/test.xlsx -LocalPath P:\test

		A File name already exists in location: P:\test
		What do you want to do?
		[C] Cancel  [O] Overwrite  [?] Help (default is "O"): O
		226 File send OK.

	.EXAMPLE	
		PS P:\> Get-FTPChildItem -path folder/subfolder1 -Recurse | Get-FTPItem -localpath p:\test -RecreateFolders -Verbose
		VERBOSE: Performing operation "Download item: 'ftp://ftp.contoso.com/folder/subfolder1/test.xlsx'" on Target "p:\test\folder\subfolder1".
		VERBOSE: Creating folder: folder\subfolder1
		226 File send OK.

		VERBOSE: Performing operation "Download item: 'ftp://ftp.contoso.com/folder/subfolder1/ziped.zip'" on Target "p:\test\folder\subfolder1".
		226 File send OK.

		VERBOSE: Performing operation "Download item: 'ftp://ftp.contoso.com/folder/subfolder1/subfolder11/ziped.zip'" on Target "p:\test\folder\subfolder1\subfolder11".
		VERBOSE: Creating folder: folder\subfolder1\subfolder11
		226 File send OK.

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
        Get-FTPChildItem
	#>    

	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="Low"
    )]
    Param(
		[parameter(Mandatory=$true,
			ValueFromPipelineByPropertyName=$true,
			ValueFromPipeline=$true)]
		[Alias("FullName")]
		[String]$Path = "",
		[String]$LocalPath = (Get-Location).Path,
		[Switch]$RecreateFolders,
		[Int]$BufferSize = 20KB,
		$Session = "DefaultFTPSession",
		[Switch]$Overwrite = $false
	)
	
	Begin
	{
		if($Session -isnot [String])
		{
			$CurrentSession = $Session
		}
		else
		{
			$CurrentSession = Get-Variable -Scope Global -Name $Session -ErrorAction SilentlyContinue -ValueOnly
		}
		
		if($CurrentSession -eq $null)
		{
			Write-Warning "Add-FTPItem: Cannot find session $Session. First use Set-FTPConnection to config FTP connection."
			Break
			Return
		}	
	}
	
	Process
	{
		Write-Debug "Native path: $Path"
		
		if($Path -match "ftp://")
		{
			$RequestUri = $Path
			Write-Debug "Use original path: $RequestUri"
			
		}
		else
		{
			$RequestUri = $CurrentSession.RequestUri.OriginalString+"/"+$Path
			Write-Debug "Add ftp:// at start: $RequestUri"
		}
		$RequestUri = [regex]::Replace($RequestUri, '/$', '')
		$RequestUri = [regex]::Replace($RequestUri, '/+', '/')
		$RequestUri = [regex]::Replace($RequestUri, '^ftp:/', 'ftp://')
		Write-Debug "Remove additonal slash: $RequestUri"
			
		if ($pscmdlet.ShouldProcess($LocalDir,"Download item: '$RequestUri'")) 
		{	
			$TotalData = Get-FTPItemSize $RequestUri -Session $Session -Silent
			if($TotalData -eq -1) { Return }
			if($TotalData -eq 0) { $TotalData = 1 }

			$AbsolutePath = ($RequestUri -split $CurrentSession.ServicePoint.Address.AbsoluteUri)[1]
			$LastIndex = $AbsolutePath.LastIndexOf("/")
			$ServerPath = $CurrentSession.ServicePoint.Address.AbsoluteUri
			if($LastIndex -eq -1)
			{
				$FolderPath = "\"
			}
			else
			{
				$FolderPath = $AbsolutePath.SubString(0,$LastIndex) -replace "/","\"
			}	
			$FileName = $AbsolutePath.SubString($LastIndex+1)
		
			if($RecreateFolders)
			{
				if(!(Test-Path (Join-Path -Path $LocalPath -ChildPath $FolderPath)))
				{
					Write-Verbose "Creating folder: $FolderPath"
					New-Item -Type Directory -Path $LocalPath -Name $FolderPath | Out-Null
				}
				$LocalDir = Join-Path -Path $LocalPath -ChildPath $FolderPath
			}
			else
			{
				$LocalDir = $LocalPath
			}			
			
			[System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($RequestUri)
			$Request.Credentials = $CurrentSession.Credentials
			$Request.EnableSsl = $CurrentSession.EnableSsl
			$Request.KeepAlive = $CurrentSession.KeepAlive
			$Request.UseBinary = $CurrentSession.UseBinary
			$Request.UsePassive = $CurrentSession.UsePassive

			$Request.Method = [System.Net.WebRequestMethods+FTP]::DownloadFile  
			Write-Debug "Use WebRequestMethods: $($Request.Method)"
			Try
			{
				[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$CurrentSession.ignoreCert}
				$SendFlag = 1
				
				if((Get-ItemProperty $LocalDir -ErrorAction SilentlyContinue).Attributes -match "Directory")
				{
					$LocalDir = Join-Path -Path $LocalDir -ChildPath $FileName
				}
				
				if(Test-Path ($LocalDir))
				{
					$FileSize = (Get-Item $LocalDir).Length
					
					if($Overwrite -eq $false)
					{
						$Title = "A file ($RequestUri) already exists in location: $LocalDir"
						$Message = "What do you want to do?"

						$CDOverwrite = New-Object System.Management.Automation.Host.ChoiceDescription "&Overwrite"
						$CDCancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel"
						if($FileSize -lt $TotalData)
						{
							$CDResume = New-Object System.Management.Automation.Host.ChoiceDescription "&Resume"
							$Options = [System.Management.Automation.Host.ChoiceDescription[]]($CDCancel, $CDOverwrite, $CDResume)
							$SendFlag = $host.ui.PromptForChoice($Title, $Message, $Options, 2) 
						}
						else
						{
							$Options = [System.Management.Automation.Host.ChoiceDescription[]]($CDCancel, $CDOverwrite)
							$SendFlag = $host.ui.PromptForChoice($Title, $Message, $Options, 1)
						}
					}
					else
					{
						$SendFlag = 1
					}
				}

				if($SendFlag)
				{
					[Byte[]]$Buffer = New-Object Byte[] $BufferSize

					$ReadedData = 0
					$AllReadedData = 0
					
					if($SendFlag -eq 2)
					{      
						$File = New-Object IO.FileStream ($LocalDir,[IO.FileMode]::Append)
						$Request.UseBinary = $True
						$Request.ContentOffset  = $FileSize 
						$AllReadedData = $FileSize
						Write-Debug "Open File to append: $LocalDir"
					}
					else
					{
						$File = New-Object IO.FileStream ($LocalDir,[IO.FileMode]::Create)
						Write-Debug "Create File: $LocalDir"
					}
					
					$Response = $Request.GetResponse()
					$Stream  = $Response.GetResponseStream()
					
					Do{
						$ReadedData=$Stream.Read($Buffer,0,$Buffer.Length)
						$AllReadedData +=$ReadedData
						$File.Write($Buffer,0,$ReadedData)
						if($TotalData)
						{
							Write-Progress -Activity "Download File: $Path" -Status "Downloading:" -Percentcomplete ([int]($AllReadedData/$TotalData * 100))
						}
					}
					While ($ReadedData -ne 0)
					$File.Close()
					Write-Debug "Close File: $LocalDir"
					
					$Status = $Response.StatusDescription
					$Response.Close()
					Return $Status
				}
			}
			Catch
			{
				Write-Error $_.Exception.Message -ErrorAction Stop 
			}
		}
	}
	
	End{}
}

<#
====================================================================================
  File:     RestoreBackup.ps1
  Author:   Changyong Xu
  Version:  SQL Server 2014, PowerShell V4
  Comment:  Get full backup Files from FTP Server,and then restore them automately.
            Run Powershell as Administor,And execute like this:
            .\ResotreBackup.ps1 "ALWAYSON3\TESTSTANDBY"
====================================================================================
#>

Function RestoreBackup
{
    Param(
        [String]$Instance = ".",
        [String]$Service = "TEMP"
    )

    Begin
    {
        $Log = Join-Path $Home "Documents/FTP.log"
        Write-Debug $Log
            
        Switch($Service)
        {
            "JZJY" { $FTPPath = "/BackupForTest/XXXX/" }
            "JZJYHIS" { $FTPPath = "/BackupForTest/XXXXHIS/" }
            "RZRQ" { $FTPPath = "/BackupForTest/YYYY/" }
            "RZRQHIS" { $FTPPath = "/BackupForTest/YYYYHIS/" }
            "ZHXT" { $FTPPath = "/BackupForTest/ZZZZ/" }
            "ZSSDB" { $FTPPath = "/BackupForTest/MMMM/" }
            Default { $FTPPath = "/BackupForTest/TEMP/" }
        }
        Write-Debug $FTPPath
    }

    Process
    {
        Try
        {
            #import SQL Server module
            Import-Module SQLPS -DisableNameChecking -Force

            #get default data file directory and backup directory
            $DBServer = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $Instance
            Write-Debug (Get-Location).Path
            Write-Debug $DBServer
            $RelocatePath = $DBServer.Settings.DefaultFile
            Write-Debug $RelocatePath
            $LocalBackupFolder = $DBServer.Settings.BackupDirectory
            Write-Debug $LocalBackupFolder

            #delete local files
            Get-ChildItem -Path $LocalBackupFolder | ForEach-Object {Remove-Item -Path $_.FullName -Force}

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

            #get backup from FTP server
            Get-FTPChildItem -Session $Session -Path $FTPPath | Get-FTPItem -Session $Session -LocalPath $LocalBackupFolder
            Write-Debug $LocalBackupFolder
            $FullBackupFiles = Get-ChildItem $LocalBackupFolder

            #restore database
            foreach ($FullBackupFile in $FullBackupFiles)
            {
                Write-Debug $FullBackupFile.FullName
                $SmoRestore = New-Object Microsoft.SqlServer.Management.Smo.Restore
                $SmoRestore.Devices.AddDevice($FullBackupFile.FullName, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)

                #get the db name from backup File
                $DBRestoreDetails = $SmoRestore.ReadBackupHeader($DBServer)
                $DBName = $DBRestoreDetails.Rows[0].DatabaseName
                Write-Debug $DBName

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
                -ServerInstance $Instance `
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
    }

    End{}
}

#$DebugPreference = "Continue"
#$DebugPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"
RestoreBackup -Instance $args[0] -Service $args[1]
Read-Host -Prompt "Press Enter to continue"