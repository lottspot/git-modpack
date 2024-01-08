DIST_FORMAT ?= tar

PROG        := git-%pack_name%
VERSION     := $(shell git describe --tags --always HEAD)
RELEASE     := $(PROG)-$(VERSION)
DIST_NAME   := $(RELEASE).$(DIST_FORMAT)

dist: $(DIST_NAME)

check:
	true

clean:
	rm -f *.{tar,zip,tar.gz,tgz}

$(DIST_NAME):
	git archive -o '$@' \
		--worktree-attributes \
		--format=$(DIST_FORMAT) \
		--prefix=$(PROG)/ \
		HEAD

.PHONY: dist
.PHONY: check
.PHONY: clean
