libenvfile_tests += packlib-envfile-strs
SUITES           += packlib-envfile
TESTS            += $(libenvfile_tests)

libenvfile_run := source ../install.sh &&

packlib-envfile: $(libenvfile_tests)

packlib-envfile-strs:
	if ($(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^$$'); then false; fi # empty lines should be excluded
	if ($(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep 'this line started with #'); then false; fi # comments should be excluded
	if ($(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep 'this line started with ;'); then false; fi # comments should be excluded
	if ($(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep 'this line has no equal sign'); then false; fi # invalid definitions should be excluded
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^INNER_WHITESPACE=is preserved$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINING_WHITESPACE=stripped$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^KEYNAME_WHITESPACE=stripped$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINING_DOUBLE_QUOTE=stripped$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINING_SINGLE_QUOTE=stripped$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINED_DOUBLE_QUOTE="preserved"$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep "^CONTAINED_SINGLE_QUOTE='preserved'\$$"
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^ESCAPED_DOUBLE_QUOTE_SHELLCHARS="`\$$$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^ESCAPED_DOUBLE_QUOTE_WHITESPACE=is\\ preserved$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^UNESCAPED_SINGLE_QUOTE_SHELLCHARS="`\$$$$'
	$(libenvfile_run) env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^ESCAPED_INNER_WHITESPACE=\\ char stripped$$'
	test "`printf 'MULTILINE_SINGLE_QUOTE=newlines in value\n preserved\n'`" = "`source ../install.sh && env_file_strs ./packlib-envfile.env | while IFS= read -r -d $$'\0' envstr; do echo "$$envstr"; done | sed -n '/^MULTILINE_SINGLE_QUOTE/,+1p'`"
	test "`printf 'MULTILINE_DOUBLE_QUOTE=newlines in value\n preserved\n'`" = "`source ../install.sh && env_file_strs ./packlib-envfile.env | while IFS= read -r -d $$'\0' envstr; do echo "$$envstr"; done | sed -n '/^MULTILINE_DOUBLE_QUOTE/,+1p'`"
