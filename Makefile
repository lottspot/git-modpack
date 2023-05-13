PROG          := git-configpack
INSTALLER_UID := $(shell id -u)

# System context
INSTALL_MODE        := system
prefix               = /usr/local
found_pkgdir         = $(firstword $(wildcard /opt /usr/local/opt))
pkgdir               = $(or $(found_pkgdir),$(prefix))
distdir              = $(DESTDIR)$(pkgdir)/$(PROG)
bindir               = $(prefix)/bin

# User context
user_distdir         = $(CURDIR)
user_bindir          = $(firstword $(wildcard $(HOME)/.local/bin $(HOME)/.bin $(HOME)/bin))

ifneq ($(INSTALLER_UID),0)
ifeq ($(DESTDIR),)
ifneq ($(user_bindir),)

INSTALL_MODE        := user
distdir              = $(user_distdir)
bindir               = $(user_bindir)

endif
endif
endif

INSTALL_BIN_SYMLINK   = $(patsubst $(DESTDIR)%,%,$(distdir))/bin/$(PROG)
INSTALL_BIN_DEST      = $(DESTDIR)$(bindir)/$(PROG)
INSTALL_BIN_DIR       = $(dir $(INSTALL_BIN_DEST))

install: $(INSTALL_BIN_DEST) $(distdir)

uninstall:
	rm -v -f $(INSTALL_BIN_DEST)
ifeq ($(INSTALL_MODE),system)
	rm -rf $(distdir)
endif

$(INSTALL_BIN_DEST): | $(INSTALL_BIN_DIR)
	ln -v -s '$(INSTALL_BIN_SYMLINK)' '$(INSTALL_BIN_DEST)'

$(INSTALL_BIN_DIR):
	mkdir -v -p '$@'

$(distdir):
	mkdir -v -p '$@'
	cp -r * '$@'

.PHONY: install
.PHONY: uninstall
