# Spin Matrix

This matrix is the working package plan for Demian and Demuntu spins. It keeps
default image contents separate from optional installer/first-login package
sets.

## Buckets

| Bucket | Purpose | Delivery |
| --- | --- | --- |
| `server-core` | Lightweight installed server baseline | server metapackages |
| `desktop-core` | Lightweight XFCE desktop baseline | desktop metapackages |
| `live-tools` | Rescue and live-session diagnostics | rescue/live metapackages |
| `developer` | Larger language/toolchain bundles | package-set selector |

Bucket notes live in `configs/package-buckets/*.packages`. Package-set options
live in `configs/package-sets/*.packages` and are installed by the server
installer selector or the desktop welcome selector.

## Current Spins

| Spin | Family | Base | Default Buckets | Optional Sets |
| --- | --- | --- | --- | --- |
| `demian-server-live` | Debian 13 | live-build | `server-core` | none |
| `demian-desktop-live` | Debian 13 | live-build | `desktop-core` | `node-developer`, `python-developer`, `dotnet-developer`, `git-gui-tools`, `docker-gui-tools` |
| `demian-rescue-live` | Debian 13 | live-build | `server-core`, `live-tools` | none |
| `demuntu-server-autoinstall` | Ubuntu 26.04 LTS | Subiquity autoinstall | `server-core` | `node-developer`, `python-developer`, `dotnet-developer`, `git-gui-tools`, `docker-gui-tools` |
| `demuntu-desktop-live` | Ubuntu 26.04 LTS | Ubuntu desktop ISO remaster | `desktop-core` | `node-developer`, `python-developer`, `dotnet-developer`, `git-gui-tools`, `docker-gui-tools` |

## Server Core

Server Core should stay small, scriptable, and useful immediately after boot:

- SSH access and guest integration
- basic network, file, and process inspection
- firewall and login hardening hooks
- unattended security updates
- terminal comfort tools

Current representative packages:

```text
openssh-server
curl
vim-tiny
tmux
htop
rsync
ufw
fail2ban
unattended-upgrades
qemu-guest-agent
```

## Desktop Core

Desktop Core should remain a practical XFCE workstation, not a heavy showcase:

- XFCE session, terminal, file manager, display manager
- Vivaldi browser
- VLC media player
- archive tools
- audio controls and PipeWire where available
- Wi-Fi, Bluetooth, firmware, and removable-device desktop tools
- branded welcome/setup app and selector flow

Current representative packages:

```text
xfce4 or task-xfce-desktop
lightdm
vivaldi-stable
vlc
thunar
xfce4-terminal
xarchiver
pavucontrol
pipewire
python3-tk
pkexec
network-manager
network-manager-gnome
ubuntu-drivers-common
software-properties-gtk
linux-firmware
firmware-sof-signed
wpasupplicant
iw
wireless-regdb
bluez
blueman
pipewire-pulse
wireplumber
alsa-utils
fwupd
gnome-disk-utility
udisks2
upower
```

Demuntu Desktop strips bulky upstream desktop defaults from the Ubuntu desktop
base before adding its own defaults: LibreOffice, Rhythmbox, Totem/Video
Player, Firefox, Thunderbird, Transmission, and Shotwell.

## Live Tools

Live Tools are for repair, diagnostics, and data movement:

- partitioning and filesystem inspection
- disk health and NVMe/SATA tools
- network diagnostics
- process tracing and recovery utilities

Current representative packages:

```text
gparted
parted
gdisk
testdisk
smartmontools
nvme-cli
lvm2
mdadm
nmap
tcpdump
gddrescue
```

## Developer

Developer tooling remains optional because it pulls from third-party repos and
adds significant install time and image surface area.

Current package sets:

- `node-developer`: NodeSource Node.js/npm, VS Code, Git, build tools, Docker CE
- `python-developer`: Python 3, pip, venv, pipx, Git, build tools, SQLite, jq, direnv
- `dotnet-developer`: .NET 10 SDK, ASP.NET Core runtime, Git, build tools, JetBrains Rider best-effort install
- `git-gui-tools`: Git Cola, git-gui, gitk, Meld, GitKraken best-effort install
- `docker-gui-tools`: Docker Engine, lazydocker, Portainer CE local web UI service

## Promotion Rule

Move a package from optional sets into a default bucket only when most users of
that spin should get it on every install. Keep large toolchains, IDEs,
containers, language runtimes, and role-specific services as selectable sets
until a dedicated spin needs them by default.
