SUITES         += installopts
INSTOPT_TESTS  += installopts-defaults
TESTS          += $(INSTOPT_TESTS)

installopts: $(INSTOPT_TESTS)

installopts-defaults:
	test "`$(SHELL) ../install.sh --get-field package.name`" = modpack
	test "`$(SHELL) ../install.sh --get-field package.configsdir`" = configs
	test "`$(SHELL) ../install.sh --get-field package.progsdir`" = bin
	test "`$(SHELL) ../install.sh --get-field install.pre`" = ""
	test "`$(SHELL) ../install.sh --get-field install.post`" = ""
	grep -E 'global|local' <<< "`$(SHELL) ../install.sh --get-field install.scope`" >/dev/null
