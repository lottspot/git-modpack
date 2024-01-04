SUITES           += packlib-envfile
LIBENVFILE_TESTS += packlib-envfile-strs
TESTS            += $(LIBENVFILE_TESTS)

packlib-envfile: $(LIBENVFILE_TESTS)

packlib-envfile-strs:
	if (source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^$$'); then false; fi # empty lines should be excluded
	if (source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep 'this line started with #'); then false; fi # comments should be excluded
	if (source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep 'this line started with ;'); then false; fi # comments should be excluded
	if (source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep 'this line has no equal sign'); then false; fi # invalid definitions should be excluded
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^INNER_WHITESPACE=is preserved$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINING_WHITESPACE=stripped$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^KEYNAME_WHITESPACE=stripped$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINING_DOUBLE_QUOTE=stripped$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINING_SINGLE_QUOTE=stripped$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^CONTAINED_DOUBLE_QUOTE="preserved"$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep "^CONTAINED_SINGLE_QUOTE='preserved'\$$"
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^ESCAPED_DOUBLE_QUOTE_SHELLCHARS="`\$$$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^ESCAPED_DOUBLE_QUOTE_WHITESPACE=is\\ preserved$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^UNESCAPED_SINGLE_QUOTE_SHELLCHARS="`\$$$$'
	source ../share/install.sh && env_file_strs ./packlib-envfile.env | tr '\0' '\n' | grep '^ESCAPED_INNER_WHITESPACE=\\ char stripped$$'
	test "`printf 'MULTILINE_SINGLE_QUOTE=newlines in value\n preserved\n'`" = "`source ../share/install.sh && env_file_strs ./packlib-envfile.env | while IFS= read -r -d $$'\0' envstr; do echo "$$envstr"; done | sed -n '/^MULTILINE_SINGLE_QUOTE/,+1p'`"
	test "`printf 'MULTILINE_DOUBLE_QUOTE=newlines in value\n preserved\n'`" = "`source ../share/install.sh && env_file_strs ./packlib-envfile.env | while IFS= read -r -d $$'\0' envstr; do echo "$$envstr"; done | sed -n '/^MULTILINE_DOUBLE_QUOTE/,+1p'`"
