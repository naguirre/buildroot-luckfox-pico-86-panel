# Kbuild-only Makefile — Buildroot kernel-module infra handles
# ARCH, CROSS_COMPILE, KDIR, and the 'modules' target automatically.

CONFIG_AIC8800_BTLPM_SUPPORT := m
CONFIG_AIC8800_WLAN_SUPPORT := m
CONFIG_AIC_WLAN_SUPPORT := m

obj-$(CONFIG_AIC_WLAN_SUPPORT) += aic8800_bsp/
obj-$(CONFIG_AIC8800_WLAN_SUPPORT) += aic8800_fdrv/
obj-$(CONFIG_AIC8800_BTLPM_SUPPORT) += aic8800_btlpm/

ccflags-y += -DCONFIG_PLATFORM_ROCKCHIP

