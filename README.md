# Distro ISO Factory

Starter build system for producing customized Debian and Ubuntu based ISO images.

Current named spins:

- Demian, a Debian-based family built with `live-build`
- Demuntu, an Ubuntu-based family built from Ubuntu Server/Desktop media

The supported build styles are:

- Demian live server, desktop, and rescue ISOs built with `live-build`
- Demuntu Server autoinstall ISO built by patching an official ISO with NoCloud seed data
- Demuntu Desktop live ISO built by patching an official desktop ISO live filesystem

## Requirements

Run the build scripts from a Debian or Ubuntu environment with root privileges. On Windows, use WSL 2 with an Ubuntu or Debian distribution.

Common tools:

```sh
sudo apt-get update
sudo apt-get install -y curl ca-certificates xorriso isolinux syslinux-common qemu-system-x86 coreutils
```

Debian live ISO tools:

```sh
sudo apt-get install -y live-build
```

Ubuntu autoinstall ISO tools:

```sh
sudo apt-get install -y p7zip-full xorriso
```

## Quick Start

Use the Makefile from a Debian or Ubuntu shell:

```sh
make help
make spins
make profiles
make manifest
make check-host
sudo make install-deps
```

Check host dependencies:

```sh
find scripts -name '*.sh' -exec chmod +x {} +
./scripts/common/check-host.sh
```

Install build dependencies:

```sh
sudo ./scripts/common/install-deps.sh all
```

When using WSL, see [docs/WSL.md](docs/WSL.md) before running long builds.

Build the Demian live server ISO:

```sh
sudo BUILD_ROOT=/root/demian-build make demian-server-live
make demian-server-live-test
```

Build the Demian desktop or rescue live ISOs:

```sh
sudo BUILD_ROOT=/root/demian-build make demian-desktop-live
make demian-desktop-live-test
sudo BUILD_ROOT=/root/demian-build make demian-rescue-live
make demian-rescue-live-test
```

Build the starter metapackages:

```sh
make packages
make repo
```

`make repo` writes a flat development APT repository to `dist/repo`. It is
unsigned and intended for ISO build inputs, not long-term public distribution.
Demian and Demuntu profiles consume matching metapackages from `dist/packages`.
The local development repository is not signed yet; that is acceptable for local
builds and can be hardened later with keyring packages.

Optional install-time package sets are documented in
[docs/PACKAGE-SETS.md](docs/PACKAGE-SETS.md). Demuntu Server currently offers a
default no-extra-packages install plus Node Developer and Python Developer
package-set paths. Demian Desktop and Demuntu Desktop start matching first-login
welcome selectors for optional package sets.

Spin package intent is tracked in [docs/SPIN-MATRIX.md](docs/SPIN-MATRIX.md).
Use it as the checklist for deciding which packages are default image contents
and which stay selectable through package sets.

Patch an Ubuntu Server ISO into a Demuntu Server autoinstall ISO:

```sh
make ubuntu-base
sudo BUILD_ROOT=/root/demuntu-build make demuntu-server-autoinstall
make demuntu-server-autoinstall-boot-test
```

Run the Demuntu autoinstall against a disposable qcow2 disk and then boot-check
the installed system:

```sh
sudo BUILD_ROOT=/root/demuntu-build make demuntu-server-autoinstall-install
```

In headless QEMU, Subiquity may leave the installer VM running after the disk is
usable. The install target stops the VM at timeout and then validates the
installed disk by booting it and waiting for the configured serial marker.

Build and boot-test the Demuntu desktop live ISO:

```sh
make ubuntu-desktop-base
sudo BUILD_ROOT=/root/demuntu-build make demuntu-desktop-live
make demuntu-desktop-live-test
```

Boot-test any ISO:

```sh
./scripts/test/boot-iso.sh dist/images/example.iso
./scripts/test/boot-iso.sh --headless --timeout 60 dist/images/example.iso
```

The QEMU test harnesses default to `QEMU_ACCEL=auto`, which uses KVM when
`/dev/kvm` is available and falls back to software emulation otherwise. Override
with `QEMU_ACCEL=tcg` or pass `--accel tcg` when you need a fully emulated run.

Generate an artifact inventory:

```sh
make manifest
```

The manifest is written to `dist/manifest.json` and records each profile's ISO,
checksum, size, base ISO alias, serial-marker test status, and local repository
inventory.

Cleanup targets:

```sh
make clean-work
make clean-cache
CONFIRM_DELETE_ARTIFACTS=yes make clean-artifacts
```

`clean-work` removes temporary build trees. `clean-cache` removes downloaded
upstream base ISOs. `clean-artifacts` removes generated ISOs and logs, so it
requires the explicit confirmation variable.

## Project Layout

```text
configs/      Profile registry, build profiles, and installer seed files
docs/         Architecture notes and build practices
packages/     Custom Debian package sources
repos/        Local APT repository notes and future repository manager config
scripts/      Build, patch, and test scripts
assets/       Branding, wallpapers, boot assets
build/        Temporary build workspace
dist/         Downloaded base ISOs and generated images
```

Current defaults as of June 2026:

- Debian stable: `trixie`
- Ubuntu LTS: `26.04`

Spin specs live in `configs/spins/*.toml`. `make spins` renders them into
`configs/profiles.tsv` and per-profile `profile.env` files, which define build
names, QEMU smoke-test markers, and validation timeouts for the existing build
scripts.

See [docs/RELEASE-MATRIX.md](docs/RELEASE-MATRIX.md) for the current baseline
release matrix, artifact hashes, and validation gates.
See [docs/PACKAGE-SETS.md](docs/PACKAGE-SETS.md) for optional install-time
package bundles.
See [docs/PACKAGE-PROFILES.md](docs/PACKAGE-PROFILES.md) for the current
metapackage layering policy.
See [docs/SPINS.md](docs/SPINS.md) for the declarative spin-spec format.
