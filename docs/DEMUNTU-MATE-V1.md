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
- Replace the DemChrome red/chrome prototype look with the DemSunset grey,
  orange, pink, and silver identity.

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

## Current Build

The current validated MATE release-line ISO was built and boot-tested on
June 5, 2026. It includes the clean auxiliary-layer pass that strips the
remaining upstream Thunderbird/snap state from the live layer stack.

```text
ISO:    dist/images/demuntu-desktop-mate-live.iso
SHA256: 770d1ed04b1281436c700554b1ea121ad4e44021b8ce39f366c2998717e218c7
Marker: DEMUNTU_MATE_DESKTOP_READY
```

Audit notes:

- `demuntu-mate-desktop`, `mate-panel`, `caja`, `compiz`, and `compiz-mate`
  are installed in the live rootfs.
- `demuntu-desktop`, `xfce4`, `xfce4-panel`, `xfdesktop`, `thunar`, and
  `libreoffice-common` are absent from the MATE live rootfs.
- `snapd` is removed for this spin, seeded Firefox/Thunderbird snaps are
  stripped, and auxiliary casper layers no longer contain the old
  `snap-thunderbird` mount unit.
- The live serial log confirms `DEMUNTU_DESKTOP_SESSION mate`.
- The theme hook emits `DEMUNTU_DESKTOP_APPLY_THEME_DONE`.

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

The desktop profile also carries virtualization guest integration for common
test and homelab targets:

```text
qemu-guest-agent
spice-vdagent
open-vm-tools
open-vm-tools-desktop
virtualbox-guest-utils
virtualbox-guest-x11
xserver-xorg-video-qxl
xserver-xorg-video-vmware
```

QEMU and Proxmox primarily benefit from `qemu-guest-agent` for guest status and
shutdown integration, plus `spice-vdagent` and the QXL Xorg driver for better
clipboard/display/pointer behavior in SPICE-style consoles. Our QEMU smoke-test
helper also attaches a USB tablet pointer by default to make host-to-guest mouse
movement less awkward in visible test windows.

Hyper-V's core storage, network, and input drivers are carried by the Ubuntu
kernel. The `linux-cloud-tools-*` Hyper-V user daemons are intentionally not
pulled by this profile yet because the generic meta packages advance the live
image kernel and headers during customization.

## DemSunset Theme

The MATE release line uses:

```text
Wallpaper: /usr/share/backgrounds/demuntu/demuntu-default.png
GTK/Marco theme: DemSunset-Dark
Icon theme: DemSunset
Plymouth theme: demuntu-sunset
Panel layout: /usr/share/mate-panel/layouts/demuntu.layout
Schema override: /usr/share/glib-2.0/schemas/60_demuntu-mate.gschema.override
MATE runtime helper: /usr/lib/demuntu/apply-mate-theme
Compiz defaults: /etc/skel/.config/compiz-1/compizconfig/Default.ini
```

Theme and icon sources live under
`packages/meta/demuntu-meta/branding/usr/share/themes/DemSunset-Dark` and
`packages/meta/demuntu-meta/branding/usr/share/icons/DemSunset`. The DemSunset
icon theme includes flat filesystem icons for the standard XDG folders,
`user-desktop`/`folder-desktop`, and matching app-menu category icons. The
deterministic generator is `scripts/assets/render-demsunset-branding.py`.

Demuntu MATE uses its own panel layout instead of Ubuntu MATE's `familiar`
layout. The upstream layout references Brisk Menu, snap Firefox, Evolution, and
indicator applets, which are intentionally absent from Demuntu's trimmed package
set and can trigger repeated panel error dialogs. Compiz remains installed and
configured, but it is no longer enabled as an automatic first-login replacement
until the base MATE session is stable.

The MATE runtime helper also seeds panel state at first login when
`org.mate.panel toplevel-id-list` is empty. It first asks `mate-panel` to reset
against the Demuntu layout, then falls back to explicit gsettings for top and
bottom panels with safe stock applets.

## Next Work

1. Boot the MATE ISO visibly in QEMU.
2. Verify that Demuntu's top and bottom MATE panels appear without panel error
   dialogs.
3. Verify whether Compiz starts reliably on the live image under QEMU and on
   real hardware.
4. Tune Compiz defaults for cube/expo behavior against QEMU and hardware.
5. Move XFCE-specific branding scripts into legacy/prototype paths or replace
   them with MATE-aware equivalents.
