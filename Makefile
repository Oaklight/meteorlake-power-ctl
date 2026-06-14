PREFIX ?= /usr
DESTDIR ?=

BIN_DIR = $(DESTDIR)$(PREFIX)/bin
CONF_DIR = $(DESTDIR)/etc/tlp.d
LICENSE_DIR = $(DESTDIR)$(PREFIX)/share/licenses/mtl-power-ctl

.PHONY: install uninstall help

install:
	install -Dm755 power-ctl $(BIN_DIR)/power-ctl
	install -Dm644 config/90-mtl-power-ctl.conf $(CONF_DIR)/90-mtl-power-ctl.conf
	install -Dm644 LICENSE $(LICENSE_DIR)/LICENSE

uninstall:
	rm -f $(PREFIX)/bin/power-ctl
	rm -f /etc/tlp.d/90-mtl-power-ctl.conf
	rm -rf $(PREFIX)/share/licenses/mtl-power-ctl

help:
	@echo "Available targets:"
	@echo "  install    - Install power-ctl and TLP config"
	@echo "  uninstall  - Remove power-ctl and TLP config"
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=<path>   - Installation prefix (default: /usr)"
	@echo "  DESTDIR=<path>  - Staging directory for packaging"
