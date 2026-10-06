<p align="center">
  <img src="assets/banner.png" alt="SSH-Tools Banner" width="720">
</p>

**Language / Sprache:** [English](README.en.md) · [Deutsch](README.md)

# SSH-Tools

**SSH-Tools** is an interactive menu tool that simplifies everyday SSH tasks: establishing connections, transferring files, installing and configuring servers, creating SSH keys and distributing them to remote systems.

The project consists of two scripts:

| Script | Platform | Description |
|---|---|---|
| `ssh-tools` | Linux (Bash) | Full feature set including SSHFS and Dropbear |
| `ssh-tools.ps1` | Windows (PowerShell) | Same core comfort, Windows-typical installation via WindowsCapability/winget |

Both scripts are purely interactive — just start them, pick a menu item, done. There are no configuration files and no dependencies beyond the programs listed below.

---

## Features on Linux (`ssh-tools`)

The Bash script installs the required packages locally, configures the SSH server if needed, and offers these menu items:

### 1) SSH connect (client: OpenSSH / Dropbear)
- Establishes an interactive SSH session — using either **OpenSSH (`ssh`)** or **Dropbear (`dbclient`)**.
- Asks once for username, host/IP and port and remembers the connection settings for the whole session (confirm reuse with `j` for yes).
- Existing settings are shown before every action and can be overwritten.

### 2) SSH file up/download (scp)
- Upload files and entire folders (`-r`) via **`scp`** (local → remote) or download them (remote → local).
- Uses the same remembered connection settings as the other functions.

### 3) SSHFS – mount remote filesystem (`~/tmp`)
- Mounts a directory of the remote system via **SSHFS** at `~/tmp`.
- After mounting, the directory stays mounted until you press Enter — then it is unmounted cleanly (`fusermount`/`fusermount3`/`umount` fallback chain).
- The mount is **unmounted automatically** when the script exits or is aborted with **Ctrl+C** — no orphaned mounts are ever left behind.

### 4) Install required packages (Arch / Ubuntu / Debian)
- Automatically detects the package manager (`pacman` or `apt-get`) and installs:
  - **OpenSSH** (client + server)
  - **Dropbear** (`dropbear` + `dropbear-bin`)
  - **SSHFS**
  - or combinations (OpenSSH + SSHFS, Dropbear + SSHFS)
- On Debian/Ubuntu the correct package names are used automatically (`openssh-client`/`openssh-server`, `dropbear-bin`).
- After installation it proceeds directly to the port configuration (see feature 5) and restarts the service.

### 5) Select/check SSH server (OpenSSH or Dropbear)
- Shows the state of both SSH servers: installed? service running? on which port?
- Reads the port automatically from `/etc/ssh/sshd_config` or `/etc/conf.d/dropbear` (Debian: `/etc/default/dropbear`).
- **Configure/start OpenSSH:** asks for the port, writes it into `sshd_config` **and** `ssh_config` (an existing `Port` line is replaced, otherwise the entry is inserted at the top), then enables and restarts the service (`sshd` on Arch, `ssh` on Debian/Ubuntu — detected automatically).
- **Configure/start Dropbear:** asks for the port, writes it into the Dropbear configuration and enables/starts the service.

### 6) Create/modify SSH key
- Creates new keys with **ed25519** (recommended), **RSA** or **ECDSA** via `ssh-keygen`.
- Free choice of path and file name; default is `~/.ssh/id_<type>`.
- If the key already exists, you can choose to:
  - **recreate** it completely (with a confirmation prompt), or
  - change only its **passphrase** (`ssh-keygen -p`).

### 7) Copy SSH key to remote system
- Uses **`ssh-copy-id`** to push a public key (`.pub`) to the remote host — no more password prompts afterwards.
- Default path is `~/.ssh/id_ed25519.pub`, any other path can be entered.

