# Package Sets

Package sets are optional install-time bundles for Demian and Demuntu spins.
They are separate from base metapackages: metapackages define what every image
of a spin includes, while package sets let an installer choose extra tools for a
specific machine.

## Layout

Package-set files currently live in:

```text
configs/package-sets/              Human-readable package set lists
scripts/package-sets/install.sh    Target-system dispatcher
scripts/package-sets/install-from-cmdline.sh
                                    Autoinstall bridge from kernel cmdline
scripts/package-sets/select.sh     Installer-stage package-set selector
scripts/package-sets/sets/*.sh     Per-set installers
packages/meta/demuntu-meta/branding/usr/lib/demuntu/demuntu-welcome
packages/meta/demian-meta/branding/usr/lib/demian/demian-welcome
                                    First-login GUI and CLI selectors
```

The Demuntu Server autoinstall builder copies this tree into the ISO at:

```text
/demuntu/package-sets
```

The `demuntu-branding` package also installs the same package-set tree into:

```text
/usr/lib/demuntu/package-sets
```

This lets an installed system run the selector after first boot.

During Subiquity late-commands, `install-from-cmdline.sh` reads
`demuntu.package_sets` from `/proc/cmdline`. If the value is empty or `none`,
no optional sets are installed. Otherwise the payload is copied into `/target`
and run through `curtin in-target`.

The late-command bridge writes progress markers to both serial and the target
log file:

```text
/var/log/demuntu-package-sets.log
DEMUNTU_PACKAGE_SETS: requested ...
DEMUNTU_PACKAGE_SETS: installing ...
DEMUNTU_PACKAGE_SETS: completed ...
```

When `demuntu.package_sets=ask`, late-commands run `select.sh` before entering
the target. The selector reads `configs/package-sets/catalog.tsv` and presents
available package sets during installation. The GRUB entry starts the selector,
but the package-set choice itself happens inside the installer flow.

## Selection Paths

The current Demuntu Server ISO exposes:

```text
Autoinstall Demuntu Server
Autoinstall Demuntu Server (choose package sets)
Autoinstall Demuntu Server (Node Developer automation)
Autoinstall Demuntu Server (Python Developer automation)
Autoinstall Demuntu Server (.NET Developer automation)
Autoinstall Demuntu Server (Git GUI Tools automation)
Autoinstall Demuntu Server (Docker GUI Tools automation)
```

The default entry installs no optional package sets. The "choose package sets"
entry adds this kernel parameter:

```text
demuntu.package_sets=ask
```

Automation entries pass package-set ids directly for repeatable QEMU tests:

```text
demuntu.package_sets=node-developer
demuntu.package_sets=python-developer
demuntu.package_sets=dotnet-developer
demuntu.package_sets=git-gui-tools
demuntu.package_sets=docker-gui-tools
```

Multiple explicit sets can be combined with commas:

```text
demuntu.package_sets=node-developer,python-developer,dotnet-developer,git-gui-tools,docker-gui-tools
```

Demian Desktop and Demuntu Desktop also autostart their welcome apps on first
login: `demian-welcome` and `demuntu-welcome`. Each is a bundled Python/Tk
setup app that combines the old welcome text, installer launcher, system
package summary, and package-set selector. Package-set installs run through the
same family-local dispatcher via `pkexec` when a non-root desktop user chooses
to install.

The welcome selector can also be run manually:

```sh
demian-welcome
demian-welcome --cli
sudo /usr/lib/demian/package-sets/install.sh node-developer
sudo /usr/lib/demian/package-sets/install.sh python-developer
sudo /usr/lib/demian/package-sets/install.sh dotnet-developer
sudo /usr/lib/demian/package-sets/install.sh git-gui-tools
sudo /usr/lib/demian/package-sets/install.sh docker-gui-tools

demuntu-welcome
demuntu-welcome --cli
sudo /usr/lib/demuntu/package-sets/install.sh node-developer
sudo /usr/lib/demuntu/package-sets/install.sh python-developer
sudo /usr/lib/demuntu/package-sets/install.sh dotnet-developer
sudo /usr/lib/demuntu/package-sets/install.sh git-gui-tools
sudo /usr/lib/demuntu/package-sets/install.sh docker-gui-tools
```

The first-run autostart writes `~/.config/<family>/welcome-seen` when the user
skips or successfully installs a selected set. The "Remind Me Later" button
closes the window without writing that state file.

## Node Developer

Set id:

```text
node-developer
```

Functional package request:

```text
nodejs
npm
vscode
git
build-essential
docker-ce
```

Concrete apt packages:

```text
nodejs
code
git
build-essential
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

`npm` is provided by the NodeSource `nodejs` package, so the distro `npm`
package is not installed separately.

When installed through the autoinstall path, this set also enables
`demuntu-node-developer-ready.service`. On the first installed-system boot it
waits for cloud-init, prints labeled package version checks to serial, and ends
with:

```text
DEMUNTU_NODE_DEVELOPER_READY
```

External repositories:

- NodeSource Node.js 24.x: `https://deb.nodesource.com/node_24.x`
- Visual Studio Code: `https://packages.microsoft.com/repos/code`
- Docker CE: `https://download.docker.com/linux/ubuntu`

