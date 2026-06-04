# Package Profiles

Demian and Demuntu image customization should move toward versioned
metapackages and away from one-off chroot package lists. The package lists can
remain as bootstrap inputs, but the package contract for each image should live
in `packages/meta/*/debian/control`.

## Profile Layers

| Layer | Purpose | Examples |
| --- | --- | --- |
| Branding | Identity files, wallpapers, icons, greeter/Plymouth theme, `/etc/skel`, release metadata | `demian-branding`, `demuntu-branding` |
| Base | Common CLI tools and defaults expected everywhere | certificates, curl, sudo, shell/admin basics |
| Server | Remote administration and lightweight server tools | SSH server, rsync, tmux, small editor |
| Desktop | Display manager, desktop session, browser, network UX | LightDM, XFCE, browser, terminal |
| Rescue | Recovery and diagnostics packages | storage tools, SMART, partitioning, network scanners |

## Current Metapackages

| Family | Metapackage | Role |
| --- | --- | --- |
| Demian | `demian-branding` | Debian-based identity files |
| Demian | `demian-base` | Common Demian packages |
| Demian | `demian-server` | Server/admin package set |
| Demian | `demian-desktop` | Desktop package set |
| Demian | `demian-rescue` | Rescue package set |
| Demuntu | `demuntu-branding` | Ubuntu-based identity files and desktop defaults |
| Demuntu | `demuntu-base` | Common Demuntu packages |
| Demuntu | `demuntu-server` | Server/admin package set |
| Demuntu | `demuntu-desktop` | XFCE desktop live package set |

## Target Package Policy

- Put packages used by every image in the family base package.
- Put packages that define an image role in the role package.
- Prefer metapackage dependencies over duplicate package-list entries.
- Keep explicit package lists only for toolchain/bootstrap packages that must be
  present before the local metapackage is consumed.
- Keep desktop dependencies conservative until visible QEMU checks pass.
- Keep rescue dependencies Debian-only until a Demuntu rescue profile exists.

## Current Build Gates

After package profile changes, run:

```sh
make packages repo manifest
```

For Demian profile changes, run the affected live build and marker test:

```sh
BUILD_ROOT=/root/demuntu-build make demian-server-live demian-server-live-test
BUILD_ROOT=/root/demuntu-build make demian-desktop-live demian-desktop-live-test
BUILD_ROOT=/root/demuntu-build make demian-rescue-live demian-rescue-live-test
```

For Demuntu profile changes, run:

```sh
BUILD_ROOT=/root/demuntu-build make demuntu-server-autoinstall demuntu-server-autoinstall-install
BUILD_ROOT=/root/demuntu-build make demuntu-desktop-live demuntu-desktop-live-test
```

Run a visible QEMU check after desktop package changes.

Branding payloads and boot-menu hook points are mapped in `docs/BRANDING.md`.
