SUITES             += packlib-property
LIBPROPERTY_TESTS  += packlib-property-add
LIBPROPERTY_TESTS  += packlib-property-get
LIBPROPERTY_TESTS  += packlib-property-getall
TESTS              += $(LIBPROPERTY_TESTS)

packlib-property: $(LIBPROPERTY_TESTS)

packlib-property-add:
	source ../install.sh && property_add foo.bar baz && test "$${PROPERTIES[foo.bar]}" = baz

packlib-property-get:
	source ../install.sh && PROPERTIES[foo.bar]=baz && test "`property_get foo.bar`" = baz

packlib-property-getall:
	source ../install.sh && properties_load ./packlib-property.properties && test bar = "`property_get_all test.getall.foo | sed -n 1p`"
	source ../install.sh && properties_load ./packlib-property.properties && test baz = "`property_get_all test.getall.foo | sed -n 2p`"
	source ../install.sh && properties_load ./packlib-property.properties && test qux = "`property_get_all test.getall.foo | sed -n 3p`"
