SUITES        += packlib-path
LIBPATH_TESTS += packlib-path-realpath
LIBPATH_TESTS += packlib-path-relto
TESTS         += $(LIBPATH_TESTS)

packlib-path: $(LIBPATH_TESTS)

packlib-path-realpath:
	source ../install.sh && if path_realpath ''; then false; fi # an empty patharg should return nonzero
	source ../install.sh && if path_realpath /$(shell dd if=/dev/urandom bs=1 count=15 2>/dev/null | base64 -w0); then false; fi # non-existent paths should return nonzero
	source ../install.sh && test "`path_realpath .`" = '$(shell realpath `pwd` 2>/dev/null || readlink `pwd` 2>/dev/null || pwd)'
	source ../install.sh && test "`path_realpath /`" = '/'
	source ../install.sh && path_realpath /bin

packlib-path-relto:
	source ../install.sh && test "`path_relto .. .`" = ..
	source ../install.sh && test "`path_relto . ..`" = ./tests
	source ../install.sh && test "`path_relto . .`"  = .
	source ../install.sh && test "`path_relto / /`"  = .
	source ../install.sh && test "`path_relto sub2/filename sub1`" = ../sub2/filename
	source ../install.sh && echo "`path_relto / .`"
	source ../install.sh && echo "`path_relto . /`"
	source ../install.sh && echo "`path_relto / ..`"
	source ../install.sh && echo "`path_relto .. /`"
