THEME     := omarchy-plus
STOCK     := omarchy
THEME_DIR := /usr/share/sddm/themes/$(THEME)
STOCK_DIR := /usr/share/sddm/themes/$(STOCK)
DROPIN    := /etc/sddm.conf.d/zz-$(THEME).conf
AUTOLOGIN := /etc/sddm.conf.d/autologin.conf

# Upright login screen on a 2-in-1. Independent of the theme install -- see
# install-autorotate.sh. ORIENT and OUTPUT use ?= so the environment and the
# command line can both override them.
ROTATE_DIR    := /usr/share/sddm/$(THEME)
ROTATE_LUA    := $(ROTATE_DIR)/hyprland.lua
ROTATE_DROPIN := /etc/sddm.conf.d/zz-$(THEME)-wayland.conf

ORIENT ?= normal
OUTPUT ?= eDP-1

.PHONY: help preview install install-no-auto-login uninstall status \
        install-autorotate uninstall-autorotate

help:
	@echo "Omarchy SDDM theme with session selector (installs as '$(THEME)')"
	@echo
	@echo "  make preview               run the theme in SDDM's greeter test mode"
	@echo "                             (nothing is installed)"
	@echo "  make install               install as $(THEME) and point SDDM at it"
	@echo "                             (the stock $(STOCK) theme is left alone)"
	@echo "  make install-no-auto-login comment out SDDM autologin so the greeter"
	@echo "                             is shown at login"
	@echo "  make uninstall             remove $(THEME) and fall back to $(STOCK)"
	@echo "  make install-autorotate    stop the login screen coming up rotated on a"
	@echo "                             2-in-1: start the greeter compositor at a fixed"
	@echo "                             orientation, and follow the accelerometer when"
	@echo "                             iio-sensor-proxy is installed. Independent of"
	@echo "                             'make install'."
	@echo "                               ORIENT=$(ORIENT) (normal|left-up|bottom-up|right-up)"
	@echo "                               OUTPUT=$(OUTPUT) (or auto)"
	@echo "  make uninstall-autorotate  remove it; back to the stock greeter config"
	@echo "  make status                show what is currently installed"

preview:
	@./preview.sh

install:
	@./install.sh

install-no-auto-login:
	@./disable-autologin.sh

uninstall:
	@./uninstall.sh

install-autorotate:
	@./install-autorotate.sh --orient '$(ORIENT)' --output '$(OUTPUT)'

uninstall-autorotate:
	@./uninstall-autorotate.sh

status:
	@echo "theme dir:  $(THEME_DIR)"
	@if [ -d "$(THEME_DIR)" ]; then \
		echo "  installed: yes"; \
	else \
		echo "  installed: no"; \
	fi
	@echo "selection:  $(DROPIN)"
	@if [ -f "$(DROPIN)" ]; then \
		echo "  present:   yes (Current=$(THEME))"; \
	else \
		echo "  present:   no (SDDM uses the omarchy-settings default)"; \
	fi
	@echo "stock:      $(STOCK_DIR)"
	@if [ -d "$(STOCK_DIR)" ]; then \
		echo "  present:   yes (untouched by this project)"; \
	else \
		echo "  present:   NO -- artwork symlinks will be broken"; \
	fi
	@echo "autologin:  $(AUTOLOGIN)"
	@if [ ! -f "$(AUTOLOGIN)" ]; then \
		echo "  state:     no autologin config"; \
	elif grep -qE '^[[:space:]]*(User|Session)[[:space:]]*=' "$(AUTOLOGIN)"; then \
		echo "  state:     ENABLED (greeter will not be shown)"; \
	else \
		echo "  state:     disabled (greeter will be shown)"; \
	fi
	@echo "autorotate: $(ROTATE_DROPIN)"
	@if [ -f "$(ROTATE_DROPIN)" ] && [ -f "$(ROTATE_LUA)" ]; then \
		echo "  compositor: overridden ($(ROTATE_LUA))"; \
	elif [ -f "$(ROTATE_DROPIN)" ]; then \
		echo "  compositor: BROKEN -- the override points at a missing"; \
		echo "              $(ROTATE_LUA), so the greeter will not start."; \
		echo "              Fix: sudo rm $(ROTATE_DROPIN)"; \
	elif [ -f "$(ROTATE_LUA)" ]; then \
		echo "  compositor: stock (the override is gone, so the config is unused)"; \
	else \
		echo "  compositor: stock (autorotate not installed)"; \
	fi
	@if [ -f "$(ROTATE_LUA)" ]; then \
		grep -m1 'omarchy-plus: output=' "$(ROTATE_LUA)" \
			| sed 's/^-- */  config:     /' || true; \
	fi
	@if command -v monitor-sensor >/dev/null 2>&1; then \
		echo "  sensor:     monitor-sensor present (automatic rotation active)"; \
	else \
		echo "  sensor:     monitor-sensor MISSING (fixed orientation only;"; \
		echo "              sudo pacman -S iio-sensor-proxy for automatic rotation)"; \
	fi
