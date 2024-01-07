SHELL          := bash
SUITES         :=
TESTS          :=
CACHEDIRS      :=
REQUIRES_SETUP :=
TEARDOWN       :=

help:

include packlib-path.mk
include packlib-env.mk
include packlib-envfile.mk
include packlib-property.mk
include installproperties.mk
include configpack-init.mk

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

suites: $(SUITES)
$(TESTS): setup
$(REQUIRES_SETUP): setup

setup:
	$(if $(CACHEDIRS),mkdir -p $(CACHEDIRS))

teardown: $(TEARDOWN)
	$(if $(CACHEDIRS),rm -rf $(CACHEDIRS))

clean: teardown

.PHONY: suites
.PHONY: setup
.PHONY: teardown
.PHONY: clean
.PHONY: $(SUITES)
.PHONY: $(TESTS)
