libenv_tests  += packlib-env-addfile
libenv_tests  += packlib-env-addset
libenv_tests  += packlib-env-setupseq
libenv_tests  += packlib-env-exportseq
libenv_tests  += packlib-env-exec
SUITES        += packlib-env
TESTS         += $(libenv_tests)

libenv_run := source ../install.sh &&

packlib-env: $(libenv_tests)

packlib-env-addfile:
	$(libenv_run) env_file_add ./noop.env && test "$$ENV_FILES" = ./noop.env

packlib-env-addset:
	$(libenv_run) env_str_add FOO=BAR && test "$$ENV_STRS" = FOO=BAR

packlib-env-setupseq:
	$(libenv_run) ENV_STRS=(FOO=QUX) && ENV_FILES=(packlib-env.1.env packlib-env.2.env) && env_seq_setup && test $${ENV_SEQ[0]} = FOO=BAR && test $${ENV_SEQ[3]} = FOO=QUX
	$(libenv_run) ENV_STRS=(FOO=QUX) && ENV_FILES=(packlib-env.1.env packlib-env.2.env) && env_seq_setup && for e in "$${ENV_SEQ[@]}"; do declare -x "$$e"; done && test "$$FOO" = QUX && test "$$HELLO" = WORLD

packlib-env-exec:
	$(libenv_run) \
		ENV_STRS=(FOO=QUX) && \
		ENV_FILES=(packlib-env.1.env packlib-env.2.env) && \
		env_seq_setup && \
		env_exec printenv | grep FOO=QUX
	$(libenv_run) \
		ENV_FILES=(packlib-env.1.env packlib-env.2.env) && \
		env_seq_setup && \
		env_exec printenv | grep FOO=BAZ
	$(libenv_run) \
		ENV_STRS=(FOO=QUX) && \
		env_seq_setup && \
		ENV_IGNORE_ENVIRON=1 env_exec printenv | xargs expr FOO=QUX =
