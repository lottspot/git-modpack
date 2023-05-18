# This program requires an enviroonment which supports symlinks
DESTDIR ?=
PKGDIR  ?=
BINDIR  ?=

prog                  := git-configpack
version               := $(shell git describe --always --dirty --tags 2>/dev/null)
destdir               := $(DESTDIR)
pkgdir                := $(PKGDIR)
bindir                := $(BINDIR)

pkgfiles              := $(shell            \
                         find . -type f     \
                         ! -path '*/.*'     \
                         ! -path './dist/*' \
                         ! -name Makefile   )

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
install_pkgver_path    = $(install_pkg_dir)/VERSION
dist_dir               = dist
dist_name              = $(prog)-$(version)
dist_path              = $(dist_dir)/$(dist_name).tar.gz

dist    : $(dist_path)
install : $(install_pkg_paths)
install : $(install_pkgver_path)
install : $(install_symlink_path)

$(dist_path):
	mkdir -p "`dirname '$@'`"
	git archive --format=tar.gz --prefix=$(dist_name)/ --add-virtual-file=$(dist_name)/VERSION:$(version) -o '$@' HEAD --

$(install_pkg_paths):
	mkdir -p "`dirname '$@'`"
	cp -p '$(patsubst $(install_pkg_dir)/%,%,$@)' '$@'

ifeq ($(filter $(install_pkgver_path),$(install_pkg_paths)),)
$(install_pkgver_path):
	printf '%s\n' '$(version)' > '$@'
endif

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
	rm -v -f $(install_pkg_paths) $(install_pkgver_path)
	while find '$(install_pkg_dir)' -empty -type d -print0 2>/dev/null | xargs -0 rmdir -v 2>/dev/null; do continue; done; true
endif
endif
ifneq ($(wildcard $(install_symlink_path)),)
	rm -v -f '$(install_symlink_path)'
endif

clean:
ifneq ($(wildcard $(dist_dir)/*),)
	rm -v -f '$(dist_dir)/'*
	rmdir -v '$(dist_dir)'
endif

.PHONY: dist
.PHONY: install
.PHONY: uninstall
.PHONY: clean

realpath = $(shell                                         \
	   find '$(1)' -prune                              \
	   -exec realpath {}                         \; -o \
	   -exec readlink -f {}                      \; -o \
	   -exec sh -c 'cd "`readlink "{}"`" && pwd' \; -o \
	   -exec sh -c 'cd "$$(dirname "$$(readlink "{}")")" && printf "%s/%s\n" "`pwd`" "$$(basename "$$(readlink "{}")")"' \; -o \
	   -exec sh -c 'cd {} && pwd'                \; -o \
	   -exec sh -c 'cd "`dirname "{}"`" && printf "%s/%s\n" `pwd` "`basename "{}"`"' \; \
	   2>/dev/null                                     )
