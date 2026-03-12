################################################################################
#
# calaos-remote-ui
#
################################################################################

CALAOS_REMOTE_UI_VERSION ?= main
CALAOS_REMOTE_UI_SITE ?= https://github.com/calaos/calaos_remote_ui
CALAOS_REMOTE_UI_SITE_METHOD = git
CALAOS_REMOTE_UI_GIT_SUBMODULES = YES

CALAOS_REMOTE_UI_LICENSE = GPL-3.0
CALAOS_REMOTE_UI_LICENSE_FILES = LICENSE

CALAOS_REMOTE_UI_DEPENDENCIES = mbedtls libdrm libevdev host-python3

# Exclude the luckfox buildroot submodule from rsync to avoid circular sync
# and pulling in the entire (huge) buildroot build output
CALAOS_REMOTE_UI_OVERRIDE_SRCDIR_RSYNC_EXCLUSIONS = \
	--exclude=boards/luckfox-86-panel/luckfox-pico-86-panel

CALAOS_REMOTE_UI_CONF_OPTS = \
	-DBUILD_LINUX=ON \
	-DBOARD=luckfox-86-panel \
	-DCMAKE_BUILD_TYPE=Release \
	-DPython3_EXECUTABLE=/usr/bin/python3 \
    -DBUILD_SHARED_LIBS=OFF

define CALAOS_REMOTE_UI_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(CALAOS_REMOTE_UI_PKGDIR)/S99calaos \
		$(TARGET_DIR)/etc/init.d/S99calaos
endef

define CALAOS_REMOTE_UI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/calaos-remote-ui \
		$(TARGET_DIR)/usr/bin/calaos-remote-ui
	$(CALAOS_REMOTE_UI_INSTALL_INIT_SYSV)
endef

$(eval $(cmake-package))
