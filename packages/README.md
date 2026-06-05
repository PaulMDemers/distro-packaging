# Packages

Custom Debian package sources live here.

The starter source packages are `packages/meta/demian-meta` and
`packages/meta/demuntu-meta`.

Demian packages:

- `demian-branding`
- `demian-base`
- `demian-server`
- `demian-desktop`
- `demian-rescue`

Demuntu packages:

- `demuntu-branding`
- `demuntu-base`
- `demuntu-server`
- `demuntu-desktop`

Build with:

```sh
make packages
make repo
```

The keyring package is still planned. Repository signing is intentionally
deferred while the builds remain local.

Branding package payloads are documented in `docs/BRANDING.md`. In short,
`demian-branding` and `demuntu-branding` carry release identity, wallpapers,
DemChrome/DemSunset icons, XFCE and MATE defaults, LightDM greeter config, Plymouth themes, and
runtime desktop theme helpers.
