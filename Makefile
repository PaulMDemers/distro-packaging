SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

PROFILE_INFO := bash scripts/common/profile-info.sh

DEBIAN_LIVE_ID ?= demian-server-live
DEBIAN_LIVE_PROFILE ?= $(shell $(PROFILE_INFO) $(DEBIAN_LIVE_ID) profile_dir)
DEBIAN_LIVE_ISO ?= $(shell $(PROFILE_INFO) $(DEBIAN_LIVE_ID) iso)
DEBIAN_LIVE_SERIAL_LOG ?= $(shell $(PROFILE_INFO) $(DEBIAN_LIVE_ID) serial_log)
DEBIAN_LIVE_MARKER ?= $(shell $(PROFILE_INFO) $(DEBIAN_LIVE_ID) boot_marker)
DEBIAN_LIVE_TIMEOUT ?= $(shell $(PROFILE_INFO) $(DEBIAN_LIVE_ID) boot_timeout)
DEBIAN_LIVE_MEMORY ?= $(shell $(PROFILE_INFO) $(DEBIAN_LIVE_ID) memory)

DEBIAN_DESKTOP_ID ?= demian-desktop-live
DEBIAN_DESKTOP_PROFILE ?= $(shell $(PROFILE_INFO) $(DEBIAN_DESKTOP_ID) profile_dir)
DEBIAN_DESKTOP_ISO ?= $(shell $(PROFILE_INFO) $(DEBIAN_DESKTOP_ID) iso)
DEBIAN_DESKTOP_SERIAL_LOG ?= $(shell $(PROFILE_INFO) $(DEBIAN_DESKTOP_ID) serial_log)
DEBIAN_DESKTOP_MARKER ?= $(shell $(PROFILE_INFO) $(DEBIAN_DESKTOP_ID) boot_marker)
DEBIAN_DESKTOP_TIMEOUT ?= $(shell $(PROFILE_INFO) $(DEBIAN_DESKTOP_ID) boot_timeout)
DEBIAN_DESKTOP_MEMORY ?= $(shell $(PROFILE_INFO) $(DEBIAN_DESKTOP_ID) memory)

DEBIAN_RESCUE_ID ?= demian-rescue-live
DEBIAN_RESCUE_PROFILE ?= $(shell $(PROFILE_INFO) $(DEBIAN_RESCUE_ID) profile_dir)
DEBIAN_RESCUE_ISO ?= $(shell $(PROFILE_INFO) $(DEBIAN_RESCUE_ID) iso)
DEBIAN_RESCUE_SERIAL_LOG ?= $(shell $(PROFILE_INFO) $(DEBIAN_RESCUE_ID) serial_log)
DEBIAN_RESCUE_MARKER ?= $(shell $(PROFILE_INFO) $(DEBIAN_RESCUE_ID) boot_marker)
DEBIAN_RESCUE_TIMEOUT ?= $(shell $(PROFILE_INFO) $(DEBIAN_RESCUE_ID) boot_timeout)
DEBIAN_RESCUE_MEMORY ?= $(shell $(PROFILE_INFO) $(DEBIAN_RESCUE_ID) memory)

UBUNTU_AUTOINSTALL_ID ?= demuntu-server-autoinstall
UBUNTU_BASE_ALIAS ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) base_alias)
UBUNTU_BASE_ISO ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) base_iso)
UBUNTU_AUTOINSTALL_PROFILE ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) profile_dir)
UBUNTU_AUTOINSTALL_ISO ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) iso)
UBUNTU_AUTOINSTALL_SCREENSHOT ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) screenshot)
UBUNTU_AUTOINSTALL_DISK ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) disk)
UBUNTU_AUTOINSTALL_CPUS ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) install_cpus)
UBUNTU_AUTOINSTALL_SERIAL_LOG ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) install_serial_log)
UBUNTU_INSTALLED_BOOT_SERIAL_LOG ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) boot_serial_log)
UBUNTU_INSTALLED_MARKER ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) boot_marker)
UBUNTU_INSTALL_TIMEOUT ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) install_timeout)
UBUNTU_INSTALL_COMPLETE_MARKER ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) install_complete_marker)
UBUNTU_INSTALL_BOOT_TIMEOUT ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) install_boot_timeout)
UBUNTU_AUTOINSTALL_MEMORY ?= $(shell $(PROFILE_INFO) $(UBUNTU_AUTOINSTALL_ID) memory)

