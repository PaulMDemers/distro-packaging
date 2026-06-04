# Repositories

Local APT repository configuration and release policy notes live here.

The current development workflow uses `scripts/repos/build-apt-repo.sh` to build
a flat unsigned Demian repository in `dist/repo` from `dist/packages/*.deb`.
This is enough for local ISO builds and smoke tests.

Longer term repository management choices are:

- `aptly` for snapshot-oriented repository management
- `reprepro` for a simpler traditional repository workflow
