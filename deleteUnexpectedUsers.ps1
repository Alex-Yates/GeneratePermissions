param(
    [Parameter(Mandatory)]$ServerInstance,
    [Parameter(Mandatory)]$Database
)

$ErrorActionPreference = "stop"

# For more info about dbatools: https://dbatools.io/
Import-Module dbatools

# Add the users that you expect to exist on the target database here
$expectedUsers = @(
    _AddExpectedUsersHere_
)

# These are the default system users for any SQL Server database
$systemUsers = @(
    "dbo",
    "guest",
    "INFORMATION_SCHEMA",
    "sys"
)

# Finding all the existing users on the target database
$existingUsers = Get-DbaDbUser -SqlInstance $ServerInstance -Database $Database

# Removing any existing users that are not either expected users or system 
$deletedUsers = @()
foreach ($user in $existingUsers){
    if (($expectedUsers -NotContains $user.Name) -and ($systemUsers -NotContains $user.Name)){
        $unexpectedUser = $user.Name
        Write-Warning "Found unexpected user: $unexpectedUser."
        Write-Output "Removing unexpected user: $unexpectedUser."
        Remove-DbaDbUser -SqlInstance $ServerInstance -Database $Database -User $unexpectedUser
        $deletedUsers = $deletedUsers + $unexpectedUser
    }
}
if ($totalUnexpectedUsers -eq 0){
    Write-Host "Great news! No unexpected users found on $ServerInstance.$Database."
}
else{
    $numDeleted = $deletedUsers.length
    Write-Host "Removed $numDeleted unexpected users from $ServerInstance.$Database" + ":"
    foreach($user in $deletedUsers){
        write-host "- $user"
    }   
}