UBUNTU_DESKTOP_ID ?= demuntu-desktop-live
UBUNTU_DESKTOP_BASE_ALIAS ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) base_alias)
UBUNTU_DESKTOP_BASE_ISO ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) base_iso)
UBUNTU_DESKTOP_PROFILE ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) profile_dir)
UBUNTU_DESKTOP_ISO ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) iso)
UBUNTU_DESKTOP_SERIAL_LOG ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) serial_log)
UBUNTU_DESKTOP_MARKER ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) boot_marker)
UBUNTU_DESKTOP_TIMEOUT ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) boot_timeout)
UBUNTU_DESKTOP_MEMORY ?= $(shell $(PROFILE_INFO) $(UBUNTU_DESKTOP_ID) memory)

UBUNTU_MATE_ID ?= demuntu-desktop-mate-live
UBUNTU_MATE_BASE_ALIAS ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) base_alias)
UBUNTU_MATE_BASE_ISO ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) base_iso)
UBUNTU_MATE_PROFILE ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) profile_dir)
UBUNTU_MATE_ISO ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) iso)
UBUNTU_MATE_SERIAL_LOG ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) serial_log)
UBUNTU_MATE_MARKER ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) boot_marker)
UBUNTU_MATE_TIMEOUT ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) boot_timeout)
UBUNTU_MATE_MEMORY ?= $(shell $(PROFILE_INFO) $(UBUNTU_MATE_ID) memory)

.PHONY: help spins profiles manifest check-host install-deps packages repo \
	demian-server-live demian-server-live-test \
	demian-desktop-live demian-desktop-live-test \
	demian-rescue-live demian-rescue-live-test \
	debian-live-server debian-live-server-test \
	debian-desktop-live debian-desktop-live-test \
	debian-rescue-live debian-rescue-live-test \
	ubuntu-base demuntu-server-autoinstall demuntu-server-autoinstall-boot-test demuntu-server-autoinstall-install \
	demuntu-server-node-developer-install demuntu-server-python-developer-install demuntu-server-dotnet-developer-install \
	demuntu-server-git-gui-tools-install demuntu-server-docker-gui-tools-install \
	ubuntu-server-autoinstall ubuntu-server-autoinstall-boot-test ubuntu-server-autoinstall-install \
	ubuntu-desktop-base demuntu-desktop-live demuntu-desktop-live-test \
	demuntu-desktop-mate-live demuntu-desktop-mate-live-test \
	ubuntu-desktop-live ubuntu-desktop-live-test \
	clean-work clean-cache clean-artifacts clean-build

