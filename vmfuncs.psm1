function Save-VM
{
    <#
    .SYNOPSIS
    Speichert eine VM ähnlich Export-VM. Export-VM ist natürlich vorzuziehen. Allerdings erwartet Export-VM
    auf einer Freigabe, das Hyper-V Computerkonto. Save-VM arbeitet mit den Rechten des aktuell angemeldeten
    Benutzer.
    .DESCRIPTION
    Speichert die Dateien einer VM in einen definierten Zielordner. Existiert der Ordner am
    definierten Ziel nicht, wird der Ordner erstellt. Durch Verwendung des Schalterparameter Override
    werden bereits existierende Dateien überschrieben.
    .PARAMETER Path
    Legt den Zielordner fest.
    .PARAMETER Name
    Der Name der zu sichernden VM
    .PARAMETER Override
    Durch Override werden ggf. vorhandene Dateien überschrieben
    .PARAMETER TurnOff
    Durch den Schalter TurnOff wird das Ausschalten der Machine erzwungen.
    Vorsicht: Hierbei kann es zu Datenverlusten kommen.
    .EXAMPLE
    Save-VM -VMName s2k12 -Path \\NAS\VMs\S2K12 -Override
    .NOTES
    .LINK
    #>

    param(
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [String] $Path,
        [Switch] $Override = $false,
        [Switch] $TurnOff = $false
    )

    $vm = Get-VM $Name -ErrorAction SilentlyContinue
    if($null -eq $vm)
    {
        Write-Error "Virtuelle Maschine nicht gefunden!"
        return
    }

    # VMState der virtuellen Maschine ermitteln
    $vmState = $vm.State
    
    # Files der Laufwerke ermitteln
    $hds = $vm.HardDrives
    $sources = $hds.Path

    foreach($vhdFile in $sources)
    {
        $result = Test-Path $path
        if($result -eq $false)
        {
            New-Item $path -ItemType Directory -ErrorAction SilentlyContinue
            $result = Test-Path $path
            if($result -eq $false)
            {
                Write-Error -Message "Der Zielpfad existiert nicht!"
                return
            }
        }
        
        # Ist das File der virtuellen Festplatte erreichbar?
        $result = Test-Path $vhdFile
        if($result -eq $false)
        {
            Write-Error -Message "$vhdFile nicht gefunden!"
        }

        # Vor dem Kopieren, wird geprüft, ob die Datei bereits existiert
        $items = $vhdFile.Split('\')
        $fileName = $items[$items.Length-1]
        $filePath = $path + '\' + $fileName

        $exist = Test-Path $filePath

        if($exist -eq $false -or $Override -eq $true)
        {
            # Wenn die virtuelle Maschine läuft, wird diese gestoppt
            if($vmState -ne "Off")
            {
                Write-Verbose "Es wird versucht, die virtuelle Maschine herunterzufahren."
                $result = Stop-VM -Name $Name -Confirm:$true
                if($null -eq $result)
                {
                    if($TurnOff -eq $true)
                    {
                         $null = Stop-VM -Name $Name -TurnOff
                    }
                }
                if((Get-VM $Name).State -ne "Off")
                {
                    Write-Error "Virtuelle Maschine konnte nicht heruntergefahren werden!"
                    return
                }
                else {
                    Write-Verbose "Virtuelle Maschine wurde heruntergefahren."
                }
            }

            Start-BitsTransfer -Source $vhdFile -Destination $path -Description $vhdFile -DisplayName "Backup"
        }
        elseif($exist -eq $true)
        {
            Write-Error "Datei wurde nicht kopiert da bereits eine Datei mit gleichem Namen am Speicherort vorhanden ist."
            Write-Verbose "$filePath bereits vorhanden. Verwenden sie den Schalter -Override um vorhandene Dateien zu überschreiben."
            return
        }
        
    }

    # Prüfung, ob ggf. Snapshots existieren
    $snapShots = Get-VMSnapshot -VMName $Name
    if($null -ne $snapShots)
    {
        Write-Verbose "Snapshots vorhanden."
        $snapShotHDs = $snapShots.HardDrives
        #$snapShotSources = $snapShots.Path     

        foreach ($snapShotSource in $snapShotHDs) 
        {
            $snapShotPath = $snapShotSource.Path
            $result = Test-Path $snapShotPath
            if($result -eq $false)
            {
                Write-Error -Message "$snapShotPath nicht gefunden!"
                break
            }
         
            # Vor dem Kopieren, wird geprüft, ob die Datei bereits existiert
            $items = $snapShotPath.Split('\')
            $fileName = $items[$items.Length-1]
            $filePath = $path + '\' + $fileName

            $exist = Test-Path $filePath

            if($exist -eq $false -or $Override -eq $true)
            {
                Write-Verbose "$snapShotPath wird kopiert."
                Start-BitsTransfer -Source $snapShotPath -Destination $path -Description $snapShotPath -DisplayName "Backup"   
            }
            elseif($exist -eq $true)
            {   
                Write-Verbose "$filePath bereits vorhanden. Verwenden sie den Schalter -Override um vorhandene Dateien zu überschreiben."
            }
            
        }        
    }

    finally {
        # Wenn die Maschine vor dem Sichern gelaufen ist, wird diese wieder gestartet
        if($vmState -eq "Running")
        {
            Write-Verbose "Die virtuelle Maschine wird gestartet."
            Start-VM -Name $vm.Name
        }
    }
}