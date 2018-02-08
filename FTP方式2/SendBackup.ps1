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

Function Remove-FTPItem
{
    <#
	.SYNOPSIS
	    Remove specific item from ftp server.

	.DESCRIPTION
	    The Remove-FTPItem cmdlet remove item from specific location on ftp server.
		
	.PARAMETER Path
	    Specifies a path to ftp location. 

	.PARAMETER Recurse
	    Remove items recursively.		
			
	.PARAMETER Session
	    Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'. 
	
	.EXAMPLE
		PS> Remove-FTPItem -Path "/myFolder" -Recurse
		->Remove Dir: /myFolder/mySubFolder
		250 Remove directory operation successful.

		->Remove Dir: /myFolder
		250 Remove directory operation successful.

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
		[Switch]$Recurse = $False,
		$Session = "DefaultFTPSession"
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
		
		if ($pscmdlet.ShouldProcess($RequestUri,"Remove item from ftp location")) 
		{	
			[System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($RequestUri)
			$Request.Credentials = $CurrentSession.Credentials
			$Request.EnableSsl = $CurrentSession.EnableSsl
			$Request.KeepAlive = $CurrentSession.KeepAlive
			$Request.UseBinary = $CurrentSession.UseBinary
			$Request.UsePassive = $CurrentSession.UsePassive
			
			if((Get-FTPItemSize -Path $RequestUri -Session $Session -Silent) -ge 0)
			{
				$Request.Method = [System.Net.WebRequestMethods+FTP]::DeleteFile
				"->Remove File: $RequestUri"
			}
			else
			{
				$Request.Method = [System.Net.WebRequestMethods+FTP]::RemoveDirectory
				
				$SubItems = Get-FTPChildItem -Path $RequestUri -Session $Session 
				if($SubItems)
				{
					$RemoveFlag = 0
					if(!$Recurse)
					{
						$Title = "Remove recurse"
						$Message = "Do you want to recurse remove items from location?"

						$Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
						$No = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
						$Options = [System.Management.Automation.Host.ChoiceDescription[]]($No, $Yes)

						$RemoveFlag = $host.ui.PromptForChoice($Title, $Message, $Options, 0) 
					}
					else
					{
						$RemoveFlag = 1
					}
					
					if($RemoveFlag)
					{
						Foreach($SubItem in $SubItems)
						{
							Remove-FTPItem -Path ($RequestUri+"/"+$SubItem.Name.Trim()) -Session $Session -Recurse
						}
					}
					else
					{
						Return
					}
				}
				"->Remove Dir: $RequestUri"
			}
			
			Try
			{
				[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$CurrentSession.ignoreCert}
				$Response = $Request.GetResponse()

				$Status = $Response.StatusDescription
				$Response.Close()
				Return $Status
			}
			Catch
			{
				Write-Error $_.Exception.Message -ErrorAction Stop 
			}
		}
	}
	
	End{}				
}

