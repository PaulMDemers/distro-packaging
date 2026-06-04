# Branding Map

Demian and Demuntu branding is intentionally split between reproducible assets,
metapackages, and ISO-builder patches. This keeps future spins from needing
one-off edits in unpacked build trees.

## Source Of Truth

| Area | Path | Notes |
| --- | --- | --- |
| Asset generator | `scripts/assets/render-redchrome-wallpapers.py` | Regenerates wallpaper, boot menu, and Plymouth PNG assets. |
| Shared boot assets | `assets/boot/` | Syslinux-sized backgrounds copied by Debian `live-build` profiles. |
| Demian package branding | `packages/meta/demian-meta/branding/` | Files installed by `demian-branding`. |
| Demuntu package branding | `packages/meta/demuntu-meta/branding/` | Files installed by `demuntu-branding`. |
| Debian live builder | `scripts/debian/build-live.sh` | Adds Syslinux menu background, colors, and profile labels. |
| Ubuntu desktop builder | `scripts/ubuntu/build-desktop-live.sh` | Adds GRUB background, menu colors, and Demuntu menu labels. |
| Ubuntu server builder | `scripts/ubuntu/build-server-autoinstall.sh` | Adds GRUB background and Demuntu server menu labels. |
| Ubuntu initrd branding | `scripts/ubuntu/rebrand-initrd.sh` | Rewrites early boot `os-release`, Plymouth text theme, and desktop spinner watermark. |
| Desktop hooks | `configs/*/desktop-live/hooks/` | Copy XFCE defaults and select the Plymouth theme in the chroot. |

Run the generator after changing the red/silver visual language:

```sh
python3 scripts/assets/render-redchrome-wallpapers.py
make packages repo manifest
```

Boot-menu backgrounds are generated from the same red/silver palette as the
desktop wallpaper, but intentionally omit the central chrome badge. GRUB and
Syslinux draw their own menu boxes, so the boot art stays clear behind the
interactive text.

## Installed Branding Files

| Surface | Demian path | Demuntu path |
| --- | --- | --- |
| Desktop wallpaper | `/usr/share/backgrounds/demian/demian-default.png` | `/usr/share/backgrounds/demuntu/demuntu-default.png` |
| GRUB background | `/usr/share/backgrounds/demian/demian-grub.png` | `/usr/share/backgrounds/demuntu/demuntu-grub.png` |
| Icon theme | `/usr/share/icons/DemChrome` | `/usr/share/icons/DemChrome` |
| XFCE defaults | `/usr/share/demian/xfce-defaults/xfce4` | `/usr/share/demuntu/xfce-defaults/xfce4` |
| XFCE runtime helper | `/usr/lib/demian/apply-xfce-theme` | `/usr/lib/demuntu/apply-xfce-theme` |
| LightDM greeter | `/etc/lightdm/lightdm-gtk-greeter.conf.d/50-demchrome.conf` | `/etc/lightdm/lightdm-gtk-greeter.conf.d/50-demchrome.conf` |
| Plymouth theme | `/usr/share/plymouth/themes/demian-chrome` | `/usr/share/plymouth/themes/demuntu-chrome` |
| Welcome launcher | `/etc/skel/Desktop/Demian Welcome.desktop` | `/etc/skel/Desktop/Demuntu Welcome.desktop` |

The XFCE runtime helper exists because live sessions create monitor-specific
backdrop nodes at startup. It discovers the real `/backdrop/.../workspace...`
paths, applies the wallpaper and icon theme through `xfconf-query`, and also
renames installer launchers to the derivative name when they appear on the
desktop. Desktop hooks also copy the XFCE defaults into `/etc/skel/.config` so
new live users inherit the wallpaper before the helper runs.

## Build-Time Branding

Debian live ISOs use Syslinux through `live-build`. `scripts/debian/build-live.sh`
copies `assets/boot/demian-isolinux.png` into the bootloader tree, sets the red
selection color, and rewrites generic `Live` labels into Demian profile labels.

Demuntu desktop and server ISOs start from upstream Ubuntu media. Their builders
copy a red/silver background into `/boot/grub/`, prepend a Demuntu GRUB stanza,
rename upstream Ubuntu menu labels in `grub.cfg` and `loopback.cfg`, rewrite
`.disk/info`, and refresh `md5sum.txt`.

Plymouth themes are installed and selected in the live filesystem. Debian
`live-build` includes that selection while generating the image. Ubuntu images
also pass through `scripts/ubuntu/rebrand-initrd.sh`, which unpacks the initrd,
sets Demuntu early boot identity, replaces the text-mode Plymouth title, and
uses the generated `assets/boot/demuntu-plymouth-watermark.png` for the desktop
spinner watermark before repacking the initrd.

## Verification

After branding changes, run:

```sh
python3 scripts/assets/render-redchrome-wallpapers.py
wsl.exe -u root -- bash -lc 'cd /mnt/c/Users/Paul/Desktop/distro && make packages repo manifest'
```

For desktop-visible changes, rebuild and test the affected ISOs:

```sh
BUILD_ROOT=/root/demuntu-build make demian-desktop-live demian-desktop-live-test
BUILD_ROOT=/root/demuntu-build make demuntu-desktop-live demuntu-desktop-live-test
```

Then run a visible QEMU framebuffer check and confirm:

- Red/silver wallpaper is visible.
- DemChrome icons are active.
- Installer launcher text uses Demian or Demuntu.
- GRUB/Syslinux menus use derivative labels and red selection highlights.
- LightDM greeter config points at the derivative wallpaper and icon theme.
