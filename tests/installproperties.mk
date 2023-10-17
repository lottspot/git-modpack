SUITES         += installproperties
INSTPROP_TESTS += installproperties-defaults
TESTS          += $(INSTPROP_TESTS)

installproperties: $(INSTPROP_TESTS)

installproperties-defaults:
	test "`../share/install.sh --get-property package.name`" = share
	test "`../share/install.sh --get-property package.configsdir`" = .
	test "`../share/install.sh --get-property package.libexecdir`" = libexec
	test "`../share/install.sh --get-property install.pre`" = ""
	test "`../share/install.sh --get-property install.post`" = ""
	grep -E 'global|local' <<< "`../share/install.sh --get-property install.scope`" >/dev/null
