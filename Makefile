DIST_FORMAT ?= tar

PROG      := git-configpack
VERSION   := $(shell git describe --tags --always HEAD)
RELEASE   := $(PROG)-$(VERSION)
DIST_NAME := $(RELEASE).$(DIST_FORMAT)

dist: $(DIST_NAME)

$(DIST_NAME):
	git archive -o '$@' \
		--worktree-attributes \
		--format=$(DIST_FORMAT) \
		--prefix=$(PROG)/ \
		--add-virtual-file=$(PROG)/VERSION:'$(VERSION)'$$'\n' \
		HEAD

check:
	$(MAKE) -C tests suites

clean:
	rm -f *.{tar,zip,tar.gz,tgz}
	$(MAKE) -C tests clean

.PHONY: dist
.PHONY: check
.PHONY: clean
