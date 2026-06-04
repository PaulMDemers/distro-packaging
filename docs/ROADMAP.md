# Roadmap

## Milestone 1: Debian Live Server

- Build a bootable Debian live ISO from `configs/debian/live-server`.
- Confirm package manifest and chroot hooks apply.
- Add QEMU boot smoke test notes.

## Milestone 2: Ubuntu Server Autoinstall

- Download and verify the current Ubuntu 26.04 LTS server ISO.
- Add NoCloud autoinstall seed.
- Add a GRUB autoinstall boot entry.
- Boot-test and then run an install test in QEMU.

## Milestone 3: Custom Desktop Live ISO

- Add desktop package profiles.
- Add branding, `/etc/skel` defaults, boot-menu visuals, greeter theme, and
  Plymouth theme.
- Add live user defaults, wallpapers, browser defaults, and first-login behavior.

## Milestone 4: Local APT Repository

- Add a signed repository using `aptly` or `reprepro`.
- Build metapackages for base, server, desktop, and branding profiles.
- Consume the repository from Debian and Ubuntu profiles.

## Milestone 5: Full Derivative Distro

- Add keyring, branding, defaults, and release metadata packages.
- Define upgrade and security update policy.
- Generate release manifests, checksums, and install test reports.
