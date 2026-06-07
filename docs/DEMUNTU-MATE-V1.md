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
June 7, 2026. It includes the clean auxiliary-layer pass that strips the
remaining upstream Thunderbird/snap state from the live layer stack, and it
restores the DemSunset GTK CSS to the last known wallpaper-safe selector set.
It also carries the flatter DemSunset filesystem icons and drive/network
aliases used by Caja's main pane and Places sidebar, plus flatter toolbar and
pathbar button chrome so those icons do not sit inside heavy beveled controls.
The address/location controls, sidebar rows, and Marco window-control glyphs
use the same flat DemSunset treatment. The panel layout now includes MATE's
GVC volume applet, and the DemSunset icon theme includes scalable volume OSD
icons. Compiz now autostarts by default when GL is available, using the
DemSunset cube/rotate profile; Marco remains the fallback when Compiz or
`glxinfo` is unavailable. Ubiquity is included for live desktop installation.
The desktop marker validates Demuntu's top and bottom MATE panel layout before
declaring the live session ready.

```text
ISO:    dist/images/demuntu-desktop-mate-live.iso
SHA256: 64ad6f3ac9e6548d60074aa2b6057c04bff600247c9bb442bbd5226c69efcef2
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
- The live serial log confirms the top panel includes `volume-control`.
- The theme hook emits `DEMUNTU_DESKTOP_APPLY_THEME_DONE`.
- The Compiz autostart helper emits `DEMUNTU_COMPIZ_AUTOSTART_BEGIN` and
  starts `compiz --replace ccp` after a successful `glxinfo` probe.
- The live rootfs includes `ubiquity`, `ubiquity-frontend-gtk`,
  `ubiquity-slideshow-ubuntu-mate`, `broadcom-sta-dkms`,
  `linux-firmware-broadcom-wireless`, and `dkms`.

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
ubiquity
ubiquity-frontend-gtk
ubiquity-slideshow-ubuntu-mate
```

The live installer launcher is branded as `Install Demuntu` and executes
`ubiquity gtk_ui`. Demuntu Welcome also falls back to `ubiquity gtk_ui` if no
installer desktop entry is discoverable.

MacBook Air Broadcom Wi-Fi coverage is handled by the normal Ubuntu firmware
stack plus Resolute's Broadcom STA DKMS package:

```text
linux-firmware
linux-firmware-broadcom-wireless
broadcom-sta-dkms
dkms
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
Compiz skeleton defaults: /etc/skel/.config/compiz-1/compizconfig/Default.ini
Compiz MATE profile source: /usr/share/demuntu/compizconfig/mate.ini
Compiz MATE selector source: /usr/share/demuntu/compizconfig/mate.conf
```

Theme and icon sources live under
`packages/meta/demuntu-meta/branding/usr/share/themes/DemSunset-Dark` and
`packages/meta/demuntu-meta/branding/usr/share/icons/DemSunset`. The DemSunset
icon theme includes flat filesystem icons for the standard XDG folders,
`user-desktop`/`folder-desktop`, `drive-harddisk*`, `network-server`,
`network-workgroup`, matching app-menu category icons, and scalable
`audio-volume-*` status icons for the keyboard volume OSD. The deterministic
generator is `scripts/assets/render-demsunset-branding.py`.

Demuntu MATE uses its own panel layout instead of Ubuntu MATE's `familiar`
layout. The upstream layout references Brisk Menu, snap Firefox, Evolution, and
indicator applets, which are intentionally absent from Demuntu's trimmed package
set and can trigger repeated panel error dialogs. The MATE image hook also
copies the Demuntu Compiz MATE selector/profile into `/etc/compizconfig` after
Ubuntu MATE packages install their defaults, avoiding a dpkg ownership conflict
with `ubuntu-mate-default-settings`.

The MATE runtime helper also seeds panel state at first login when
`org.mate.panel toplevel-id-list` is empty. It first asks `mate-panel` to reset
against the Demuntu layout, then falls back to explicit gsettings for top and
bottom panels with safe stock applets.

## Compiz Probe

On June 6, 2026, the MATE ISO was booted in QEMU with `gtk,gl=on`,
`virtio-vga-gl`, and a qemu-guest-agent socket. The guest reached the normal
MATE readiness marker, then the default Demuntu autostart helper successfully
changed the active window manager to `Compiz`.

The guest GL stack reported direct rendering with Mesa/virgl:

```text
OpenGL renderer string: virgl (LLVMPIPE (LLVM 20.1.2, 256 bits))
OpenGL version string: 4.3 (Compatibility Profile) Mesa 26.0.3-1ubuntu1
```

The Compiz log confirmed `composite`, `opengl`, `decor`, `mousepoll`, `cube`,
`rotate`, `expo`, `ezoom`, `scale`, and `animation` started from the default
profile. `wall` is intentionally not loaded for this profile.

The final rebuild after the metacity decorator XML cleanup passed the standard
serial smoke test. The host does not expose a DRM render node for QEMU
`egl-headless`, and the visible GTK/QGA path wedged WSL during the final
decorator-only retest, so the final GL/cube result is carried forward from the
immediately preceding QGA pass with the unchanged Compiz profile.

Repeatable guest-agent helpers live in the packaging repo:

```text
scripts/test/qga-exec.py
scripts/test/guest-demuntu-compiz-probe.sh
scripts/test/guest-demuntu-compiz-status.sh
```

## Next Work

1. Verify Compiz startup and cube/expo behavior on real hardware.
2. Verify that Demuntu's top and bottom MATE panels appear without panel error
   dialogs.
3. Convert the manual QGA Compiz probe into a formal make target with a
   `DEMUNTU_COMPIZ_READY` serial marker.
4. Move XFCE-specific branding scripts into legacy/prototype paths or replace
   them with MATE-aware equivalents.
