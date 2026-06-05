# Demuntu Desktop MATE

Release-line profile for Demuntu Desktop on Ubuntu 26.04 LTS with MATE.

This profile carries forward the curated XFCE v1 application choices and starts
the transition to:

- MATE as the default desktop session.
- LightDM autologin for the live user.
- Compiz as the preferred compositor on X11, with Marco left available as the
  fallback window manager.
- The next Demuntu visual identity: sunset grey, orange, and pink.

The first implementation pass is intentionally structural. The package list and
session hook make the ISO buildable as a MATE/Compiz target; the complete
sunset theme assets and Compiz cube defaults are layered in subsequent commits.