Function Add-FTPItem
{
    <#
	.SYNOPSIS
	    Send file to specific ftp location.

	.DESCRIPTION
	    The Add-FTPItem cmdlet send file to specific location on ftp server.
		
	.PARAMETER Path
	    Specifies a path to ftp location. 

	.PARAMETER LocalPath
	    Specifies a local path. 

	.PARAMETER BufferSize
	    Specifies size of buffer. Default is 20KB. 		
			
	.PARAMETER Session
	    Specifies a friendly name for the ftp session. Default session name is 'DefaultFTPSession'.
		
	.PARAMETER Overwrite
	    Overwrite item on remote location. 		
	
	.EXAMPLE
		PS> Add-FTPItem -Path "/myfolder" -LocalPath "C:\myFile.txt"

		Dir          : -
		Right        : rw-r--r--
		Ln           : 1
		User         : ftp
		Group        : ftp
		Size         : 82033
		ModifiedDate : Aug 17 12:27
		Name         : myFile.txt
		
	.EXAMPLE
		PS> Get-ChildItem "C:\Folder" | Add-FTPItem

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
		[String]$Path = "",
		[parameter(Mandatory=$true,
			ValueFromPipelineByPropertyName=$true,
			ValueFromPipeline=$true)]
		[Alias("FullName")]		
		[String]$LocalPath,
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
		if(Test-Path $LocalPath)
		{
			$FileName = (Get-Item $LocalPath).Name
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
			$RequestUri = $RequestUri+"/"+$FileName
			$RequestUri = [regex]::Replace($RequestUri, '/$', '')
			$RequestUri = [regex]::Replace($RequestUri, '/+', '/')
			$RequestUri = [regex]::Replace($RequestUri, '^ftp:/', 'ftp://')
			Write-Debug "Remove additonal slash: $RequestUri"
				
			if ($pscmdlet.ShouldProcess($RequestUri,"Send item: '$LocalPath' in ftp location")) 
			{	
				[System.Net.FtpWebRequest]$Request = [System.Net.WebRequest]::Create($RequestUri)
				$Request.Credentials = $CurrentSession.Credentials
				$Request.EnableSsl = $CurrentSession.EnableSsl
				$Request.KeepAlive = $CurrentSession.KeepAlive
				$Request.UseBinary = $CurrentSession.UseBinary
				$Request.UsePassive = $CurrentSession.UsePassive

				Try
				{
					[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$CurrentSession.ignoreCert}
					
					$SendFlag = 1
					if($Overwrite -eq $false)
					{
						if((Get-FTPChildItem -Path $RequestUri -Session $Session).Name)
						{
							$FileSize = Get-FTPItemSize -Path $RequestUri -Session $Session -Silent
							
							$Title = "A File name: $FileName already exists in this location."
							$Message = "What do you want to do?"

							$ChoiceOverwrite = New-Object System.Management.Automation.Host.ChoiceDescription "&Overwrite"
							$ChoiceCancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel"
							if($FileSize -lt (Get-Item -Path $LocalPath).Length)
							{
								$ChoiceResume = New-Object System.Management.Automation.Host.ChoiceDescription "&Resume"
								$Options = [System.Management.Automation.Host.ChoiceDescription[]]($ChoiceCancel, $ChoiceOverwrite, $ChoiceResume)
								$SendFlag = $host.ui.PromptForChoice($Title, $Message, $Options, 2) 
							}
							else
							{
								$Options = [System.Management.Automation.Host.ChoiceDescription[]]($ChoiceCancel, $ChoiceOverwrite)		
								$SendFlag = $host.ui.PromptForChoice($Title, $Message, $Options, 1) 
							}	
						}
					}
					
					if($SendFlag -eq 2)
					{
						$Request.Method = [System.Net.WebRequestMethods+FTP]::AppendFile
					}
					else
					{
						$Request.Method = [System.Net.WebRequestMethods+FTP]::UploadFile
					}
					Write-Debug "Use WebRequestMethods: $($Request.Method)"
					
					if($SendFlag)
					{
						$File = [IO.File]::OpenRead( (Convert-Path $LocalPath) )
						Write-Debug "Open File: $LocalPath"
						
	           			$Response = $Request.GetRequestStream()
            			[Byte[]]$Buffer = New-Object Byte[] $BufferSize
						
						$ReadedData = 0
						$AllReadedData = 0
						$TotalData = (Get-Item $LocalPath).Length
						
						if($SendFlag -eq 2)
						{
							$SeekOrigin = [System.IO.SeekOrigin]::Begin
							$File.Seek($FileSize,$SeekOrigin) | Out-Null
							$AllReadedData = $FileSize
						}
						
						if($TotalData -eq 0)
						{
							$TotalData = 1
						}
						
					    Do {
               				$ReadedData = $File.Read($Buffer, 0, $Buffer.Length)
               				$AllReadedData += $ReadedData
               				$Response.Write($Buffer, 0, $ReadedData);
               				Write-Progress -Activity "Upload File: $Path/$FileName" -Status "Uploading:" -Percentcomplete ([int]($AllReadedData/$TotalData * 100))
            			} While($ReadedData -gt 0)
			
			            $File.Close()
            			$Response.Close()
						Write-Debug "Close File: $LocalPath"
						
						Return Get-FTPChildItem -Path $RequestUri -Session $Session
					}
					
				}
				Catch
				{
					Write-Error $_.Exception.Message -ErrorAction Stop 
				}
			}
		}
		else
		{
			Write-Error "Cannot find local path '$LocalPath' because it does not exist." -ErrorAction Stop 
		}
	}
	
	End{}				
}

<#
====================================================================================
  File:     SendBackup.ps1
  Author:   Changyong Xu
  Version:  SQL Server 2014, PowerShell V4
  Comment:  Delete files on FTP Server,and then send full backup files to it.
            You need write backup file name to C:\FileConfig.ini,
            and execute it like this:  .\SendBackup.ps1
====================================================================================
#>

Function SendBackup
{
    Param(
        [String]$Service = "TEMP"
    )

    Begin
    {
        $Log = Join-Path $Home "Documents/FTP.log"

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
    }

    Process
    {
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
            Get-FTPChildItem -Session $Session -Path $FTPPath | Remove-FTPItem -Session $Session

            #send backup to FTP Server
            $ConfigFile = "$PSScriptRoot\FileConfig.ini"
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
    }

    End{}
}

$ErrorActionPreference = "Stop"
SendBackup -Service $args[0]
Read-Host -Prompt "Press Enter to continue"