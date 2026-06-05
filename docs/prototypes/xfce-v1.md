# Prototype XFCE v1

`prototype-xfce-v1` is the archived checkpoint for the first Demian and Demuntu
desktop customization pass.

## Scope

- Demuntu Desktop live ISO on Ubuntu 26.04 LTS with XFCE.
- Demian Desktop live ISO on Debian 13/trixie with XFCE.
- Red, silver, black, and charcoal DemChrome visual identity.
- Demuntu Welcome and Demian Welcome first-login selectors.
- Optional package-set installer plumbing for Node, Python, .NET, Git GUI, and
  Docker GUI/developer payloads.
- Demuntu desktop app curation: Vivaldi and VLC added; Firefox, Thunderbird,
  LibreOffice, Rhythmbox, Totem/Videos, Transmission, and Shotwell removed from
  the live surface.

## Local Artifact Archive

The generated artifacts are stored locally and intentionally ignored by Git:

```text
dist/prototypes/xfce-v1/
  manifest.json
  demuntu/
    demuntu-desktop-live.iso
    demuntu-desktop-live.iso.sha256
    demuntu-desktop-live-serial.log
    demuntu-desktop-welcome.png
    demuntu-redchrome-visible.png
  demian/
    demian-desktop-live-trixie-amd64.iso
    demian-desktop-live-trixie-amd64.iso.sha256
    demian-desktop-live-trixie-amd64-serial.log
```

## Artifact Hashes

| Profile | SHA256 | Boot marker |
| --- | --- | --- |
| `demuntu-desktop-live` | `9a26c7581d694114b11e86a26dab9e4bb0e84a09718bd3c050c753b25ea66974` | `DEMUNTU_DESKTOP_READY` |
| `demian-desktop-live` | `8f8ff7795330696143301013263bc14aa93693f1c549ba61d81f566c1a15f431` | `DEMIAN_DESKTOP_READY` |

## Validation

- Demuntu Desktop live ISO booted in QEMU and reached
  `DEMUNTU_DESKTOP_READY`.
- Demian Desktop live ISO booted in QEMU and reached `DEMIAN_DESKTOP_READY`.
- Demuntu package and live-layer cleanup verified removal of seeded Firefox and
  Thunderbird snaps, default office/media/mail/photo/transmission applications,
  and stale menu launchers.
- Demian was rebuilt after the latest branding/theme source updates and passed
  the headless boot marker gate.

## Known Follow-Up

This prototype is no longer the active release direction. The next release line
starts with Demuntu Desktop on MATE with a sunset grey/orange/pink visual
identity and a composited X11 session target.
