# This program requires an enviroonment which supports symlinks
DESTDIR ?=
PKGDIR  ?=
BINDIR  ?=

prog                  := git-configpack
destdir               := $(DESTDIR)
pkgdir                := $(PKGDIR)
bindir                := $(BINDIR)

pkgfiles              := $(shell          \
                         find . -type f   \
                         ! -path '*/.*'   \
                         ! -name Makefile )

# System context
prefix                := /usr/local
pkgrootdir            := $(firstword $(wildcard /opt /usr/local/opt) $(prefix))

pkgdir                := $(or $(pkgdir),$(pkgrootdir)/$(prog))
bindir                := $(or $(bindir),$(prefix)/bin)

ifeq ($(shell id -u),0)
have_super = 1
endif

# User context
ifeq ($(or $(DESTDIR),$(have_super)),)
prefix                 = $(HOME)/.local
pkgrootdir             = $(HOME)
user_bindir            = $(firstword $(wildcard $(HOME)/.local/bin $(HOME)/.bin $(HOME)/bin) $(HOME)/.bin)

pkgdir                := $(if $(PKGDIR),$(pkgdir),$(pkgrootdir)/.$(prog))
bindir                := $(if $(BINDIR),$(bindir),$(user_bindir))
endif

install_symlink_target = $(patsubst $(destdir)%,%,$(pkgdir))/bin/$(prog)
install_symlink_path   = $(destdir)$(bindir)/$(prog)
install_symlink_dir    = $(dir $(install_symlink_path))
install_pkg_dir        = $(destdir)$(pkgdir)
install_pkg_paths      = $(patsubst %,$(install_pkg_dir)/%,$(pkgfiles))

install : $(install_pkg_paths)
install : $(install_symlink_path)

$(install_pkg_paths):
	mkdir -p "`dirname '$@'`"
	cp -p '$(patsubst $(install_pkg_dir)/%,%,$@)' '$@'

MAKEFLAGS += -L
$(install_symlink_path):
	mkdir -p "`dirname '$@'`"
	ln -v -s '$(install_symlink_target)' '$(install_symlink_path)'
ifeq ($(shell printenv | grep -E 'PATH=(.+:)?$(bindir)(:|$$)'),)
	@echo WARN: To use this installation, you will need to add the following line to your shell\'s RC file: 'export PATH=$$PATH:$(bindir)' >&2
endif

uninstall:
ifneq ($(wildcard $(install_pkg_paths)),)
ifneq ($(call realpath,$(install_pkg_dir)),$(call realpath,$(CURDIR)))
	rm -v -f $(install_pkg_paths)
	while find '$(install_pkg_dir)' -empty -type d -print0 2>/dev/null | xargs -0 rmdir -v 2>/dev/null; do continue; done; true
endif
endif
ifneq ($(wildcard $(install_symlink_path)),)
	rm -v -f '$(install_symlink_path)'
endif

.PHONY: install
.PHONY: uninstall

realpath = $(shell                                         \
	   find '$(1)' -prune                              \
	   -exec realpath {}                         \; -o \
	   -exec readlink -f {}                      \; -o \
	   -exec sh -c 'cd "`readlink "{}"`" && pwd' \; -o \
	   -exec sh -c 'cd "$$(dirname "$$(readlink "{}")")" && printf "%s/%s\n" "`pwd`" "$$(basename "$$(readlink "{}")")"' \; -o \
	   -exec sh -c 'cd {} && pwd'                \; -o \
	   -exec sh -c 'cd "`dirname "{}"`" && printf "%s/%s\n" `pwd` "`basename "{}"`"' \; \
	   2>/dev/null                                     )
