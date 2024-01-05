SUITES         += installproperties
INSTPROP_TESTS += installproperties-defaults
TESTS          += $(INSTPROP_TESTS)

installproperties: $(INSTPROP_TESTS)

installproperties-defaults:
	test "`../install.sh --get-property package.name`" = configpack
	test "`../install.sh --get-property package.configsdir`" = configs
	test "`../install.sh --get-property package.libexecdir`" = libexec
	test "`../install.sh --get-property install.pre`" = ""
	test "`../install.sh --get-property install.post`" = ""
	grep -E 'global|local' <<< "`../install.sh --get-property install.scope`" >/dev/null
