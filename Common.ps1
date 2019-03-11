# Modul COMMON
#
# Cmdlets/Functions
# -----------------
# Check-ProfileScript
# Invoke-NetScan
# Send-Arp
# Test-HostOnline
# Get-PSVersion
# Get-ComputerSystemInfo
# Compare-PSVersion
# CreateSelfSignCertificateForCodeSigning
# Get-LoggedIn
# Copy-File
#
# Aliases
# -------
# ver

$iphlpapi = @" 
[DllImport("iphlpapi.dll", ExactSpelling=true)] 
   public static extern int SendARP(  
       uint DestIP, uint SrcIP, byte[] pMacAddr, ref int PhyAddrLen); 
"@ 

Add-Type -MemberDefinition $iphlpapi -Name Utils -Namespace Network 

Function Test-ProfileScript
{
    <#

    .SYNOPSIS
    Test-ProfileScript Prueft das Vorhandensein eines Profilskript. Wenn der Pfad zum Profilskript
    noch nicht existiert, wird das Verzeichnis und/oder die Datei erzeugt

    Version: 0.2
    ++++++++++++

    .DESCRIPTION
    Test-ProfileScript rueft das Vorhandensein eines Profilskript. Wenn der Pfad zum Profilskript noch
    nicht existiert, wird das Verzeichnis und/oder die Datei erzeugt. Der Parameter SelectedProfile
    legt fest, welches Profilskript geprueft werden soll. Mit dem Parameter OpenWith besteht die
    Moeglichkeit, die entsprechende Datei in einem Programm zum Editieren zu Oeffnen.

    .PARAMETER SelectProfile
    Mit SelectProfile wird das Profilskript ausgewaehlt. Hier steht zur Auswahl:
    AllUsersAllHosts, AllUsersCurrentHost, CurrentUserAllHosts, CurrentUserCurrentHost 

    .PARAMETER OpenWith
    Mit dem optionalen Parameter OpenWith kann angegeben werden, mit welchem Programm die entsprechende
    Datei zum Editieren geoeffnet werden soll. Voraussetzung zum erfolgreichen Aufruf, ist die
    Existenz des gewählten Programms.

    Ise     Oeffnet die PowerShell ISE
    Notepad Oeffnet den Texteditor Notepad
    Code    Oeffnet Visual Studio Code

 
    .EXAMPLE
    Test-ProfileScript AllUsersCurrentHost
    Test-ProfileScript -SelectedProfile CurrentUserCurrentHost -OpenWith Code
    
    #>

    [CmdletBinding()]

    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateSet("AllUsersAllHosts","AllUsersCurrentHost","CurrentUserAllHosts","CurrentUserCurrentHost")]
        [string]$SelectedProfile,
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Ise","Notepad","Code")]
        [string]$OpenWith
    )

    $path = $profile.$SelectedProfile
    $result = Test-Path -Path $path

    if(-not $result)
    {
        Write-Host "Pofilskript $path erzeugen"
        Write-Host "Soll die Profilskriptdatei erzeugt werden?"
        Write-Host -NoNewline "[J] Ja " 
        Write-Host -NoNewline -ForegroundColor Yellow "[N] Nein"
        Write-Host -NoNewline ' (Standard ist "N")  '  
        $input = Read-Host 
        if($input -eq "J")
        {
            New-Item -Path $path -ItemType File -Force
            "# $SelectedProfile" | Out-File $Path -Append
        }
    }

    if($OpenWith -ne $null)
    {
        &$OpenWith $path
    }
}