Repo setup mirrors the current official deb822/source-list guidance:

- NodeSource setup script: `https://deb.nodesource.com/setup_24.x`
- VS Code Linux docs: `https://code.visualstudio.com/docs/setup/linux`
- Docker Engine Ubuntu docs: `https://docs.docker.com/engine/install/ubuntu/`

## Python Developer

Set id:

```text
python-developer
```

Functional package request:

```text
python3
python3-pip
python3-venv
pipx
git
build-essential
sqlite3
jq
direnv
```

Concrete apt packages:

```text
python3
python3-dev
python3-pip
python3-venv
pipx
git
build-essential
sqlite3
jq
direnv
```

When installed through the autoinstall path, this set enables
`demuntu-python-developer-ready.service`. On the first installed-system boot it
waits for cloud-init, prints labeled package version checks to serial, and ends
with:

```text
DEMUNTU_PYTHON_DEVELOPER_READY
```

## .NET Developer

Set id:

```text
dotnet-developer
```

Functional package request:

```text
latest .NET SDK
JetBrains Rider, where possible
git
build-essential
```

Concrete package-managed core:

```text
dotnet-sdk-10.0
aspnetcore-runtime-10.0
git
build-essential
```

The installer first uses the available distro or Microsoft APT feed for
`dotnet-sdk-10.0`. On Debian 13, Microsoft documents Debian support for .NET
10, 9, and 8 and installs the SDK with `dotnet-sdk-10.0`. On current Ubuntu
releases, Microsoft documents .NET availability through Ubuntu feeds rather
than the Microsoft feed. If no APT package is available, the package set falls
back to Microsoft's `dotnet-install.sh` for channel `10.0`.

Rider is installed best-effort from JetBrains' latest stable Linux tarball into
`/opt/jetbrains/rider` with `/usr/local/bin/rider` and a desktop entry. Rider
is not pre-licensed; JetBrains provides Rider free for non-commercial use, and
the user signs in on first launch to select the appropriate license. Commercial
use still requires a paid JetBrains license.

When installed through the autoinstall path, this set enables
`demuntu-dotnet-developer-ready.service`. On the first installed-system boot it
waits for cloud-init, prints labeled package version checks to serial, and ends
with:

```text
DEMUNTU_DOTNET_DEVELOPER_READY
```

The latest QEMU autoinstall gate validated .NET SDK `10.0.108`, Git `2.53.0`,
GCC `15.2.0`, and a Rider launcher at
`/opt/jetbrains/rider/bin/rider.sh`.

External install references:

- Microsoft .NET on Debian: `https://learn.microsoft.com/en-us/dotnet/core/install/linux-debian`
- Microsoft .NET on Ubuntu: `https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu`
- JetBrains Rider Linux install: `https://www.jetbrains.com/help/rider/Installation_guide.html`

## Git GUI Tools

Set id:

```text
git-gui-tools
```

Functional package request:

```text
git GUI tools
GitKraken, as a temporary preferred proprietary option
```

Concrete package-managed baseline:

```text
git
git-cola
git-gui
gitk
meld
xdg-utils
```

GitKraken Desktop is installed best-effort on `amd64` from GitKraken's active
Linux tarball channel into `/opt/gitkraken`:

```text
https://api.gitkraken.dev/releases/production/linux/x64/active/gitkraken-amd64.tar.gz
```

The open-source tools remain the dependable baseline if GitKraken download or
package installation fails. GitKraken is proprietary and may require a
GitKraken account/license depending on repository type and use case.

When installed through the autoinstall path, this set enables
`demuntu-git-gui-tools-ready.service`. On first installed-system boot it checks
the Git version and launcher paths, then ends with:

```text
DEMUNTU_GIT_GUI_TOOLS_READY
```

## Docker GUI Tools

Set id:

```text
docker-gui-tools
```

Functional package request:

```text
Docker GUI/management tools
```

Concrete package-managed core:

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

The set adds Docker's official apt repository for Debian or Ubuntu, installs
Docker Engine, installs the latest lazydocker release from GitHub where a
matching Linux binary asset exists, and enables a `demuntu-portainer.service`
unit for Portainer CE.

Portainer CE is exposed locally at:

```text
https://localhost:9443
```

The service uses:

```text
portainer/portainer-ce:lts
```

Docker Desktop remains a candidate for a future workstation-only payload. It is
not included here because its licensing and desktop integration assumptions are
heavier than Portainer CE or lazydocker.

When installed through the autoinstall path, this set enables
`demuntu-docker-gui-tools-ready.service`. On first installed-system boot it
checks Docker, lazydocker if installed, and Portainer service enablement, then
ends with:

```text
DEMUNTU_DOCKER_GUI_TOOLS_READY
```

## Adding A Set

1. Add a package list or note in `configs/package-sets/<set-id>.packages`.
2. Add the set id, display name, and summary to
   `configs/package-sets/catalog.tsv`.
3. Add an executable installer at
   `scripts/package-sets/sets/<set-id>.sh`.
4. Rebuild the relevant ISO so the payload is copied into
   `/demuntu/package-sets`.
5. Add a repeatable install target when the set has packages that should be
   validated in QEMU.

Keep set ids limited to letters, numbers, underscores, and hyphens.
