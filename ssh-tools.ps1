<#
.SYNOPSIS
SSH-Helper fuer Windows PowerShell (ohne SSHFS-Funktionen).

.DESCRIPTION
Interaktives Menue-Werkzeug: SSH-Verbindung aufbauen, Datei-Transfer per
scp, OpenSSH-Client/Server nachinstallieren (WindowsCapability oder
winget), SSH-Keys erstellen und Pubkeys auf Remote-Hosts uebertragen.
Farbausgabe nach DESIGN.md (ANSI-Farbkonstanten); bei fehlender
VT-Unterstuetzung wird automatisch farblos ausgegeben.

.PARAMETER Help
Zeigt die Hilfe des Skripts an (Get-Help -Detailed).

.EXAMPLE
.\ssh-tools.ps1
Startet das interaktive Menue.

.EXAMPLE
.\ssh-tools.ps1 -Help
Zeigt die Hilfe an, ohne das Menue zu starten.
#>

[CmdletBinding()]
param(
    [Alias('h')]
    [switch] $Help
)

if ($Help) {
    Get-Help -Name $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# --- Farbkonstanten (DESIGN.md, kompatibel mit PS 5.1 und 7+) ---
$ESC       = [char]0x1B
$CYAN_H    = "$ESC[1;96m"   # Hell Cyan  - Ueberschriften
$YELLOW_H  = "$ESC[1;93m"   # Hell Gelb  - normaler Text
$RED_H     = "$ESC[1;91m"   # Hell Rot   - Warnung/Fehler
$MAGENTA_L = "$ESC[1;35m"   # Hell Lila  - Datei/Befehl
$GREEN_O   = "$ESC[1;92m"   # Hell Gruen - alles andere
$RESET     = "$ESC[0m"      # Reset

# --- VT-Verarbeitung aktivieren (DESIGN.md) mit Farb-Fallback ---
# Setzt ENABLE_VIRTUAL_TERMINAL_PROCESSING (Bit 4) und liest den Bit zur
# Kontrolle zurueck; schlaegt das fehl (keine Konsole, Umleitung, sehr
# alter Host), werden alle Farbvariablen geleert: Ausgabe schlicht,
# aber niemals rohe ESC-Zeichen.
try {
    $k32 = Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);' -Name K32Ps -PassThru -ErrorAction Stop
    $hOut = $k32::GetStdHandle(-11)
    $m = 0
    if (-not $k32::GetConsoleMode($hOut, [ref]$m)) { throw }
    if (-not $k32::SetConsoleMode($hOut, $m -bor 4)) { throw }
    $m2 = 0
    if (-not $k32::GetConsoleMode($hOut, [ref]$m2)) { throw }
    if (($m2 -band 4) -ne 4) { throw }
} catch {
    $CYAN_H    = ""
    $YELLOW_H  = ""
    $RED_H     = ""
    $MAGENTA_L = ""
    $GREEN_O   = ""
    $RESET     = ""
}

$global:SessionUser = ""
$global:SessionHost = ""
$global:SessionPort = 22
$global:SessionSet  = $false

function Pause-Enter { Read-Host "Weiter mit Enter..." }

function Read-CredentialsInteractive {
    if ($global:SessionSet) {
        Write-Host "${YELLOW_H}Aktuelle Verbindungseinstellungen:${RESET}"
        Write-Host "${YELLOW_H}  Benutzer: ${MAGENTA_L}$($global:SessionUser)${RESET}"
        Write-Host "${YELLOW_H}  Host/IP : ${MAGENTA_L}$($global:SessionHost)${RESET}"
        Write-Host "${YELLOW_H}  Port    : ${MAGENTA_L}$($global:SessionPort)${RESET}"
        $reuse = Read-Host "Diese Einstellungen weiter benutzen? (j/N)"
        if ($reuse -eq "j" -or $reuse -eq "J") { return }
    }
    $global:SessionUser = Read-Host "Benutzername"
    $global:SessionHost = Read-Host "Host/IP"
    $port = Read-Host "Port (Enter fuer 22)"
    $global:SessionPort = if ([string]::IsNullOrWhiteSpace($port)) { 22 } else { [int]$port }
    $global:SessionSet = $true
}

function Test-Program {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Connect-Ssh {
    if (-not (Test-Program "ssh")) {
        Write-Host "${RED_H}ssh.exe fehlt! OpenSSH installieren...${RESET}"
        Install-OpenSSHComponents
        return
    }
    Read-CredentialsInteractive
    ssh -p $global:SessionPort "$($global:SessionUser)@$($global:SessionHost)"
    After-ConnectionMenu
}

function Invoke-Scp {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$Recursive
    )

    $scpArgs = @("-P", $global:SessionPort.ToString())
    if ($Recursive) { $scpArgs += "-r" }
    $scpArgs += $Source, $Destination

    Write-Host "${MAGENTA_L}SCP-Befehl: scp $($scpArgs -join ' ')${RESET}"

    $scpProcess = Start-Process -FilePath "scp" -ArgumentList $scpArgs -NoNewWindow -PassThru -Wait
    if ($scpProcess.ExitCode -ne 0) {
        Write-Host "${RED_H}SCP fehlgeschlagen mit Exit-Code: $($scpProcess.ExitCode)${RESET}"
    }
}

