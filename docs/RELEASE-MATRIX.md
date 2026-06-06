# Release Matrix

This file records the current baseline releases and artifact gates before larger
Demian and Demuntu customization work.

Generated artifacts are tracked in `dist/manifest.json`. The manifest stores
the same profile ids, ISO paths, hashes, and serial-marker test results in a
machine-readable form.

## Baseline Releases

| Family | Base | Codename | Source |
| --- | --- | --- | --- |
| Demian | Debian 13 | trixie | `deb.debian.org` via `live-build` |
| Demuntu | Ubuntu 26.04 LTS | resolute | official Ubuntu server and desktop ISOs |

## Upstream Base Media

| Profile | Base ISO |
| --- | --- |
| `demuntu-server-autoinstall` | `dist/downloads/ubuntu-26.04-live-server-amd64.iso` |
| `demuntu-desktop-live` | `dist/downloads/ubuntu-26.04-desktop-amd64.iso` |
| `demuntu-desktop-mate-live` | `dist/downloads/ubuntu-26.04-desktop-amd64.iso` |

Ubuntu base media is fetched and verified with:

```sh
./scripts/common/fetch-iso.sh ubuntu-26.04-lts-live-server-amd64
./scripts/common/fetch-iso.sh ubuntu-26.04-lts-desktop-amd64
```

## Current Artifacts

| Profile | ISO | SHA256 | Test marker |
| --- | --- | --- | --- |
| `demian-server-live` | `dist/images/demian-server-live-trixie-amd64.iso` | `c6fec2ea5561dc69c4bbdf397aac945764a439a248ccd32d776087207d70dbaf` | `DEMIAN_SERVER_READY` |
| `demian-desktop-live` | `dist/images/demian-desktop-live-trixie-amd64.iso` | `8f8ff7795330696143301013263bc14aa93693f1c549ba61d81f566c1a15f431` | `DEMIAN_DESKTOP_READY` |
| `demian-rescue-live` | `dist/images/demian-rescue-live-trixie-amd64.iso` | `112ccc8e2d671c3f37ce147b8f67a0c9ece5252abeea73405ec86ce77ca7454a` | `DEMIAN_RESCUE_READY` |
| `demuntu-server-autoinstall` | `dist/images/demuntu-server-autoinstall.iso` | `2bdec23528e295e06ea633a6f0eae3374747bee08a674bdfff802182b1220f20` | `DEMUNTU_INSTALL_READY` |
| `demuntu-desktop-live` | `dist/images/demuntu-desktop-live.iso` | `9a26c7581d694114b11e86a26dab9e4bb0e84a09718bd3c050c753b25ea66974` | `DEMUNTU_DESKTOP_READY` |
| `demuntu-desktop-mate-live` | `dist/images/demuntu-desktop-mate-live.iso` | `8900d3b4615856116e5755dc67f41868016c1c6e5073ebb29112d60e637406e3` | `DEMUNTU_MATE_DESKTOP_READY` |

## Validation Gates

Run profile and manifest validation:

```sh
make profiles
make manifest
```

Run all current headless smoke tests:

```sh
BUILD_ROOT=/root/demuntu-build make \
  demian-server-live-test \
  demian-desktop-live-test \
  demian-rescue-live-test \
  demuntu-desktop-live-test \
  demuntu-desktop-mate-live-test
```

Run the full Demuntu server autoinstall and installed-system boot test:

```sh
BUILD_ROOT=/root/demuntu-build make demuntu-server-autoinstall-install
```

Run the Node Developer selected package-set install and installed-system checks:

```sh
BUILD_ROOT=/root/demuntu-build make demuntu-server-node-developer-install
```

Run the Python Developer selected package-set install and installed-system
checks:

```sh
BUILD_ROOT=/root/demuntu-build make demuntu-server-python-developer-install
```

Run the .NET Developer selected package-set install and installed-system
checks:

```sh
BUILD_ROOT=/root/demuntu-build make demuntu-server-dotnet-developer-install
```

Run the Git GUI Tools selected package-set install and installed-system checks:

```sh
BUILD_ROOT=/root/demuntu-build make demuntu-server-git-gui-tools-install
```

Run the Docker GUI Tools selected package-set install and installed-system
checks:

```sh
BUILD_ROOT=/root/demuntu-build make demuntu-server-docker-gui-tools-install
```

The latest passing .NET Developer gate emitted:

- `DEMUNTU_PACKAGE_SETS: requested dotnet-developer`
- `DEMUNTU_PACKAGE_SETS: installing dotnet-developer`
- `DEMUNTU_PACKAGE_SETS: completed dotnet-developer`

The installed-system boot check validated:

- `dotnet: 10.0.108`
- `dotnet-sdks: 10.0.108 [/usr/lib/dotnet/sdk]`
- `git: git version 2.53.0`
- `gcc: gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0`
- `rider-launcher: /opt/jetbrains/rider/bin/rider.sh`
- `DEMUNTU_DOTNET_DEVELOPER_READY`

The latest passing Git GUI Tools gate validated:

