libpath_tests += packlib-path-realpath
libpath_tests += packlib-path-relfrom
SUITES        += packlib-path
TESTS         += $(libpath_tests)

libpath_run := source ../install.sh &&

packlib-path: $(libpath_tests)

packlib-path-realpath:
	$(libpath_run) if path_realpath ''; then false; fi # an empty patharg should return nonzero
	$(libpath_run) if path_realpath /$(shell dd if=/dev/urandom bs=1 count=15 2>/dev/null | base64 -w0); then false; fi # non-existent paths should return nonzero
	$(libpath_run) test "`path_realpath .`" = '$(shell realpath `pwd` 2>/dev/null || readlink `pwd` 2>/dev/null || pwd)'
	$(libpath_run) test "`path_realpath /`" = '/'
	$(libpath_run) path_realpath /bin

packlib-path-relfrom:
	$(libpath_run) test "`path_relfrom .. .`" = ..
	$(libpath_run) test "`path_relfrom . ..`" = ./tests
	$(libpath_run) test "`path_relfrom . .`"  = .
	$(libpath_run) test "`path_relfrom / /`"  = .
	$(libpath_run) test "`path_relfrom sub2/filename sub1`" = ../sub2/filename
	$(libpath_run) test "`path_relfrom a b/c`" = ../../a
	$(libpath_run) echo "`path_relfrom / .`"
	$(libpath_run) echo "`path_relfrom . /`"
	$(libpath_run) echo "`path_relfrom / ..`"
	$(libpath_run) echo "`path_relfrom .. /`"