function Transfer-File {
    if (-not (Test-Program "scp")) {
        Write-Host "${RED_H}scp.exe fehlt! OpenSSH installieren...${RESET}"
        Install-OpenSSHComponents
        return
    }
    Read-CredentialsInteractive

    Write-Host "${CYAN_H}1) HOCHladen  2) HERUNTERladen${RESET}"
    $mode = Read-Host "Auswahl"

    switch ($mode) {
        "1" {
            $local  = Read-Host "Lokale Datei/Ordner (z.B. C:\Pfad\datei.txt)"
            $remote = Read-Host "Remote-Pfad (z.B. /home/user/)"

            if (-not (Test-Path $local)) {
                Write-Host "${RED_H}Lokaler Pfad nicht gefunden: $local${RESET}"
                Pause-Enter
                return
            }

            $localArg  = "`"$local`""
            $remoteArg = "$($global:SessionUser)@$($global:SessionHost):$remote"

            Invoke-Scp -Source $localArg -Destination $remoteArg -Recursive
        }
        "2" {
            $remote = Read-Host "Remote-Pfad (z.B. /home/user/datei.txt)"
            $local  = Read-Host "Lokaler Ordner (z.B. C:\Zielordner)"
            $remoteArg = "$($global:SessionUser)@$($global:SessionHost):$remote"
            $localArg  = "`"$local`""

            Invoke-Scp -Source $remoteArg -Destination $localArg -Recursive
        }
        default {
            Write-Host "${RED_H}Ungueltige Auswahl.${RESET}"
        }
    }
    After-ConnectionMenu
}

function Install-OpenSSHWinget {
    param([string]$Component, [string]$Edition)

    $clientId = if ($Edition -eq "preview") { "Microsoft.OpenSSH.Beta" } else { "Microsoft.OpenSSH" }
    $serverId = if ($Edition -eq "preview") { "Microsoft.OpenSSH.Beta.Server" } else { "Microsoft.OpenSSH.Server" }

    if (-not (Test-Program "winget")) {
        Write-Host "${RED_H}winget nicht gefunden. Bitte manuell installieren.${RESET}"
        Pause-Enter
        return $false
    }

    switch ($Component) {
        "client" {
            Write-Host "${YELLOW_H}Installiere OpenSSH Client $Edition mit winget...${RESET}"
            & winget install --id $clientId --accept-package-agreements --accept-source-agreements --silent
        }
        "server" {
            Write-Host "${YELLOW_H}Installiere OpenSSH Server $Edition mit winget...${RESET}"
            & winget install --id $serverId --accept-package-agreements --accept-source-agreements --silent
        }
        "both" {
            Write-Host "${YELLOW_H}Installiere OpenSSH Client $Edition mit winget...${RESET}"
            & winget install --id $clientId --accept-package-agreements --accept-source-agreements --silent
            Write-Host "${YELLOW_H}Installiere OpenSSH Server $Edition mit winget...${RESET}"
            & winget install --id $serverId --accept-package-agreements --accept-source-agreements --silent
        }
    }
    Write-Host "${GREEN_O}winget Installation abgeschlossen.${RESET}"
    return $true
}

function Install-OpenSSHComponents {
    Write-Host "${CYAN_H}=== OpenSSH Installation ===${RESET}"

    Write-Host "${YELLOW_H}1) PowerShell WindowsCapability (stable)${RESET}"
    Write-Host "${YELLOW_H}2) winget stable${RESET}"
    Write-Host "${YELLOW_H}3) winget preview/beta${RESET}"
    Write-Host "${YELLOW_H}0) Zurueck${RESET}"
    $method = Read-Host "Installationsmethode"

    if ($method -eq "0") { return }

    Write-Host "${YELLOW_H}`nWas installieren?${RESET}"
    Write-Host "${YELLOW_H}1) Nur Client${RESET}"
    Write-Host "${YELLOW_H}2) Nur Server${RESET}"
    Write-Host "${YELLOW_H}3) Client und Server${RESET}"
    Write-Host "${YELLOW_H}0) Abbruch${RESET}"
    $choice = Read-Host "Auswahl"

    switch ($method) {
        "1" {
            # PowerShell WindowsCapability (stable)
            $clientCap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
            $serverCap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

            switch ($choice) {
                "1" {
                    if ($clientCap.State -ne 'Installed') {
                        Add-WindowsCapability -Online -Name $clientCap.Name
                        Write-Host "${GREEN_O}OpenSSH-Client installiert.${RESET}"
                    } else {
                        Write-Host "${GREEN_O}OpenSSH-Client bereits installiert.${RESET}"
                    }
                }
                "2" {
                    if ($serverCap.State -ne 'Installed') {
                        Add-WindowsCapability -Online -Name $serverCap.Name
                        Write-Host "${GREEN_O}OpenSSH-Server installiert.${RESET}"
                        Write-Host "${MAGENTA_L}Dienst starten: Start-Service sshd${RESET}"
                    } else {
                        Write-Host "${GREEN_O}OpenSSH-Server bereits installiert.${RESET}"
                    }
                }
                "3" {
                    if ($clientCap.State -ne 'Installed') {
                        Add-WindowsCapability -Online -Name $clientCap.Name
                        Write-Host "${GREEN_O}OpenSSH-Client installiert.${RESET}"
                    } else {
                        Write-Host "${GREEN_O}OpenSSH-Client bereits installiert.${RESET}"
                    }
                    if ($serverCap.State -ne 'Installed') {
                        Add-WindowsCapability -Online -Name $serverCap.Name
                        Write-Host "${GREEN_O}OpenSSH-Server installiert.${RESET}"
                        Write-Host "${MAGENTA_L}Dienst starten: Start-Service sshd${RESET}"
                    } else {
                        Write-Host "${GREEN_O}OpenSSH-Server bereits installiert.${RESET}"
                    }
                }
            }
        }
        "2" {
            # winget stable
            Install-OpenSSHWinget -Component $choice -Edition "stable"
        }
        "3" {
            # winget preview
            Install-OpenSSHWinget -Component $choice -Edition "preview"
        }
    }

    Write-Host "${GREEN_O}Installation abgeschlossen. Neustart PowerShell empfohlen!${RESET}"
    Pause-Enter
}

