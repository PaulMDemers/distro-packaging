# Demuntu MATE v1 Release Line

Demuntu MATE v1 is the first release-focused Demuntu Desktop line after the
`prototype-xfce-v1` checkpoint.

## Goals

- Build from Ubuntu 26.04 LTS.
- Use MATE as the default desktop instead of XFCE.
- Prefer an X11 Compiz session for visual effects, including cube/expo-style
  workspace effects where supported.
- Keep Marco available as the fallback MATE window manager when GL or Compiz
  fails.
- Carry forward Demuntu Welcome, optional developer package sets, Vivaldi, VLC,
  driver/network/audio tooling, and the stripped default app policy from XFCE
  v1.
- Replace the DemChrome red/chrome prototype look with a sunset grey,
  orange, and pink identity.

## Initial Profile

The initial release profile is:

```text
configs/spins/demuntu-desktop-mate-live.toml
configs/ubuntu/desktop-mate/
```

Build targets:

```sh
make demuntu-desktop-mate-live
make demuntu-desktop-mate-live-test
```

The boot marker target is `DEMUNTU_MATE_DESKTOP_READY`, emitted after the live
session starts `mate-panel` and `caja`.

## First Build

The first validated MATE release-line ISO was built and boot-tested on
June 5, 2026.

```text
ISO:    dist/images/demuntu-desktop-mate-live.iso
SHA256: f2e51bcd184b246cf0fb52a225e35bef72e02ddd7ef61727f1d066ea71e8c99b
Marker: DEMUNTU_MATE_DESKTOP_READY
```

Audit notes:

- `demuntu-mate-desktop`, `mate-panel`, `caja`, `compiz`, and `compiz-mate`
  are installed in the live rootfs.
- `demuntu-desktop`, `xfce4`, `xfce4-panel`, `xfdesktop`, `thunar`, and
  `libreoffice-common` are absent from the MATE live rootfs.
- The live serial log confirms `DEMUNTU_DESKTOP_SESSION mate`.

## Desktop Stack

Default packages include the curated MATE core, LightDM, hardware/network/audio
support, Vivaldi, VLC, and Compiz:

```text
mate-desktop-environment-core
mate-panel
caja
mate-control-center
mate-terminal
marco
compiz
compiz-mate
compizconfig-settings-manager
compiz-plugins
compiz-plugins-default
compiz-plugins-extra
fusion-icon
```

## Next Work

1. Boot the MATE ISO visibly in QEMU.
2. Verify whether Compiz starts reliably on the live image under QEMU and on
   real hardware.
3. Add the sunset theme package assets:
   - wallpaper
   - Plymouth splash
   - GRUB background
   - LightDM greeter config
   - MATE GTK theme
   - icon recolors
4. Add Compiz defaults for cube/expo behavior with a clean fallback path.
5. Move XFCE-specific branding scripts into legacy/prototype paths or replace
   them with MATE-aware equivalents.
