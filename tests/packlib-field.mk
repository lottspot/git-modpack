SUITES          += packlib-field
LIBFIELD_TESTS  += packlib-field-add
LIBFIELD_TESTS  += packlib-field-get
LIBFIELD_TESTS  += packlib-field-getall
TESTS           += $(LIBFIELD_TESTS)

packlib-field: $(LIBFIELD_TESTS)

packlib-field-add:
	source ../install.sh && field_add foo.bar baz && test "$${_FIELDS[foo.bar]}" = baz

packlib-field-get:
	source ../install.sh && _FIELDS[foo.bar]=baz && test "`field_get foo.bar`" = baz

packlib-field-getall:
	source ../install.sh && fields_load ./packlib-field.ini && test bar = "`field_get_all test.getall.foo | sed -n 1p`"
	source ../install.sh && fields_load ./packlib-field.ini && test baz = "`field_get_all test.getall.foo | sed -n 2p`"
	source ../install.sh && fields_load ./packlib-field.ini && test qux = "`field_get_all test.getall.foo | sed -n 3p`"
