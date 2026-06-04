# Spin Specs

Spin specs are the edition-level source of truth for Demian and Demuntu ISO
profiles. Each spec lives in `configs/spins/*.toml` and renders into the legacy
files consumed by the current build scripts:

- `configs/profiles.tsv`
- `configs/<family>/<profile>/profile.env`

The package intent behind those specs is tracked in
[SPIN-MATRIX.md](SPIN-MATRIX.md). Use the matrix to decide which package bucket
belongs in a spin, then express the result through metapackages and package
lists.

Run this after editing a spin:

```sh
make spins
make profiles
make manifest
```

The manifest records the originating spin spec for each profile under
`profiles[].spin_spec`.

## Spec Layout

Required tables:

| Table | Purpose |
| --- | --- |
| `[spin]` | Stable id, family, build kind, profile directory, and description |
| `[image]` | Distro/image naming, architecture, and optional volume id |
| `[packages]` | Ordered metapackages that define the edition |

Family-specific tables:

| Table | Used by |
| --- | --- |
| `[debian]` | Demian `live-build` profiles |
| `[ubuntu]` | Demuntu profiles rebuilt from upstream Ubuntu media |
| `[install]` | Autoinstall profiles with a disposable QEMU disk test |
| `[artifacts]` | Explicit serial logs, screenshots, and other output paths |

Autoinstall specs may set `[install].cpus` when a profile needs a stable QEMU
CPU topology. That value renders to `INSTALL_CPUS` in `profile.env` and is used
by `make demuntu-server-autoinstall-install`.

## Current Specs

| Spec | Role |
| --- | --- |
| `demian-server-live.toml` | Lightweight Debian-based server live ISO |
| `demian-desktop-live.toml` | Debian-based XFCE desktop live ISO |
| `demian-rescue-live.toml` | Debian-based rescue/recovery live ISO |
| `demuntu-server-autoinstall.toml` | Ubuntu-based unattended server installer |
| `demuntu-desktop-live.toml` | Ubuntu-based XFCE desktop live ISO |

## Adding A Spin

1. Copy the nearest existing spec in `configs/spins`.
2. Change `[spin].id`, `[spin].profile_dir`, `[image].image_name`, and package
   metapackages.
3. Add hooks, package lists, or installer seed files under the selected profile
   directory.
4. Run `make spins profiles manifest`.
5. Build and QEMU-test the new target before treating it as supported.

The renderer intentionally does not delete files from profile directories.
Hooks, package lists, and seed data stay hand-authored until we decide which of
those should also become declarative.
