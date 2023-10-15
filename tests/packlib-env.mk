SUITES        += packlib-env
LIBENV_TESTS  += packlib-env-addfile
LIBENV_TESTS  += packlib-env-addset
LIBENV_TESTS  += packlib-env-setupseq
LIBENV_TESTS  += packlib-env-exportseq
TESTS         += $(LIBENV_TESTS)

packlib-env: $(LIBENV_TESTS)

packlib-env-addfile:
	source ../share/install.sh && env_file_add ./noop.env && test "$$ENV_FILES" = ./noop.env

packlib-env-addset:
	source ../share/install.sh && env_set_add FOO=BAR && test "$$ENV_SETS" = FOO=BAR

packlib-env-setupseq:
	source ../share/install.sh && ENV_SETS=(FOO=QUX) && ENV_FILES=(packlib-env.1.env packlib-env.2.env) && env_seq_setup && test $${ENV_SEQ[0]} = FOO=BAR && test $${ENV_SEQ[3]} = FOO=QUX
	source ../share/install.sh && ENV_SETS=(FOO=QUX) && ENV_FILES=(packlib-env.1.env packlib-env.2.env) && env_seq_setup && for e in "$${ENV_SEQ[@]}"; do declare -x "$$e"; done && test "$$FOO" = QUX && test "$$HELLO" = WORLD