- `git: git version 2.53.0`
- `git-cola-launcher: /usr/bin/git-cola`
- `git-gui-launcher: /usr/lib/git-core/git-gui`
- `gitk-launcher: /usr/bin/gitk`
- `meld-launcher: /usr/bin/meld`
- `gitkraken-launcher: /usr/local/bin/gitkraken`
- `DEMUNTU_GIT_GUI_TOOLS_READY`

The latest passing Docker GUI Tools gate validated:

- `docker: Docker version 29.5.3, build d1c06ef`
- `docker-enabled: enabled`
- `lazydocker: Version: 0.25.2`
- `portainer-service: enabled`
- `DEMUNTU_DOCKER_GUI_TOOLS_READY`

The latest passing Python Developer gate validated:

- `python: Python 3.14.4`
- `pip: pip 25.1.1`
- `pipx: 1.8.0`
- `git: git version 2.53.0`
- `gcc: gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0`
- `sqlite: 3.46.1`
- `jq: jq-1.8.1`
- `direnv: 2.37.1`

The Node Developer install gate selects the package-set automation entry with
QEMU sendkeys and uses `q35` to avoid the Ubuntu 26.04 installer overlayfs
fault seen intermittently with the default emulated machine. The latest passing
gate emitted:

- `DEMUNTU_PACKAGE_SETS: requested node-developer`
- `DEMUNTU_PACKAGE_SETS: installing node-developer`
- `DEMUNTU_PACKAGE_SETS: completed node-developer`

The installed-system boot check validated:

- `node: v24.15.0`
- `npm: 11.12.1`
- `code: 1.122.1`
- `git: git version 2.53.0`
- `gcc: gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0`
- `docker: Docker version 29.5.2, build 79eb04c`
- `docker-enabled: enabled`
- `ubuntu` user membership includes `docker`

The Demuntu server install profile uses one QEMU vCPU (`INSTALL_CPUS=1`) because
the Ubuntu 26.04 installer kernel hit an overlayfs fault during extraction in a
two-vCPU KVM run. The one-vCPU gate completed and booted the installed system.
After the Server Core bucket update, the default install gate emitted
`DEMUNTU_PACKAGE_SETS: none requested`, then the installed system boot showed
`ufw`, `fail2ban`, and `unattended-upgrades` starting before
`DEMUNTU_INSTALL_READY`.

The Demuntu Server GRUB menu includes a package-set selector entry. The default
autoinstall entry passes no package-set parameter. The selector entry passes
`demuntu.package_sets=ask`, which opens the package-set chooser during
Subiquity late-commands. Automation entries pass direct set ids for repeatable
QEMU tests. See [PACKAGE-SETS.md](PACKAGE-SETS.md) for the package set layout
and repo details.

Demian Desktop and Demuntu Desktop start branded welcome selectors on first
login so the same package sets can be selected after installation from a small
GUI welcome screen. The same selectors have a `--cli` mode for terminal use.

The desktop readiness marker discovers the UID 1000 live user dynamically so
Ubuntu-derived remasters using `demuntu` instead of `ubuntu` still apply theme
defaults and emit `DEMUNTU_DESKTOP_READY`. The QEMU serial assertion checks for
an exact marker line, so timeout suffixes such as
`DEMUNTU_DESKTOP_READY_SESSION_TIMEOUT` do not satisfy the gate.

The current Demuntu Desktop image strips the upstream Ubuntu Firefox and
Thunderbird seeded snaps, masks the broken live-session snap seed wait after
that cleanup, and removes the default LibreOffice/Rhythmbox/Totem/Thunderbird/
Transmission/Shotwell application set. The rebuilt filesystem validates
`vivaldi-stable 8.0.4033.42-1` and `vlc 3.0.23-1` as installed defaults.

Run a visible Demuntu desktop check:

```sh
qemu-system-x86_64 \
  -enable-kvm \
  -m 6144 \
  -smp 2 \
  -cdrom dist/images/demuntu-desktop-live.iso \
  -boot d \
  -no-reboot \
  -net none \
  -device virtio-rng-pci \
  -device qemu-xhci,id=demuntu-usb \
  -device usb-tablet,bus=demuntu-usb.0 \
  -display gtk \
  -serial file:/tmp/distro-qemu/demuntu-visible-serial.log
```

The visible desktop should show:

- XFCE panel and desktop icons
- DemSunset grey/orange/pink Demuntu wallpaper
- DemSunset icon theme
- charcoal DemSunset GTK/MATE theme with orange and pink focus/selection highlights
- Vivaldi and VLC as default desktop applications
- the centered Demuntu Welcome setup app on first login

## Notes

- Ubuntu 24.04 base ISOs were pruned from `dist/downloads` after the 26.04
  upgrade to reclaim disk space.
- `scripts/common/fetch-iso.sh` keeps 24.04 aliases for reproducibility, but
  the active Demuntu profiles target 26.04.
- Manifest generation trusts adjacent `.sha256` files by default. Set
  `MANIFEST_VERIFY_SHA256=1` when a full ISO rehash is required.
- `dist/manifest.json` is the authoritative machine-readable inventory; this
  matrix is the human-readable checkpoint.
