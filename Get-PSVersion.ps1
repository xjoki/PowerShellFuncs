Function Get-PSVersion
{
    <#
    .SYNOPSIS
    Liefert Informationen zur PowerShell Version.

    Version: 0.1
    ++++++++++++

    .DESCRIPTION
    Get-PSVersion liefert Information über die PowerShell Version als Textausgabe
    oder vollständige Informationen der PowerShell Versionstabelle.

    .PARAMETER FullInfo
    Mit dem Parameterschalter wird angegeben, dass vollständige Informationen der
    PowerShell Versionstabelle geliefert werden sollen.

    .EXAMPLE
    Get-PSVersion
    .EXAMPLE
    Get-PSVersion -FullInfo
    
    #>

    param
    (
        [Switch] $FullInfo
    )

    if($FullInfo)
    {
        $PSVersionTable
    }
    else {
        "Microsoft PowerShell [Version " + $PSVersionTable.PSVersion.ToString()+"]"    
    }
}

Function Get-PSVersionCheck
{
    <#
    .SYNOPSIS
    Prüft, ob mindestens die angegebene Version der PowerShell vorhanden ist. 

    Version: 0.1
    ++++++++++++

    .DESCRIPTION
    Prüft, ob mindestens die angegebene Version der PowerShell vorhanden ist.
    Per Vorgabe ist Minor 0

    .PARAMETER Version
    Der Parameter Version legt fest, welche Mindestversion gefordert ist.
    Soll mindestens Version 3 der PowerShell vorliegen lautet der Aufruf
    Get-PSVersionCheck -Version 3

    .PARAMETER Minor
    Mit Minor wird die Versionsnummer hinter dem Punkt ebenfalls berücksichtigt.
    Per Vorgabe ist Minor immer 0. Soll beispielsweise geprüft werden, ob Version
    5.1 der PowerShell installiert ist, lautet der Aufruf
    Get-PSVersionCheck -Version 5 -Minor 1


    .EXAMPLE
    Get-PSVersionCheck -Version 3
    .EXAMPLE
    Get-PSVersionCheck -Version 5 -Minor 1
    
    #>

    param( 
        [Parameter(Mandatory=$true)]
        [Int32] $Version, 
        [Int32] $Minor=0
    )
    
    $PSVersionTable.PSVersion.Major -ge $Version -and $PSVersionTable.PSVersion.Minor -ge $Minor
}

Set-Alias ver Get-PSVersion
