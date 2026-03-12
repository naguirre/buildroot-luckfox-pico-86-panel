################################################################################
#
# aic8800dc-wifi
#
################################################################################

AIC8800DC_WIFI_VERSION = 1.0
AIC8800DC_WIFI_SITE = $(BR2_EXTERNAL_LUCKFOX_86PANEL_PATH)/package/aic8800dc-wifi/src
AIC8800DC_WIFI_SITE_METHOD = local
AIC8800DC_WIFI_LICENSE = PROPRIETARY
AIC8800DC_WIFI_LICENSE_FILES =

AIC8800DC_WIFI_MODULE_MAKE_OPTS = \
	CONFIG_AIC8800_BTLPM_SUPPORT=m \
	CONFIG_AIC8800_WLAN_SUPPORT=m \
	CONFIG_AIC_WLAN_SUPPORT=m \
	KCFLAGS="-Wno-error"

# Install firmware blobs to /lib/firmware/aic8800dc/
define AIC8800DC_WIFI_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/lib/firmware/aic8800dc
	cp -f $(@D)/aic8800dc_fw/*.bin $(TARGET_DIR)/lib/firmware/aic8800dc/
	cp -f $(@D)/aic8800dc_fw/*.txt $(TARGET_DIR)/lib/firmware/aic8800dc/
endef

$(eval $(kernel-module))
$(eval $(generic-package))
