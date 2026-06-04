# WSL Build Notes

This repository can be edited on Windows, but ISO builds are more reliable from the Linux filesystem inside WSL 2.

Recommended setup:

```sh
mkdir -p ~/src
rsync -a --delete /mnt/c/Users/Paul/Desktop/distro/ ~/src/distro/
cd ~/src/distro
find scripts -name '*.sh' -exec chmod +x {} +
sudo ./scripts/common/install-deps.sh all
./scripts/common/check-host.sh
```

If you build directly from the Windows-mounted workspace, keep live-build's
temporary chroot on the WSL ext4 filesystem:

```sh
cd /mnt/c/Users/Paul/Desktop/distro
sudo BUILD_ROOT=/root/demian-build make demian-server-live
```

Build outputs can be copied back to Windows after the build:

```sh
mkdir -p /mnt/c/Users/Paul/Desktop/distro/dist
rsync -a dist/ /mnt/c/Users/Paul/Desktop/distro/dist/
```

Why this matters:

- Live image tools create symlinks, device metadata, and root-owned files.
- Windows-mounted paths under `/mnt/c` can behave differently from native Linux filesystems.
- Large ISO and squashfs builds are usually faster on the WSL ext4 filesystem.
