THEME     := omarchy-plus
STOCK     := omarchy
THEME_DIR := /usr/share/sddm/themes/$(THEME)
STOCK_DIR := /usr/share/sddm/themes/$(STOCK)
DROPIN    := /etc/sddm.conf.d/zz-$(THEME).conf
AUTOLOGIN := /etc/sddm.conf.d/autologin.conf

.PHONY: help preview install install-no-auto-login uninstall status

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
	@echo "  make status                show what is currently installed"

preview:
	@./preview.sh

install:
	@./install.sh

install-no-auto-login:
	@./disable-autologin.sh

uninstall:
	@./uninstall.sh

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