Function Invoke-NetScan
{
    <#
    .SYNOPSIS
    Scannt einen Bereich in einem Class-C Netz und liefert zurueck, welche IP-Adressen erreichbar sind.
    Neben den IP-Adressen werden auch MAC-Adressen ermittelt und zurueckgeliefert.

    Version: 0.2
    ++++++++++++

    .DESCRIPTION
    Invoke-NetScan sucht in einem Class-C Netz und liefert Informationen zurueck,
    welche IP Adressen erreichbar sind.

    .PARAMETER NetAddr
    Der Parameter NetAddr bestimmt das zu durchsuchende Netzwerk

    .PARAMETER ClientStart
    Mit ClientStart wird angegeben bei welcher Clientadresse die Suche beginnen soll.
    Per Vorgabe ist ClientStart 1

    .PARAMETER ClientEnd
    ClientEnd legt fest, bis zu welcher Clientadresse gesucht werden soll. Per Vorgabe ist
    ClientEnd 255    

    .EXAMPLE
    Invoke-NetScan -NetAddr 192.168.178 -ClientStart 10 -ClientEnd 20
    
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $NetAddr,
        [byte] $ClientStart = 1,
        [byte] $ClientEnd = 255
    )

    # Hashtable
    $ips = @{}
    
    $ipAddrs = $ClientStart..$ClientEnd | ForEach-Object {$NetAddr+"."+$_}
    $job = Test-Connection $ipAddrs -ErrorAction SilentlyContinue -Count 1 -AsJob
    $null = Wait-Job $job
    $result = Receive-Job $job | Where-Object {$null -ne $_.ResponseTime -and $null -ne $_.IPV4Address }  | Select-Object IPV4Address, IPV6Address

    foreach($r in $result)
    {
           try
           {
                if($null -ne $r.IPV4Address)
                {
                    $hostName = [System.Net.Dns]::GetHostByAddress($r.IPV4Address).HostName
                    
                    $MAC = Send-Arp -DestinationIPAddress $r.IPV4Address
                    
                    $CptInformation = New-Object PSObject -Property @{ 
                        HostName = $hostName
                        MACAddr = $MAC
                    }
                    $ips.Add($r.IPV4Address, $CptInformation) 
                }
           }
           catch 
           {    
                Write-Error "Error $r"
                continue
           }
          
    }
    
    Remove-Job $job

    $ips
}


Function Test-HostOnline
{
    <#
    .SYNOPSIS
    Test-HostOnline

    Version: 0.1
    ++++++++++++

    .DESCRIPTION
    Test-HostOnline prüft, ob eine Verbindung zu einem Host möglich ist.

    .PARAMETER Host
    Mit dem Parameter Host wird der zu testende Host festgelegt.

    .EXAMPLE
    Test-HostOnline -Host localhost
    Test-HostOnline -Host www.microsoft.com
    
    #>

    [CmdletBinding()]

    param
    (
        [Parameter(Mandatory=$true)]
        [String] $ComputerName
    )

    return (Test-Connection $ComputerName -Count 1 -Quiet)
}

Function Send-Arp
{
    <#
    .SYNOPSIS
    Send-Arp

    Version: 0.2
    ++++++++++++

    .DESCRIPTION
    Send-Arp sendet eine ARP-Anforderung (Address Resolution Protocol),
    um die physische Adresse zu erhalten, die der angegebenen IPv4-Zieladresse entspricht.
   
    .PARAMETER DestinationIPAddress
    Die IPv4-Zieladresse. Die ARP-Anforderung versucht, die physikalische Adresse abzurufen,
    die dieser IPv4-Adresse entspricht.

    .EXAMPLE
    Send-Arp -DestinationIPAddress 192.168.178.4
    
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Position=0, Mandatory=$true)]
        $DestinationIPAddress
    )
    
   # $SourceIPAddress = 0

    try 
    { 
        $DstIp = [System.Net.IPAddress]::Parse($DestinationIPAddress) 
        $DstIp = [System.BitConverter]::ToUInt32($DstIp.GetAddressBytes(), 0) 
    }
    catch
    { 
        Write-Error "$($DestinationIPAddress) kann nicht in eine IP-Adresse konvertiert werden." 
        break 
    } 
 
    $SendARPInfo = New-Object PSObject -Property @{ 
        IpAddress = $DstIpAddress 
        PhysicalAddress = '' 
        Description = '' 
        ArpSuccess = $true 
    } 
 
    $MacAddress = New-Object Byte[] 6 
    $MacAddressLength = [uint32]$MacAddress.Length 
 
    $Ret = [Network.Utils]::SendARP($DstIp, 0, $MacAddress, [ref]$MacAddressLength) 
 
    if ($Ret -ne 0)
    { 
        $SendARPInfo.Description =  "SendArp() hat einen Fehler zurueckgeliefert.$($Ret)" 
        $SendARPInfo.ArpSuccess = $false 
    }
    else 
    { 
        $Mac = @() 
        foreach ($b in $MacAddress)
        { 
            $Mac += $b.ToString('X2') 
        } 
 
        $SendARPInfo.PhysicalAddress = ($Mac -join ':') 
    } 
     
    return $SendARPInfo.PhysicalAddress
}

