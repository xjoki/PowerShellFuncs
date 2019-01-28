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