help:
	@printf '%s\n' \
		'Targets:' \
		'  spins                         Render configs/spins/*.toml into profile env files' \
		'  profiles                      List configured ISO profiles' \
		'  manifest                      Write dist/manifest.json artifact inventory' \
		'  check-host                    Check required host tooling' \
		'  install-deps                  Install build dependencies with apt' \
		'  packages                      Build Demian and Demuntu packages' \
		'  repo                          Build local APT repo from dist/packages/*.deb' \
		'  demian-server-live            Build Demian live server ISO' \
		'  demian-server-live-test       Assert Demian server reaches userspace in QEMU' \
		'  demian-desktop-live           Build Demian XFCE desktop live ISO' \
		'  demian-desktop-live-test      Assert Demian desktop reaches userspace in QEMU' \
		'  demian-rescue-live            Build Demian rescue live ISO' \
		'  demian-rescue-live-test       Assert Demian rescue reaches userspace in QEMU' \
		'  debian-live-server            Alias for demian-server-live' \
		'  debian-desktop-live           Alias for demian-desktop-live' \
		'  debian-rescue-live            Alias for demian-rescue-live' \
		'  ubuntu-base                   Download and verify Ubuntu Server base ISO' \
		'  demuntu-server-autoinstall    Build Demuntu Server autoinstall ISO' \
		'  demuntu-server-autoinstall-boot-test Capture a QEMU GRUB/menu screenshot' \
		'  demuntu-server-autoinstall-install Boot Demuntu autoinstall ISO with a disposable disk' \
		'  demuntu-server-node-developer-install Install Node Developer set and assert package checks' \
		'  demuntu-server-python-developer-install Install Python Developer set and assert package checks' \
		'  demuntu-server-dotnet-developer-install Install .NET Developer set and assert package checks' \
		'  demuntu-server-git-gui-tools-install Install Git GUI Tools set and assert package checks' \
		'  demuntu-server-docker-gui-tools-install Install Docker GUI Tools set and assert package checks' \
		'  ubuntu-server-autoinstall     Alias for demuntu-server-autoinstall' \
		'  ubuntu-desktop-base           Download and verify Ubuntu Desktop base ISO' \
		'  demuntu-desktop-live          Build Demuntu Desktop live ISO' \
		'  demuntu-desktop-live-test     Assert Demuntu Desktop live reaches userspace in QEMU' \
		'  demuntu-desktop-mate-live     Build Demuntu Desktop MATE live ISO' \
		'  demuntu-desktop-mate-live-test Assert Demuntu Desktop MATE reaches userspace in QEMU' \
		'  ubuntu-desktop-live           Alias for demuntu-desktop-live' \
		'  clean-work                    Remove temporary build trees and test disks' \
		'  clean-cache                   Remove downloaded upstream base ISOs' \
		'  clean-artifacts               Remove generated artifacts; requires CONFIRM_DELETE_ARTIFACTS=yes' \
		'  clean-build                   Alias for clean-work'

spins:
	python3 ./scripts/common/render-spins.py

profiles:
	$(PROFILE_INFO) list

manifest:
	python3 ./scripts/common/write-manifest.py

check-host:
	./scripts/common/check-host.sh

install-deps:
	./scripts/common/install-deps.sh all