Function Create-SelfSignedCertificateForCodeSigning
{
     <#
    .SYNOPSIS
    Erzeugen eines selbst signierten Zertifikats zur Codesignierung
    Erfordert PowerShell Version 4

    Version: 0.2
    ++++++++++++

    .DESCRIPTION
    Create-SelfSignedCertificateForCodeSigning erzeugt ein selbst signiertes Zertifikat
    zur Codesignierung und speichert dieses in einer .PFX Datei. Nachdem das Zertifikat
    erzeugt wurde, wird das zum Zugriff auf das Zertifikat zu verwendende Passwort abgefragt
    und anschließend in eine PFX-Datei exportiert. Danach wird das Zertifikat aus dem
    Zertifikatsspeicher gelöscht.

    WICHTIG: Wenn das Kennwort vergessen wird, kann das Zertifikat nicht mehr verwendet werden.

    .PARAMETER Path
    Pfadangabe, wohin das Zertifikatsfile gepeichert werden soll

    .PARAMETER File
    Dateiname der zu speichernden .PFX Datei. Die Dateierweiterung .PFX ist ebenfalls anzugeben.
    Es wird nicht vom Cmdlet geprüft, ob die Dateierweiterung dieses Parameters .PFX ist.
    Der Nutzer ist also frei in seiner Entscheidung auch eine andere Extension zu verwenden.

    .PARAMETER FriendlyName
    Einfach zu lesender Name, z.B. 'MeinZertifikat'

    .PARAMETER Subject
    z.B.: CN=Zertifikatsabteilung

    .PARAMETER Duration
    Legt die Gültigkeitsdauer des Zertifikats in Monaten fest.
    Per Vorgabe sind 60 Monate (5 Jahre) festgelegt.
    
    .EXAMPLE
    Create-SelfSignedCertificateForCodeSigning -FriendlyName JoKi-Codesigning-Certificate `
    -Subject CN=JoKi-Sign -FileName jokicscert.pfx

    #>
    
    [CmdletBinding()]
    param
    (
        [Parameter(Position=0,Mandatory=$true)]
        [string] $FriendlyName,
        [Parameter(Position=1,Mandatory=$true)]
        [string] $Subject,
        [Parameter(Position=2,Mandatory=$true)]
        [string] $FileName,
        [string] $Path = '.',
        [int] $DurationMonth = 60
    )

    # PowerShell 4 ist Voraussetzung
    if((Compare-PSVersion -Version 4) -eq $false)
    {
        Write-Error "Create-SelfsignedCertificateForCodeSigning erfordert mindestens PowerShell 4"
        return
    }

    # da das Zertifikat gespeichert werden soll, wird als erses geprüft, ob der angegebene Pfad
    # existiert

    $result = Test-Path -Path $path
    if($result -eq $false)
    {
        Write-Error "Der angegebene Pfad $Path existiert nicht."
        return $null
    }
    
    $certDestinationFile = Join-Path -Path $path -ChildPath $FileName

   
    $credential = Get-Credential -Message "Geben sie bitte Benutzername und Kennwort für das Zertifikat ein."
    
    if($null -eq $credential)
    {
        Write-Error -Message "Keine gültige Kombination aus Benutzer/Passwort."
        return $null
    }

    $credCompare = Get-Credential -Message "Bitte Kennwort wiederholen." -UserName $credential.UserName
    if($null -eq $credCompare)
    {
        Write-Error -Message "Keine gültige Kombination aus Benutzer/Passwort."
        return $null
    }

    if($credCompare.GetNetworkCredential().Password -cne $credential.GetNetworkCredential().Password)
    {
        Write-Error -Message "Passworteingabe war nicht identisch!"
        return $null
    }

    # Zertifikat erzeugen
    # 1.3.6.1.5.5.7.3.3 / id-kp-CodeSigning
    # s. http://www.oid-info.com/get/1.3.6.1.5.5.7.3.3
    # 2.5.29.37 / certificateExtension
    # s. https://www.alvestrand.no/objectid/2.5.29.html

    $certificate = New-SelfSignedCertificate -KeyUsage DigitalSignature -KeySpec Signature -FriendlyName $FriendlyName -KeyExportPolicy ExportableEncrypted -NotAfter (Get-Date).AddMonths($DurationMonth) -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3') -Subject CN=$Subject

    if($null -eq $certificate)
    {
        Write-Error "Fehler beim Erzeugen des Zertifikats."
        return $null
    }
    
    # Das Zertifikat soll gespeichert werden, bevor es aus dem Zertifikatsspeicher
    # gelöscht wird.

    $result = $certificate | Export-PfxCertificate -Password $credential.Password -FilePath $certDestinationFile


    $certificate | Remove-Item
    Write-Verbose -Message "Zertifikat wurde aus dem Zertifikatsspeicher gelöscht."
}

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

Function Get-LoggedIn
{
    <#
    .SYNOPSIS
    Get-LoggedIn

    Version: 0.2
    ++++++++++++

    .DESCRIPTION
    Get-LoggedIn liefert zurück, welcher Benutzer angemeldet ist.
    Mit dem Parameter ComputerName kann festgelegt werden, für welche Computer
    zurückgeliefert werden soll, welcher Benutzer angemeldet ist.
    Wird ComputerName nicht angegeben, wird automatisch der angemeldete Benutzer
    des lokalen Systems (localhost) zurückgegeben.

    .PARAMETER ComputerName
    Mit dem Parameter ComputerName wird festgelegt, für welche Computer zurückgeliefert
    werden soll, welcher Benutzer angemeldet ist. Die Angabe ist optional. Ohne Angabe
    wird automatisch der angemeldetet Benutzer des lokalen Systems zurückgegeben.

    .EXAMPLE
    Get-LoggedIn
    .EXAMPLE
    Get-LoggedIn -ComputerName SRV01,SRV02,DC01
    
    #>

    [CmdletBinding()]
    param
    (
        $ComputerName="localhost"
    )
 
    (Get-WmiObject Win32_ComputerSystem -ComputerName $ComputerName).username
    
}
Function Compare-PSVersion
{
    <#
    .SYNOPSIS
    Prüft, ob mindestens die angegebene Version der PowerShell vorhanden ist. 

    Version: 0.3
    ++++++++++++

    .DESCRIPTION
    Prüft, ob mindestens die angegebene Version der PowerShell vorhanden ist.
    Per Vorgabe ist Minor 0

    .PARAMETER Version
    Der Parameter Version legt fest, welche Mindestversion gefordert ist.
    Soll mindestens Version 3 der PowerShell vorliegen lautet der Aufruf
    Compare-PSVersion -Version 3

    .PARAMETER Minor
    Mit Minor wird die Versionsnummer hinter dem Punkt ebenfalls berücksichtigt.
    Per Vorgabe ist Minor immer 0. Soll beispielsweise geprüft werden, ob Version
    5.1 der PowerShell installiert ist, lautet der Aufruf
    Compare-PSVersion -Version 5 -Minor 1


    .EXAMPLE
    Compare-PSVersion -Version 3
    Compare-PSVersion 5
    .EXAMPLE
    Compare-PSVersion -Version 5 -Minor 1
    Compare-PSVersion 5 -Minor 1
    
    #>

    param( 
        [Parameter(Position=0, Mandatory=$true)]
        [Int32] $Version, 
        [Int32] $Minor=0
    )
    
    $PSVersionTable.PSVersion.Major -ge $Version -and $PSVersionTable.PSVersion.Minor -ge $Minor
}

Set-Alias ver Get-PSVersion

Function Get-ComputerSystemInfo
{
    <#
    .SYNOPSIS
    Get-ComputerSystemInfo

    Version: 0.2
    ++++++++++++

    .DESCRIPTION
    Get-ComputerSystemInfo

    .PARAMETER ComputerName

    .EXAMPLE
    Get-ComputerSystemInfo
    Get-ComputerSystemInfo -ComputerName SRV01
    
    #>

    [CmdletBinding()]
    param
    (
        [ValidateNotNullOrEmpty()]
        [String] $ComputerName = "localhost"
    )

    $d = $null
    $props = "DNSHostName","DomainRole","Domain","HypervisorPresent","Manufacturer","Model",
    "NumberOfLogicalProcessors","NumberOfProcessors","SystemFamily","SystemType","TotalPhysicalMemory",
    "UserName", "WorkGroup"
    
    $domainRoleEntrys = @{
        0="Eigenstaendige Arbeitsstation";
        1="Mitglied der Domaene/Arbeitsgruppe";
        2="Eigenstaendiger Server";
        3="Mitgliedsserver";
        4="Reservedomaenencontroller";
        5="Primaerer Domaenencontroller"
    }

    if($ComputerName -eq "localhost")
    {
        $d = Get-WmiObject -Class CIM_ComputerSystem |
        Select-Object $props
    }
    else {
        $d = Invoke-Command -ComputerName $ComputerName -ScriptBlock {Get-WmiObject -Class CIM_ComputerSystem} |
        Select-Object $props
    }

    $ComputerSystemInfo = New-Object PSObject -Property @{ 
        DNSHostName = $d.DNSHostName
        DomainRole = $domainRoleEntrys.([int32]$domainRoleValue)
        Domain = $d.Domain
        HyperVisorPresent = $d.HyperVisorPresent
        Manufacturer = $d.Manufacturer
        Model = $d.Model
        NumberOfLogicalProcessors = $d.NumberOfLogicalProcessors
        NumberOfProcessors = $d.NumberOfProcessors
        SystemFamily = $d.SystemFamily
        SystemType = $d.SystemType
        TotalPhysicalMemoryGB = $d.TotalPhysicalMemory / 1GB
        UserName = $d.UserName
        WorkGroup = $d.WorkGroup 
    } 

    $ComputerSystemInfo
}

function Copy-File
{
     <#
    .SYNOPSIS
    Kopiert eine Datei mit Fortschrittsanzeige

    Version: 0.1
    ++++++++++++

    .DESCRIPTION
    Kopiert eine Datei mit Fortschrittsanzeige.
    Mit Copy-File kann nur eine einzelne Datei kopiert werden. Die Verwendung von Wildcards ist nicht möglich.
    Sofern die Datei im Ziel schon existiert, wird nicht kopiert.

    .PARAMETER Source
    Legt die Quelle fest.

    .PARAMETER Destination
    Legt das Ziel fest.

    .PARAMETER BufferSize
    Legt die Größe des Speicherpuffer für den Kopiervorgang fest.
    Per Vorgabe ist die Größe auf 8192 Bytes (8KB) festgelegt.

    .PARAMETER AutoBufferSize
    Durch die Verwendung des Schalterparameter AutoBufferSize, wird der Puffer in Abhängigkeit der Dateigröße
    automatisch reserviert. Eine ggf. vorhandene Angabe in BufferSize wird ignoriert.

    .PARAMETER OBuffer
    Mit dem Parameter Buffer kann ein Speicherbereich übergeben werden. In dem Fall reserviert Copy-File
    keinen Speicher, sondern verwendet den übergebenen Speicher für die Kopieraktion. Dies ist insbesondere
    beim Kopieren von mehreren Dateien hilfreich, da damit nicht jedesmal aufs Neue Speicher allokiert
    werden muss.

    .EXAMPLE
    Copy-File -Source C:\MyDir1\datei1.bin -Destinatination C:\MyDir1\Kopie_datei1.bin

    dir *.avhdx | `
       % {Copy-File -Source $_.FullName -Destination (Join-Path -Path C:\SaveMyVM\Kopie\ -ChildPath $_.Name) -AutoBufferSize -Verbose}
    #>

    param(
        [Parameter(Mandatory=$true)]
        [String] $Source,
        [Parameter(Mandatory=$true)]
        [String] $Destination,
        [long] $BufferSize = 8KB,
        [byte[]] $OBuffer = $null,
        [Switch] $AutoBufferSize
    )

    $copyProgress = $false
    $workDirectory = Get-Location
    $items = $Source.Split('\')
    if($items -ne $null -and $items.Length -eq 1)
    {
        $Source = Join-Path -Path $workDirectory -ChildPath $Source
    }
    $items = $Destination.Split('\')
    if($items -ne $null -and $items.Length -eq 1)
    {
        $Destination = Join-Path -Path $workDirectory -ChildPath $Destination
    }

    $result = Test-Path -Path $Source
    if($result -eq $false)
    {
        Write-Error -Message "$Source nicht gefunden."
        return
    }

    $result = Test-Path -Path $Destination

    if($result -eq $true)
    {
        Write-Warning -Message "$Destionation schon vorhanden!"
        return
    }

    try 
    {
        $hsource = [io.file]::OpenRead($Source)
        $hdest = [io.file]::OpenWrite($Destination)

        if($hsource -eq $null)
        {
            Write-Error "$Source konnte nicht geöffnet werden."
            return
        }

        if($hdest -eq $null)
        {
            Write-Error "$Destination konnte nicht geöffnet werden."
            return
        }

        # Speicher für Puffer allokieren, sofern kein OutBuffer
        if($AutoBufferSize -eq $true -and $OBuffer -eq $null)
        {
            $f = Get-Item -Path $Source
            $fileSize = $f.Length

            $BufferSize = 64KB
            if($fileSize -ge 10MB)
            {
                $BufferSize = 500KB
            }
            if($fileSize -ge 100MB)
            {
                $BufferSize = 12MB
            }
            if($fileSize -ge 1GB)
            {
                $BufferSize = 128MB
            }
        }

        $buffer = $null

        if($OBuffer -ne $null)
        {
            $buffer = $OBuffer
            $BufferSize = $OBuffer.Length
        }
        else {
            [byte[]]$buffer = New-Object Byte[] $BufferSize    
        }

        Write-Verbose "Pufferspeicher: $BufferSize Byte"
        
        $total = 0
        $counter = 0
        $copyProgress = $true

        do
        {
            $counter = $hsource.Read($buffer, 0, $buffer.Length)
            $hdest.Write($buffer, 0, $counter)
            $total += $counter
            
            # Division durch Null vermeiden
            if($hSource.Length -gt 0) 
            {
                Write-Progress -Activity "Kopiere $Source" -PercentComplete ($total/$hsource.Length*100)
            }
            

        } while($counter -gt 0)
    }
    finally
    {
        if($hsource -ne $null)
        {
            $hsource.Dispose()
        }
        if($hdest -ne $null)
        {
            $hdest.Dispose()
        }
        if($copyProgress -eq $true)
        {
            Write-Progress -Activity "Kopiere $Source" -Completed
        }
    }
}