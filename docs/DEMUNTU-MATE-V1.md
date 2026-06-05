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

The first boot marker target is `DEMUNTU_MATE_DESKTOP_READY`, emitted after the
live session starts `mate-panel` and `caja`.

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

1. Build the first `demuntu-desktop-mate-live.iso`.
2. Boot it headless and visibly in QEMU.
3. Verify whether Compiz starts reliably on the live image under QEMU and on
   real hardware.
4. Add the sunset theme package assets:
   - wallpaper
   - Plymouth splash
   - GRUB background
   - LightDM greeter config
   - MATE GTK theme
   - icon recolors
5. Add Compiz defaults for cube/expo behavior with a clean fallback path.
6. Move XFCE-specific branding scripts into legacy/prototype paths or replace
   them with MATE-aware equivalents.