### Operation & comfort
- **`0`/`00` rule:** In every submenu `0` means *back* and `00` means *quit*.
- On exit, any existing SSHFS mount is always unmounted cleanly.
- **`-nc` / `--no-color`:** disable colored output (for old terminals or redirection); the **`NO_COLOR`** environment variable is respected as well.
- Color scheme: cyan = headings, yellow = prompts, red = errors/warnings, magenta = files/commands, green = status/success.

### Requirements (Linux)
- Bash, `sudo` rights for installation/configuration
- Depending on the feature: `openssh`, `dropbear`/`dropbear-bin`, `sshfs`
- Supported package managers: **pacman** (Arch) and **apt-get** (Debian/Ubuntu)

### Getting started (Linux)
```bash
chmod +x ssh-tools
./ssh-tools          # with colors
./ssh-tools --no-color   # without colors
```

---

## Features on Windows (`ssh-tools.ps1`)

The PowerShell script offers the same core comfort; SSHFS is not included on Windows, but instead you get the typical Windows installation methods.

### 1) SSH connect
- Establishes an interactive SSH session with the Windows OpenSSH client.
- Asks for username, host/IP and port (default 22) and remembers the settings for the session.
- If `ssh.exe` is missing, the OpenSSH installation (menu item 3) is offered directly.

### 2) File transfer (scp)
- Upload and download of files/folders via `scp` (always recursive).
- Checks local paths before transferring and displays the executed SCP command as well as its exit code.
- Uses the same remembered connection settings.

### 3) Install OpenSSH (PowerShell / winget)
Three installation methods:
- **PowerShell WindowsCapability** (`Add-WindowsCapability -Online`) — the classic, stable way; checks the installation state first and installs the client, the server or both.
- **winget stable** (`Microsoft.OpenSSH` / `Microsoft.OpenSSH.Server`)
- **winget preview/beta** (`Microsoft.OpenSSH.Beta` / `Microsoft.OpenSSH.Beta.Server`)

Depending on the method you can install only the client, only the server, or both; already installed components are detected and skipped.

### 4) Create SSH key
- Creates keys with **ed25519**, **RSA** or **ECDSA** via `ssh-keygen`.
- Default location: `%USERPROFILE%\.ssh\id_<type>` (folder is created if needed).
- If the key already exists: recreate it or change only the passphrase.

### 5) Copy key to remote
- Transfers the public key to the remote host (on Linux hosts via an `ssh` command appending to `~/.ssh/authorized_keys` incl. correct permissions `700`/`600`) — passwordless login afterwards.
- Default path: `%USERPROFILE%\.ssh\id_ed25519.pub`.

### Operation & comfort (Windows)
- **`-Help` / `-h`:** shows the detailed help (`Get-Help -Detailed`) without starting the menu.
- VT color output is enabled automatically (ENABLE_VIRTUAL_TERMINAL_PROCESSING); if that fails (legacy console, redirection), the script falls back to colorless output — raw escape characters are never printed.
- Same color language as the Linux version.

### Requirements (Windows)
- PowerShell 5.1 or 7+ (Windows PowerShell or PowerShell Core)
- For installation: admin rights plus WindowsCapability or winget availability
- For ssh/scp/ssh-keygen: OpenSSH client (installed on demand via menu item 3)

### Getting started (Windows)
```powershell
Set-ExecutionPolicy -Scope Process Bypass   # if necessary
.\ssh-tools.ps1
.\ssh-tools.ps1 -Help
```

---

## Screenshots

### Linux (Bash)
<p align="center">
  <img src="assets/screenshot-linux-main.png" alt="Linux main menu" width="720">
</p>
<p align="center">
  <img src="assets/screenshot-linux-install.png" alt="Linux package installation" width="720">
</p>
<p align="center">
  <img src="assets/screenshot-linux-key.png" alt="Linux SSH key menu" width="720">
</p>

### Windows (PowerShell)
<p align="center">
  <img src="assets/screenshot-windows-main.png" alt="Windows main menu" width="720">
</p>
<p align="center">
  <img src="assets/screenshot-windows-install.png" alt="Windows OpenSSH installation" width="720">
</p>

---

## License

This project is licensed under the **GNU General Public License v3.0** — see [LICENSE](LICENSE).