function New-SshKey {
    if (-not (Test-Program "ssh-keygen")) {
        Write-Host "${RED_H}ssh-keygen fehlt!${RESET}"
        Install-OpenSSHComponents
        return
    }
    Write-Host "${CYAN_H}1)ed25519  2)rsa  3)ecdsa${RESET}"
    $choice = Read-Host "Typ (Enter=1)"
    $type = switch ($choice) {
        "2" { "rsa" }
        "3" { "ecdsa" }
        default { "ed25519" }
    }

    $sshDir = "$env:USERPROFILE\.ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    $path = Read-Host "Pfad (Enter: $sshDir\id_$type)"
    if (-not $path) { $path = "$sshDir\id_$type" }

    if (Test-Path $path) {
        Write-Host "${CYAN_H}1)NEU  2)Passphrase  0)Abbruch${RESET}"
        $opt = Read-Host "Auswahl"
        switch ($opt) {
            "1" { & ssh-keygen -t $type -f $path }
            "2" { & ssh-keygen -p -f $path }
            default { return }
        }
    } else {
        & ssh-keygen -t $type -f $path
    }
    Write-Host "${GREEN_O}Fertig: $($path).pub${RESET}"
    Pause-Enter
}

function Copy-KeyRemote {
    Read-CredentialsInteractive
    $defaultPub = "$env:USERPROFILE\.ssh\id_ed25519.pub"
    $pubkey = Read-Host "Pubkey (Enter: $defaultPub)"
    if (-not $pubkey) { $pubkey = $defaultPub }
    if (-not (Test-Path $pubkey)) {
        Write-Host "${RED_H}Pubkey nicht gefunden!${RESET}"
        Pause-Enter
        return
    }

    $keyContent = Get-Content $pubkey -Raw
    $remoteCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$keyContent' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    ssh -p $global:SessionPort "$($global:SessionUser)@$($global:SessionHost)" $remoteCmd
    Write-Host "${GREEN_O}Key uebertragen!${RESET}"
    Pause-Enter
}

function After-ConnectionMenu {
    Write-Host "${CYAN_H}`n1)Weiter  2)Beenden${RESET}"
    $again = Read-Host "Auswahl"
    if ($again -eq "1") { Main-Menu }
    else { exit }
}

function Main-Menu {
    while ($true) {
        Clear-Host
        Write-Host "${CYAN_H}==== SSH-Helper Windows ====${RESET}"
        Write-Host "${GREEN_O}1)${RESET} ${YELLOW_H}SSH verbinden${RESET}"
        Write-Host "${GREEN_O}2)${RESET} ${YELLOW_H}Datei-Transfer (scp)${RESET}"
        Write-Host "${GREEN_O}3)${RESET} ${YELLOW_H}OpenSSH installieren (PowerShell/winget)${RESET}"
        Write-Host "${GREEN_O}4)${RESET} ${YELLOW_H}SSH-Key erstellen${RESET}"
        Write-Host "${GREEN_O}5)${RESET} ${YELLOW_H}Key zu Remote kopieren${RESET}"
        Write-Host "${GREEN_O}0)${RESET} ${YELLOW_H}Beenden${RESET}"
        Write-Host ""

        switch ((Read-Host "Auswahl").Trim()) {
            "1" { Connect-Ssh }
            "2" { Transfer-File }
            "3" { Install-OpenSSHComponents }
            "4" { New-SshKey }
            "5" { Copy-KeyRemote }
            "0" { exit }
            default { Write-Host "${RED_H}Falsche Eingabe!${RESET}"; Start-Sleep 1 }
        }
    }
}

Write-Host "${GREEN_O}SSH-Helper gestartet!${RESET}"
Main-Menu
