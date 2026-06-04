# Distro Build Plan

## Strategy

Treat ISO generation as a pipeline:

1. Resolve a profile.
2. Create or patch a root filesystem.
3. Apply packages, files, hooks, and installer automation.
4. Assemble bootable ISO media.
5. Generate checksums and manifests.
6. Boot/install test in QEMU.

The long-term goal is to move customization out of one-off filesystem edits and into versioned `.deb` packages, metapackages, and APT repositories.

## Initial Targets

### Debian Live Server

Use `live-build` because it is the native Debian Live toolchain. The starter profile creates a small live image with server/admin tools, SSH, and a simple MOTD hook.

### Ubuntu Server Autoinstall

Patch an official Ubuntu Server ISO with a NoCloud seed directory and GRUB autoinstall entry. This keeps us close to Canonical's supported image while allowing reproducible unattended installs.

### Customized Desktop

After the first two targets work, add desktop package manifests, branding packages, `/etc/skel` defaults, and live-session customization.

### Full Distro

Promote customization into packages:

- `distro-keyring`
- `distro-branding`
- `distro-defaults`
- `distro-server`
- `distro-desktop`

Then publish them through a signed APT repository and consume that repository from the ISO profiles.

## Practices

- Prefer package manifests and hooks over manual chroot changes.
- Keep secrets out of seed files.
- Generate SHA256 checksums for every produced ISO.
- Keep build outputs under `dist/` and temporary files under `build/`.
- Test BIOS and UEFI boot paths before publishing images.
- Use QEMU install tests for unattended installer media.

