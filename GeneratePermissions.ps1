############################################################################################################
# This script works in conjunction with some .sql files (that should exist in the same folder
#   to generate scripts that will recreate 
#   principles and permissions for those principles as they are currently defined for a named 
#   principle on a named server in a named database.
#
# The output file is placed into a folder at:
# .\[ProjectName]\Scripts\Post-Deploy\SecurityAdditions\PermissionSets\
# .\[ProjectName]\Scripts\Post-Deploy\SecurityAdditions\Users\
#
# Execute using> .\GeneratePermissions.ps1 -SQLInstance instanceName -Environment XXX
#  e.g.        > .\GeneratePermissions.ps1 -SQLInstance "localhost" -Environment DEV
#
# by Jamie Thomson
# 21st July 2010
#
#
# Peter Schott - 2011-02-17
# Created a section to handle the Role Permissions
# Tweaked script to appropriately handle Principle.Name property
#  (prior version pointed to a non-existent/set $DatabasePrinciple variable of some sort)
############################################################################################################

#####PARAMETERS#####
Param(
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$SQLInstance,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$Environment,
	[Parameter(Mandatory)][ValidateNotNullOrEmpty()]$DbObjArray,
	$OutputDir = "",
	[ValidateSet('ssdt','ps')]$Format = "ssdt",
	[switch]$includeRolePermissions = $false
)

$ErrorActionPreference = "Stop"

#####Add all the SQL goodies (including Invoke-Sqlcmd)#####
# Note: need to upgrade these to use dbatools or the latest sql server module
add-pssnapin sqlserverprovidersnapin100 -ErrorAction SilentlyContinue
add-pssnapin sqlservercmdletsnapin100 -ErrorAction SilentlyContinue

# For more info about dbatools: https://dbatools.io/
Import-Module dbatools

if ($Format -notlike "ssdt" -and $Format -notlike "ps"){
	Write-Error "Format must be set to either 'ssdt' or 'ps' but it is set to $format"
}

if ($OutputDir -like ""){
	$OutputDir = Join-Path -Path $PSScriptRoot -ChildPath "output"
}

