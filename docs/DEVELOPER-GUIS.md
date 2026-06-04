# Developer GUI Options

This note tracks GUI tools that are reasonable candidates for optional developer
payloads. Keep these out of default desktop buckets unless we decide a specific
spin should always include them.

## Git GUIs

| Tool | Fit | Packaging notes |
| --- | --- | --- |
| GitKraken Desktop | Polished commercial GUI and a good temporary/preferred option if the user likes it | Current payload uses GitKraken's active Linux tarball channel on amd64 |
| Sublime Merge | Fast native GUI with strong diff/merge workflow | Official apt repository is available |
| Git Cola | Lightweight open-source GUI | Usually available from Debian/Ubuntu repos |
| gitg | GNOME-style repository viewer | Usually available from Debian/Ubuntu repos |
| git gui/gitk | Minimal baseline tools from the Git project | Small and package-native, but dated UX |

Recommendation: keep GitKraken as an optional add-on, not a default, because it
is proprietary and account/licensing expectations differ by user. The
`git-gui-tools` package set installs Git Cola, git-gui, gitk, Meld, and
GitKraken best-effort.

## Docker GUIs

| Tool | Fit | Packaging notes |
| --- | --- | --- |
| Docker Desktop | Official full desktop Docker experience with GUI, Kubernetes, extensions, and bundled tooling | Official Linux installers exist for Ubuntu and Debian, but licensing and desktop virtualization behavior make it better as an optional workstation payload |
| Portainer CE | Good web UI for local or remote Docker hosts | Runs as a container, so it pairs naturally with Docker Engine already in `node-developer` |
| lazydocker | Excellent terminal UI for Docker and Compose | Lightweight, developer-friendly, not a traditional GUI |
| VS Code Docker extension | Good enough for many developers already using VS Code | Extension-based rather than system package |

Recommendation: use Portainer CE or lazydocker for a lightweight distro-native
Docker management option. The `docker-gui-tools` package set installs Docker
Engine, lazydocker, and a Portainer CE local service. Treat Docker Desktop as an
optional workstation add-on for users who specifically want Docker's official
GUI stack.

## References

- GitKraken install docs: `https://help.gitkraken.com/gitkraken-desktop/how-to-install/`
- Sublime Merge Linux repositories: `https://www.sublimemerge.com/docs/linux_repositories`
- Docker Desktop docs: `https://docs.docker.com/desktop/`
- Portainer docs: `https://docs.portainer.io/`
- lazydocker: `https://lazydocker.com/`
