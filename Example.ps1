###### CONFIG GOES HERE #########

    # Would you like to generate scripts for an SSDT project or plain PowerShell
    $Format = "ps" # for SSDT use "ssdt"

    # What SQL Server instance are your databases on?
    $SQLInstance = "SQLSERVER\SQLINSTANCE"

    # What sort of environment is this?
    $Environment = "Dev"

    # What databases do you have on your SQL instance? You can add as many as you like.
    # Note: Project name is important for SSDT format, for PowerShell format you probably 
    # want to use the database name for ProjectName too.
    $DbObjArray = @()
    $tmpObject = New-Object PSObject
    $tmpObject | Add-Member -MemberType NoteProperty -Name "DatabaseName" -Value "DB1"
    $tmpObject | Add-Member -MemberType NoteProperty -Name "ProjectName" -Value "DB1"
    $DBobjArray += $tmpObject

    # $tmpObject2 = New-Object PSObject
    # $tmpObject2 | Add-Member -MemberType NoteProperty -Name "DatabaseName" -Value "DB2"
    # $tmpObject2 | Add-Member -MemberType NoteProperty -Name "ProjectName" -Value "DB2"
    # $DbObjArray += $tmpObject2

    # $tmpObject3 = New-Object PSObject
    # $tmpObject3 | Add-Member -MemberType NoteProperty -Name "DatabaseName" -Value "DB3"
    # $tmpObject3 | Add-Member -MemberType NoteProperty -Name "ProjectName" -Value "DB3"
    # $DbObjArray += $tmpObject3

    # etc

# Executing GeneratePermissions.ps1

    .\GeneratePermissions -SQLInstance $SQLInstance -Environment $Environment -DbObjArray $DbObjArray -Format $Format