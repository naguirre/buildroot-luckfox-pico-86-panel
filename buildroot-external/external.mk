include $(sort $(wildcard $(BR2_EXTERNAL_LUCKFOX_86PANEL_PATH)/package/*/*.mk))

UBOOT_MAKE_OPTS += KCFLAGS="-Wno-error=address -Wno-error=maybe-uninitialized -Wno-error=enum-int-mismatch"
LINUX_CFLAGS += -Wno-dangling-pointer

# Install RV1106-specific rkbin extras (blobs, INI files, host tools) that
# the upstream rockchip-rkbin package does not install by default.
define ROCKCHIP_RKBIN_INSTALL_RV1106_EXTRAS
	mkdir -p $(STAGING_DIR)/rkbin
	cp -a $(@D)/bin $(STAGING_DIR)/rkbin/
	cp -a $(@D)/RKBOOT $(STAGING_DIR)/rkbin/
	cp -a $(@D)/tools $(STAGING_DIR)/rkbin/
	install -m 755 $(@D)/tools/boot_merger $(HOST_DIR)/bin/
	install -m 755 $(@D)/tools/resource_tool $(HOST_DIR)/bin/
endef
ROCKCHIP_RKBIN_POST_INSTALL_IMAGES_HOOKS += ROCKCHIP_RKBIN_INSTALL_RV1106_EXTRAS