packages:
	rm -f dist/packages/*.deb dist/packages/*.buildinfo dist/packages/*.changes
	./scripts/packages/build-meta.sh packages/meta/demian-meta
	./scripts/packages/build-meta.sh packages/meta/demuntu-meta

repo: packages
	./scripts/repos/build-apt-repo.sh

demian-server-live:
	./scripts/debian/build-live.sh "$(DEBIAN_LIVE_PROFILE)"

demian-server-live-test: $(DEBIAN_LIVE_ISO)
	./scripts/test/boot-iso.sh \
		--headless \
		--memory "$(DEBIAN_LIVE_MEMORY)" \
		--timeout "$(DEBIAN_LIVE_TIMEOUT)" \
		--expect-serial "$(DEBIAN_LIVE_MARKER)" \
		--serial-log "$(DEBIAN_LIVE_SERIAL_LOG)" \
		"$(DEBIAN_LIVE_ISO)"

debian-live-server: demian-server-live

debian-live-server-test: demian-server-live-test

demian-desktop-live:
	./scripts/debian/build-live.sh "$(DEBIAN_DESKTOP_PROFILE)"

demian-desktop-live-test: $(DEBIAN_DESKTOP_ISO)
	./scripts/test/boot-iso.sh \
		--headless \
		--memory "$(DEBIAN_DESKTOP_MEMORY)" \
		--timeout "$(DEBIAN_DESKTOP_TIMEOUT)" \
		--expect-serial "$(DEBIAN_DESKTOP_MARKER)" \
		--serial-log "$(DEBIAN_DESKTOP_SERIAL_LOG)" \
		"$(DEBIAN_DESKTOP_ISO)"

debian-desktop-live: demian-desktop-live

debian-desktop-live-test: demian-desktop-live-test

demian-rescue-live:
	./scripts/debian/build-live.sh "$(DEBIAN_RESCUE_PROFILE)"

demian-rescue-live-test: $(DEBIAN_RESCUE_ISO)
	./scripts/test/boot-iso.sh \
		--headless \
		--memory "$(DEBIAN_RESCUE_MEMORY)" \
		--timeout "$(DEBIAN_RESCUE_TIMEOUT)" \
		--expect-serial "$(DEBIAN_RESCUE_MARKER)" \
		--serial-log "$(DEBIAN_RESCUE_SERIAL_LOG)" \
		"$(DEBIAN_RESCUE_ISO)"

debian-rescue-live: demian-rescue-live

debian-rescue-live-test: demian-rescue-live-test

$(UBUNTU_BASE_ISO):
	./scripts/common/fetch-iso.sh "$(UBUNTU_BASE_ALIAS)"

ubuntu-base: $(UBUNTU_BASE_ISO)

$(UBUNTU_AUTOINSTALL_ISO): $(UBUNTU_BASE_ISO)
	./scripts/ubuntu/build-server-autoinstall.sh \
		"$(UBUNTU_BASE_ISO)" \
		"$(UBUNTU_AUTOINSTALL_PROFILE)"

demuntu-server-autoinstall: $(UBUNTU_BASE_ISO)
	./scripts/ubuntu/build-server-autoinstall.sh \
		"$(UBUNTU_BASE_ISO)" \
		"$(UBUNTU_AUTOINSTALL_PROFILE)"

demuntu-server-autoinstall-boot-test: $(UBUNTU_AUTOINSTALL_ISO)
	./scripts/test/boot-iso.sh \
		--headless \
		--memory "$(UBUNTU_AUTOINSTALL_MEMORY)" \
		--screendump "$(UBUNTU_AUTOINSTALL_SCREENSHOT)" \
		--boot-wait 20 \
		"$(UBUNTU_AUTOINSTALL_ISO)"

demuntu-server-autoinstall-install: $(UBUNTU_AUTOINSTALL_ISO)
	./scripts/test/install-iso.sh \
		--headless \
		--memory "$(UBUNTU_AUTOINSTALL_MEMORY)" \
		--cpus "$(UBUNTU_AUTOINSTALL_CPUS)" \
		--disk "$(UBUNTU_AUTOINSTALL_DISK)" \
		--timeout "$(UBUNTU_INSTALL_TIMEOUT)" \
		--install-complete-serial "$(UBUNTU_INSTALL_COMPLETE_MARKER)" \
		--boot-timeout "$(UBUNTU_INSTALL_BOOT_TIMEOUT)" \
		--machine "q35" \
		--abort-on-serial "BUG:" \
		--serial-log "$(UBUNTU_AUTOINSTALL_SERIAL_LOG)" \
		--boot-serial-log "$(UBUNTU_INSTALLED_BOOT_SERIAL_LOG)" \
		--expect-serial "$(UBUNTU_INSTALLED_MARKER)" \
		--boot-check-on-timeout \
		"$(UBUNTU_AUTOINSTALL_ISO)"

demuntu-server-node-developer-install: $(UBUNTU_AUTOINSTALL_ISO)
	./scripts/test/install-iso.sh \
		--headless \
		--memory "$(UBUNTU_AUTOINSTALL_MEMORY)" \
		--cpus "$(UBUNTU_AUTOINSTALL_CPUS)" \
		--disk "build/test/demuntu-server-node-developer.qcow2" \
		--disk-size "30G" \
		--timeout "5400" \
		--install-complete-serial "$(UBUNTU_INSTALL_COMPLETE_MARKER)" \
		--boot-timeout "480" \
		--machine "q35" \
		--abort-on-serial "BUG:" \
		--serial-log "dist/images/demuntu-server-node-developer-install-serial.log" \
		--boot-serial-log "dist/images/demuntu-server-node-developer-boot-serial.log" \
		--expect-serial "DEMUNTU_NODE_DEVELOPER_READY" \
		--boot-check-on-timeout \
		--boot-sendkeys "down,down,ret" \
		--boot-sendkey-delay "5" \
		"$(UBUNTU_AUTOINSTALL_ISO)"

demuntu-server-python-developer-install: $(UBUNTU_AUTOINSTALL_ISO)
	./scripts/test/install-iso.sh \
		--headless \
		--memory "$(UBUNTU_AUTOINSTALL_MEMORY)" \
		--cpus "$(UBUNTU_AUTOINSTALL_CPUS)" \
		--disk "build/test/demuntu-server-python-developer.qcow2" \
		--disk-size "30G" \
		--timeout "5400" \
		--install-complete-serial "$(UBUNTU_INSTALL_COMPLETE_MARKER)" \
		--boot-timeout "480" \
		--machine "q35" \
		--abort-on-serial "BUG:" \
		--serial-log "dist/images/demuntu-server-python-developer-install-serial.log" \
		--boot-serial-log "dist/images/demuntu-server-python-developer-boot-serial.log" \
		--expect-serial "DEMUNTU_PYTHON_DEVELOPER_READY" \
		--boot-check-on-timeout \
		--boot-sendkeys "down,down,down,ret" \
		--boot-sendkey-delay "5" \
		"$(UBUNTU_AUTOINSTALL_ISO)"

demuntu-server-dotnet-developer-install: $(UBUNTU_AUTOINSTALL_ISO)
	./scripts/test/install-iso.sh \
		--headless \
		--memory "$(UBUNTU_AUTOINSTALL_MEMORY)" \
		--cpus "$(UBUNTU_AUTOINSTALL_CPUS)" \
		--disk "build/test/demuntu-server-dotnet-developer.qcow2" \
		--disk-size "40G" \
		--timeout "7200" \
		--install-complete-serial "$(UBUNTU_INSTALL_COMPLETE_MARKER)" \
		--boot-timeout "600" \
		--machine "q35" \
		--abort-on-serial "BUG:" \
		--serial-log "dist/images/demuntu-server-dotnet-developer-install-serial.log" \
		--boot-serial-log "dist/images/demuntu-server-dotnet-developer-boot-serial.log" \
		--expect-serial "DEMUNTU_DOTNET_DEVELOPER_READY" \
		--boot-check-on-timeout \
		--boot-sendkeys "down,down,down,down,ret" \
		--boot-sendkey-delay "5" \
		"$(UBUNTU_AUTOINSTALL_ISO)"

demuntu-server-git-gui-tools-install: $(UBUNTU_AUTOINSTALL_ISO)
	./scripts/test/install-iso.sh \
		--headless \
		--memory "$(UBUNTU_AUTOINSTALL_MEMORY)" \
		--cpus "$(UBUNTU_AUTOINSTALL_CPUS)" \
		--disk "build/test/demuntu-server-git-gui-tools.qcow2" \
		--disk-size "40G" \
		--timeout "7200" \
		--install-complete-serial "$(UBUNTU_INSTALL_COMPLETE_MARKER)" \
		--boot-timeout "600" \
		--machine "q35" \
		--abort-on-serial "BUG:" \
		--serial-log "dist/images/demuntu-server-git-gui-tools-install-serial.log" \
		--boot-serial-log "dist/images/demuntu-server-git-gui-tools-boot-serial.log" \
		--expect-serial "DEMUNTU_GIT_GUI_TOOLS_READY" \
		--boot-check-on-timeout \
		--boot-sendkeys "down,down,down,down,down,ret" \
		--boot-sendkey-delay "5" \
		"$(UBUNTU_AUTOINSTALL_ISO)"

demuntu-server-docker-gui-tools-install: $(UBUNTU_AUTOINSTALL_ISO)
	./scripts/test/install-iso.sh \
		--headless \
		--memory "$(UBUNTU_AUTOINSTALL_MEMORY)" \
		--cpus "$(UBUNTU_AUTOINSTALL_CPUS)" \
		--disk "build/test/demuntu-server-docker-gui-tools.qcow2" \
		--disk-size "40G" \
		--timeout "7200" \
		--install-complete-serial "$(UBUNTU_INSTALL_COMPLETE_MARKER)" \
		--boot-timeout "600" \
		--machine "q35" \
		--abort-on-serial "BUG:" \
		--serial-log "dist/images/demuntu-server-docker-gui-tools-install-serial.log" \
		--boot-serial-log "dist/images/demuntu-server-docker-gui-tools-boot-serial.log" \
		--expect-serial "DEMUNTU_DOCKER_GUI_TOOLS_READY" \
		--boot-check-on-timeout \
		--boot-sendkeys "down,down,down,down,down,down,ret" \
		--boot-sendkey-delay "5" \
		"$(UBUNTU_AUTOINSTALL_ISO)"

ubuntu-server-autoinstall: demuntu-server-autoinstall

ubuntu-server-autoinstall-boot-test: demuntu-server-autoinstall-boot-test

ubuntu-server-autoinstall-install: demuntu-server-autoinstall-install

$(UBUNTU_DESKTOP_BASE_ISO):
	./scripts/common/fetch-iso.sh "$(UBUNTU_DESKTOP_BASE_ALIAS)"

ubuntu-desktop-base: $(UBUNTU_DESKTOP_BASE_ISO)

$(UBUNTU_DESKTOP_ISO): $(UBUNTU_DESKTOP_BASE_ISO)
	./scripts/ubuntu/build-desktop-live.sh \
		"$(UBUNTU_DESKTOP_BASE_ISO)" \
		"$(UBUNTU_DESKTOP_PROFILE)"

demuntu-desktop-live: $(UBUNTU_DESKTOP_BASE_ISO)
	./scripts/ubuntu/build-desktop-live.sh \
		"$(UBUNTU_DESKTOP_BASE_ISO)" \
		"$(UBUNTU_DESKTOP_PROFILE)"

demuntu-desktop-live-test: $(UBUNTU_DESKTOP_ISO)
	./scripts/test/boot-iso.sh \
		--headless \
		--memory "$(UBUNTU_DESKTOP_MEMORY)" \
		--timeout "$(UBUNTU_DESKTOP_TIMEOUT)" \
		--expect-serial "$(UBUNTU_DESKTOP_MARKER)" \
		--serial-log "$(UBUNTU_DESKTOP_SERIAL_LOG)" \
		"$(UBUNTU_DESKTOP_ISO)"

demuntu-desktop-mate-live: $(UBUNTU_MATE_BASE_ISO)
	./scripts/ubuntu/build-desktop-live.sh \
		"$(UBUNTU_MATE_BASE_ISO)" \
		"$(UBUNTU_MATE_PROFILE)"

$(UBUNTU_MATE_ISO): $(UBUNTU_MATE_BASE_ISO)
	./scripts/ubuntu/build-desktop-live.sh \
		"$(UBUNTU_MATE_BASE_ISO)" \
		"$(UBUNTU_MATE_PROFILE)"

demuntu-desktop-mate-live-test: $(UBUNTU_MATE_ISO)
	./scripts/test/boot-iso.sh \
		--headless \
		--memory "$(UBUNTU_MATE_MEMORY)" \
		--timeout "$(UBUNTU_MATE_TIMEOUT)" \
		--expect-serial "$(UBUNTU_MATE_MARKER)" \
		--serial-log "$(UBUNTU_MATE_SERIAL_LOG)" \
		"$(UBUNTU_MATE_ISO)"

ubuntu-desktop-live: demuntu-desktop-live

ubuntu-desktop-live-test: demuntu-desktop-live-test

clean-work:
	./scripts/common/clean.sh work

clean-cache:
	./scripts/common/clean.sh cache

clean-artifacts:
	./scripts/common/clean.sh artifacts

clean-build: clean-work
