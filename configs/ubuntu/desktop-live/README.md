# Demuntu Desktop Live Profile

Demuntu desktop customization starts by patching an official Ubuntu desktop ISO rather than rebuilding Canonical's full live image pipeline.

Customization inputs:

- `packages.list`: extra packages to install into the live filesystem
- `files/`: files copied into the extracted squashfs root
- `hooks/`: scripts run inside the extracted squashfs root
- branding packages: wallpapers, installer assets, greeter theme, Plymouth
  theme, and boot menu artwork

The first implementation unpacks the official desktop ISO, applies the package,
file, and hook overlays, repacks the live squashfs, and rebuilds the hybrid ISO.

See `docs/BRANDING.md` for the full branding map.
