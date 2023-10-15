SUITES        += packlib-path
LIBPATH_TESTS += packlib-path-realpath
LIBPATH_TESTS += packlib-path-relto
TESTS         += $(LIBPATH_TESTS)

packlib-path: $(LIBPATH_TESTS)

packlib-path-realpath:
	source ../share/install.sh && if path_realpath ''; then false; fi # an empty patharg should return nonzero
	source ../share/install.sh && if path_realpath /$(shell dd if=/dev/urandom bs=1 count=15 2>/dev/null | base64 -w0); then false; fi # non-existent paths should return nonzero
	source ../share/install.sh && test "`path_realpath .`" = '$(shell realpath `pwd` 2>/dev/null || readlink `pwd` 2>/dev/null || pwd)'
	source ../share/install.sh && test "`path_realpath /`" = '/'
	source ../share/install.sh && path_realpath /bin

packlib-path-relto:
	source ../share/install.sh && test "`path_relto .. .`" = ..
	source ../share/install.sh && test "`path_relto . ..`" = ./tests
	source ../share/install.sh && test "`path_relto . .`"  = .
	source ../share/install.sh && test "`path_relto / /`"  = .
	source ../share/install.sh && echo "`path_relto / .`"
	source ../share/install.sh && echo "`path_relto . /`"
	source ../share/install.sh && echo "`path_relto / ..`"
	source ../share/install.sh && echo "`path_relto .. /`"
