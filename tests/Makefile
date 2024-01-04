SHELL  := bash
SUITES :=
TESTS  :=

help:

include packlib-path.mk
include packlib-env.mk
include packlib-envfile.mk
include packlib-property.mk
include installproperties.mk

help:
	@echo
	@echo   'usage: make [suites|<SUITE>|<TEST>]...                              '
	@echo   '                                                                    '
	@echo   '    suites - run all suites                                         '
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

.PHONY: suites
.PHONY: $(SUITES)
.PHONY: $(TESTS)
