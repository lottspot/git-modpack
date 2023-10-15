SHELL  := bash
SUITES :=
TESTS  :=

help:

include packlib-path.mk

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
