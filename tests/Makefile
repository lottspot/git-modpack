SHELL          := bash
SUITES         :=
TESTS          :=
CACHEDIRS      :=
REQUIRES_SETUP :=
TEARDOWN       :=
TOPCACHE       := .cache

CACHEDIRS      += $(TOPCACHE)

help:

include packlib-path.mk
include packlib-env.mk
include packlib-envfile.mk
include packlib-field.mk
include installopts.mk
include modpack-init.mk

help:
	@echo
	@echo   'usage: make [<ACTION>|<SUITE>|<TEST>]...                            '
	@echo   '                                                                    '
	@echo   'Actions:                                                            '
	@echo   '                                                                    '
	@echo   '    suites   - run all suites                                       '
	@echo   '    setup    - initialize local environment                         '
	@echo   '    teardown - cleanup local environment                            '
	@echo   '                                                                    '
	@echo   'Suites:                                                             '
	@echo   '                                                                    '
	@printf '    %s                                                            \n' $(SUITES)
	@echo   '                                                                    '
	@echo   'Tests:                                                             '
	@echo   '                                                                    '
	@printf '    %s                                                            \n' $(TESTS)
	@echo

suites            : $(SUITES)
setup             : $(CACHEDIRS)
$(TESTS)          : setup
$(REQUIRES_SETUP) : setup

teardown: $(TEARDOWN)
	rm -rf $(CACHEDIRS)

clean: teardown

$(CACHEDIRS):
	mkdir -p '$@'

.PHONY: suites
.PHONY: setup
.PHONY: teardown
.PHONY: clean
.PHONY: $(SUITES)
.PHONY: $(TESTS)