Foreach($DbObj in $DbObjArray)
{
	$DbName = $DbObj.DatabaseName
	$ProjectName = $DbObj.ProjectName
	"DB: " + $DbName + "   Project: " + $ProjectName
	$ProjectPath = Join-Path -Path $OutputDir -ChildPath $ProjectName
	$OutputDirPath = Join-Path -Path $ProjectPath -ChildPath "Scripts\Post-Deploy\Security"
	If(!(Test-Path -path $OutputDirPath)){   
		New-Item -Path $OutputDirPath -ItemType Directory | out-null  #One way of making sure no output makes it to the console.
		"   Created folder " + $OutputDirPath
	}
	$EnvironmentWrapperFile = ""
	if ($Format -like "ssdt"){
		$EnvironmentWrapperFile = Join-Path -Path $OutputDirPath -ChildPath "DeploySecurity_$Environment.sql"
	}
	if ($Format -like "ps"){
		$EnvironmentWrapperFile = Join-Path -Path $OutputDirPath -ChildPath "DeploySecurity_$Environment.ps1"
	}
	If(Test-Path -path $EnvironmentWrapperFile){   
		Remove-Item -Path $EnvironmentWrapperFile -Force | out-null  #One way of making sure no output makes it to the console.
		"   Deleted existing file " + $EnvironmentWrapperFile
		}
	New-Item -Path $EnvironmentWrapperFile -ItemType File | out-null
	"   Created new file " + $EnvironmentWrapperFile

	#####CREATE FOLDERS (IF NOT EXIST)#####
	$UsersFolder = Join-Path -Path $OutputDirPath -ChildPath "Users"
	If(!(Test-Path -path $UsersFolder)){   
		mkdir $UsersFolder | out-null  #One way of making sure no output makes it to the console.
		"   Created folder " + $UsersFolder
		}
	if($includeRolePermissions){
		$RolesFolder = Join-Path -Path $OutputDirPath -ChildPath "RolePermissions"
		If(!(Test-Path -path $RolesFolder)){   
			mkdir $RolesFolder | out-null  #One way of making sure no output makes it to the console.
			"   Created folder " + $RolesFolder
		}
	}
	$PermissionsFolder = Join-Path -Path $OutputDirPath -ChildPath "PermissionSets"
	If(!(Test-Path -path $PermissionsFolder)){
		[void](mkdir $PermissionsFolder)   #Another way of making sure no output makes it to the console.
		"   Created folder " + $PermissionsFolder
		}
	if($Format -like "ps"){
		"Param(" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		'	$ServerInstance,' | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		'	$Database,' | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		'	[switch]$dropUnexpectedUsers = $false' | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		")" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		"" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append #Empty line
		'if ($dropUnexpectedUsers){' | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		'	$args = @{' | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		'		ServerInstance=$ServerInstance;' | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		'		Database=$Database' | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		'	}' | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		'	$command = "$PSScriptRoot' + "\deleteUnexpectedUsers__$Environment.ps1`"" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		'	&$command @args # Deleting unexpected users!' | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		"}" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		"" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append #Empty line
	}

	if($includeRolePermissions){	
		$RoleList = Invoke-SqlCmd -MaxCharLength 500 -ServerInstance $SQLInstance -database $DBName -InputFile "$PSScriptRoot\GetDatabaseRoleList.sql"
		if ($Format -like "ssdt"){
			"PRINT 'Create role permissions for " + '$(DeployType)' + "';" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile
		}	
		if ($Format -like "ps"){
			"Write-Output `"Create role permissions for $Environment`"" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		}	
		Foreach ($Role in $RoleList)
		{
			"   " + $Role.Name
			$VariableArray = "PrincipleName='" + $Role.Name + "'"
			$fileName = $Role.name + "___" + $Environment + ".sql"
			$OutPath = Join-Path -Path $RolesFolder -ChildPath $fileName
			Invoke-SqlCmd -MaxCharLength 500 -ServerInstance $SqlInstance -database $DBName -Variable $VariableArray -InputFile "$PSScriptRoot\CreateDDLForAssigningPermissionsPerPrinciple.sql" | Out-File -width 500 -encoding ascii -FilePath $OutPath #ascii encoding is important if committing to Subversion

			#Trim all trailing/leading spaces in the generated file
			(gc $OutPath)| % {$_.trim()} | sc $OutPath

			if ($Format -like "ssdt"){
				":r .\RolePermissions\$fileName" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
			}
			if ($Format -like "ps"){
				"Invoke-SqlCmd -InputFile " + '$PSScriptRoot' + "\RolePermissions\`"$filename`" -ServerInstance " + '$ServerInstance' + " -Database " + '$Database' | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii		
				}	
		}
	}

	$PrincipleList = Invoke-SqlCmd -MaxCharLength 500 -ServerInstance $SQLInstance -database $DBName -InputFile "$PSScriptRoot\GetDatabasePrincipalList.sql"
	"" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append #Empty line
	
	#####CREATE USERS#####	
	if ($Format -like "ssdt"){
		"PRINT 'Create users for " + '$(DeployType)' + "';" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
	}	
	if ($Format -like "ps"){
		"Write-Output `"Create users for $Environment`"" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
	}

	$expectedUsers = @()

	Foreach ($Principle in $PrincipleList)
	{
		"   " + $Principle.Name
		$PrincipleName = $Principle.Name
		$formattedPrincipleName = "`"$PrincipleName`"" # Later we need a list of users with quotes
		$expectedUsers = $expectedUsers + $formattedPrincipleName
		$ReplacedPrinciple = $Principle.name.replace('\','_') #Stripping out backslashes so we can use in a filename

		$StmtCheckIfUserExists = "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '" + $Principle.name + "') AND EXISTS (select 'x' from master.dbo.syslogins where name = '" + $Principle.Login + "')
		" 
		$StmtCreateUser = 'CREATE USER ['
		$StmtForLogin = '] FOR LOGIN ['
		$StmtDefaultSchema = '] WITH DEFAULT_SCHEMA=['
		$StmtEnd = '];'
		$WholeStmt = $StmtCheckIfUserExists + $StmtCreateUser + $Principle.name + $StmtForLogin + $Principle.Login
		If ($Principle.default_schema_name.Length -gt 0 )  #If there is a default schema, include it!
		{
			$WholeStmt = $WholeStmt + $StmtDefaultSchema + $Principle.default_schema_name
		}
		$WholeStmt = $WholeStmt + $StmtEnd
		$fileName = $ReplacedPrinciple + ".user.sql"
		$OutPath = Join-Path -Path $UsersFolder -Child $fileName
		$WholeStmt | Out-File -width 500 -encoding ascii -FilePath $OutPath
		
		#Trim all trailing/leading spaces in the generated file
		(gc $OutPath)| % {$_.trim()} | sc $OutPath
		
		if ($Format -like "ssdt"){
			":r .\Users\$fileName" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		}
		if ($Format -like "ps"){
			"Invoke-SqlCmd -InputFile " + '$PSScriptRoot' + "\Users\`"$fileName`" -ServerInstance " + '$ServerInstance' + " -Database " + '$Database' | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		}		
	}

	# Generating the script to drop unexpected additional users
	$templateDropUserFile = Join-Path -Path $PSScriptRoot -ChildPath "deleteUnexpectedUsers.ps1"
	$newDropUserFile = Join-Path -Path $OutputDirPath -ChildPath "deleteUnexpectedUsers__$Environment.ps1"

	# Dropping the Drop User File if already exists
	if(test-path $newDropUserFile){
		Remove-Item $newDropUserFile
	}
	$expectedUsersFormatted = $expectedUsers -join "," # casting array of expected users to string, comma separated
	$newFile = New-Item $newDropUserFile -ItemType "file"
	$content = Get-Content -Path $templateDropUserFile
	$content -replace '_AddExpectedUsersHere_', $expectedUsersFormatted | Out-File -width 500 -append -FilePath $newFile -encoding ascii

	#####SCRIPT PERMISSIONS#####
	"" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append #Empty line
	if ($Format -like "ssdt"){
		"PRINT 'Create permissions for " + '$(DeployType)' + "';" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
	}	
	if ($Format -like "ps"){
		"Write-Output `"Create permissions for $Environment`"" | Out-File -width 500 -FilePath $EnvironmentWrapperFile -encoding ascii -append
	}
	
	Foreach ($Principle in $PrincipleList)
	{
		$ReplacedPrinciple = $Principle.name.replace('\','_') #Stripping out backslashes so we can use in a filename
		$VariableArray = "PrincipleName='" + $Principle.name + "'"
		$fileName = $ReplacedPrinciple + "___" + $Environment + ".sql"
		$OutPath = Join-Path -Path $PermissionsFolder -ChildPath $fileName
		Invoke-SqlCmd -MaxCharLength 500 -ServerInstance $SqlInstance -database $DBName -Variable $VariableArray -InputFile "$PSScriptRoot\CreateDDLForAssigningPermissionsPerPrinciple.sql" | Out-File -width 500 -encoding ascii -FilePath $OutPath #ascii encoding is important if committing to Subversion
		
		#Trim all trailing/leading spaces in the generated file
		(gc $OutPath)| % {$_.trim()} | sc $OutPath

		if ($Format -like "ssdt"){
			":r .\PermissionSets\$fileName" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		}
		if ($Format -like "ps"){
			"Invoke-SqlCmd -InputFile " + '$PSScriptRoot' + "\PermissionSets\`"$fileName`" -ServerInstance " + '$ServerInstance' + " -Database " + '$Database' | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
		}
		
	}
	
	# Generating role memberships script
	$RoleMembershipList = Invoke-SqlCmd -MaxCharLength 500 -ServerInstance $SQLInstance -database $DBName -InputFile "$PSScriptRoot\Generate sp_addrolemember statements.sql"
	$RoleMembershipsScript = Join-Path -Path $OutputDirPath -ChildPath "RoleMemberships___$Environment.sql"
	if(test-path $RoleMembershipsScript){
		remove-item $RoleMembershipsScript
	}	
	New-Item -Path $RoleMembershipsScript -ItemType File | out-null 
	Foreach ($RoleMembership in $RoleMembershipList)
	{
		$RoleMembership.Stmt | Out-File -width 500 -encoding ascii -FilePath $RoleMembershipsScript -append #Empty line
	}

	# Updating Security wrapper to execute role memberships script
	"" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append #Empty line
	if ($Format -like "ssdt"){
		"PRINT 'Create role memberships for " + '$(DeployType)' + "';" | Out-File -width 500 -encoding ascii -FilePath $EnvironmentWrapperFile -append
		":r .\RoleMemberships___$Environment.sql" | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
	}	
	if ($Format -like "ps"){
		"Write-Output `"Create role memberships for $Environment`"" | Out-File -width 500 -FilePath $EnvironmentWrapperFile -encoding ascii -append
		"Invoke-SqlCmd -InputFile " + '$PSScriptRoot' + "\RoleMemberships___$Environment.sql -ServerInstance " + '$ServerInstance' + " -database " + '$Database' | Out-File -width 500 -append -FilePath $EnvironmentWrapperFile -encoding ascii
	}	

	#Trim all trailing/leading spaces in the generated Environment Wrapper file
	(gc $EnvironmentWrapperFile)| % {$_.trim()} | sc $EnvironmentWrapperFile
	
}