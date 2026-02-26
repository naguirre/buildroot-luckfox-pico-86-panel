# ── U-Boot ────────────────────────────────────────────────────────────────────
# Suppress GCC 13/14 warnings-as-errors that the Rockchip U-Boot 2017.09 fork
# was not written to satisfy.  Using -Wno-error=X rather than -Wno-error so
# that any genuinely new warnings still show up during the build.
UBOOT_MAKE_OPTS += KCFLAGS="-Wno-error=address -Wno-error=maybe-uninitialized -Wno-error=enum-int-mismatch"

LINUX_CFLAGS += -Wno-dangling-pointer
