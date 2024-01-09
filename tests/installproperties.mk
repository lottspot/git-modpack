SUITES         += installproperties
INSTPROP_TESTS += installproperties-defaults
TESTS          += $(INSTPROP_TESTS)

installproperties: $(INSTPROP_TESTS)

installproperties-defaults:
	test "`$(SHELL) ../install.sh --get-property package.name`" = configpack
	test "`$(SHELL) ../install.sh --get-property package.configsdir`" = configs
	test "`$(SHELL) ../install.sh --get-property package.libexecdir`" = libexec
	test "`$(SHELL) ../install.sh --get-property install.pre`" = ""
	test "`$(SHELL) ../install.sh --get-property install.post`" = ""
	grep -E 'global|local' <<< "`$(SHELL) ../install.sh --get-property install.scope`" >/dev/null
