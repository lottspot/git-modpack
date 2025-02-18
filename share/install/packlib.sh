field_get()
{
  local field_name=$1
  printf '%s\n' "${_FIELDS[$field_name]}" | tail -n1
}

field_get_all()
{
  local field_name=$1
  printf '%s\n' "${_FIELDS[$field_name]}"
}

field_set()
{
  local field_name=$1
  local field_val=$2
  _FIELDS[$field_name]=$field_val
}

field_add()
{
  local field_name=$1
  local field_val=$2
  if [[ ${_FIELDS[$field_name]} ]]; then
    _FIELDS[$field_name]=$(printf '%s\n%s\n' "${_FIELDS[$field_name]}" "$field_val")
  else
    _FIELDS[$field_name]=$field_val
  fi
}

fields_load()
{
  for loadpath in "$@"; do
    while read field_name field_val; do
      test "$field_name" || continue
      field_add "$field_name" "$field_val"
    done <<< "$(git config -f "$loadpath" --get-regexp '.*')"
  done
}

fields_write()
{
  local dest=$1
  mkdir -p "$(dirname "$dest")"
  printf '# %s %s\n' 'vim:' 'filetype=gitconfig:' > "$dest"
  for field in "${!_FIELDS[@]}"; do
    local var=$field
    local val=${_FIELDS[$field]}
    git config -f "$dest" "$var" "$val"
  done
  printf '+ %s\n' "${NEWPACK_INI_PATH#$PACK_PATH/}"
}

fields_dump()
{
  for field_name in "${!_FIELDS[@]}"; do
    printf '%s %s\n' "$field_name" "${_FIELDS[$field_name]}";
  done
}

fields_list()
{
  local awk_prog='
BEGIN {
  maxlen=0
}
{
  fieldlen=length($1)
  if (fieldlen > maxlen) maxlen=fieldlen
  field[NR]=$1
  val[NR]=substr($0, fieldlen+2)
}
END {
  fstr = sprintf("%%-%ds  %%s\n", maxlen)
  for (i = 1; i <= NR; i++) printf(fstr, field[i], val[i])
}
'
awk "$awk_prog" <<< "$(fields_dump)"
}

declare -A _FIELDS

path_realpath()
{
  local patharg=$1
  find "$patharg" -prune                                  \
    -exec realpath {}                         \; -o \
    -exec readlink -f {}                      \; -o \
    -exec sh -c 'cd "`readlink "{}"`" && pwd' \; -o \
    -exec sh -c 'cd "$(dirname "$(readlink "{}")")" && printf "%s/%s\n" "`pwd`" "$(basename "$(readlink "{}")")"' \; -o \
    -exec sh -c 'cd {} && pwd'                \; -o \
    -exec sh -c 'cd "`dirname "{}"`" && printf "%s/%s\n" `pwd` "`basename "{}"`"' \; 2>/dev/null
}

path_norm()
{
  local patharg=$1
  local pathbase=
  local pathstem=
  while ! path_realpath "$patharg" >/dev/null 2>&1; do
    if [ "$patharg" = '/' ]; then
      if [[ $DEBUG ]]; then
        printf 'path_norm: failed to resolve %s/\n' "$1" >&2
      fi
      return 1
    fi
    pathstem="/$(basename "$patharg")$pathstem"
    patharg=$(dirname "$patharg")
  done
  pathbase=$(path_realpath "$patharg")
  test "$pathbase" != '/' || pathbase=
  printf '%s\n' "$pathbase$pathstem"
}

path_relfrom()
{
  local dest_path=$1
  local dest_norm=$(path_norm "$dest_path")
  local dest_stem=
  local origin_dir=$2
  local origin_norm=$(path_norm "$origin_dir")
  local origin_stem=
  local origin_traversal=
  local stem_i=

  local maxlen=
  if [[ ${#dest_norm} -gt ${#origin_norm} ]]; then
    maxlen=${#dest_norm}
  else
    maxlen=${#origin_norm}
  fi

  for (( i=0; i<=maxlen; i++ )); do

    if [[ $i -eq $maxlen ]]; then
      # paths are equal
      printf '.\n'
      return 0
    fi

    local dest_c=${dest_norm:$i:1}
    local origin_c=${origin_norm:$i:1}

    if [[ $dest_c == / ]] || [[ $origin_c == / ]]; then
      stem_i=`expr $i + 1`
    fi

    if [[ ! $dest_c ]] || [[ ! $origin_c ]]; then
      break
    fi

    if [[ $dest_c != $origin_c ]]; then
      break
    fi

  done

  dest_stem=${dest_norm:$stem_i}
  origin_stem=${origin_norm:$stem_i}

  local origin_levels=1
  for (( i=0; i<${#origin_stem}; i++ )); do
    local c=${origin_stem:$i:1}
    if [[ $c == / ]]; then
      origin_levels=`expr $origin_levels + 1`
    fi
  done

  for (( i=0; i<$origin_levels; i++ )); do
    origin_traversal+=../
  done

  if ! [[ $origin_stem ]]; then
    origin_traversal=./
  fi

  if ! [[ $dest_stem ]]; then
    origin_traversal=${origin_traversal%/}
  fi

  printf '%s%s\n' "$origin_traversal" "$dest_stem"
}

_env_seq_setup()
{
  local env_files_seq=()
  while IFS= read -r -d $'\0' envstr; do
    env_files_seq+=("$envstr")
  done < <(env_file_strs "${ENV_FILES[@]}")

  ENV_SEQ=( "${env_files_seq[@]}" "${ENV_STRS[@]}" )
}

env_file_add()
{
  for env_file_path in "$@"; do
    ENV_FILES+=("$env_file_path")
  done
}

env_file_reset()
{
  ENV_FILES=()
}

env_file_strs()
{
  local awk_prog='
BEGIN {
  if (!strsep) exit 1;
  WHITESPACE        = " \t\n\r"
  COMMENTS          = "#;"
  SHELL_NEED_ESCAPE = "\"\\`$"
  state             = "PRE_KEY"
  envstr            = ""
}
{
  buf = $0
  processing = 1
  while (processing) {
    c   = substr(buf, 1, 1)
    buf = substr(buf, 2)
    if (ENVIRON["DEBUG"]) print "DEBUG: c=" c | "cat 1>&2"
    switch (state) {
    case "PRE_KEY":
      if (!c) {
        envstr = ""
        next
      }
      if (index(COMMENTS, c)) {
        state = "COMMENT"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: COMMENT" | "cat 1>&2"
      } else if (!index(WHITESPACE, c)) {
        state  = "KEY"
        envstr = envstr c
      }
      break
    case "KEY":
      if (!c) {
        state  = "PRE_KEY"
        envstr = ""
        next
      } else if (c == "=") {
        state = "PRE_VALUE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: PRE_VALUE" | "cat 1>&2"
        sub(/[[:space:]]+$/, "", envstr)
        envstr = envstr c
      } else {
        envstr = envstr c
      }
      break
    case "PRE_VALUE":
      if (!c) {
        state  = "PRE_KEY"
        printf("%s\n%s\n", envstr, strsep)
        envstr = ""
        next
      } else if (c == "'\''") {
        state = "SINGLE_QUOTE_VALUE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: SINGLE_QUOTE_VALUE" | "cat 1>&2"
      } else if (c == "\"") {
        state = "DOUBLE_QUOTE_VALUE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: DOUBLE_QUOTE_VALUE" | "cat 1>&2"
      } else if (c == "\\") {
        state = "VALUE_ESCAPE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: VALUE_ESCAPE" | "cat 1>&2"
      } else if (!index(WHITESPACE, c)) {
        state = "VALUE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: VALUE" | "cat 1>&2"
        envstr = envstr c
      }
      break
    case "VALUE":
      if (!c) {
        state = "PRE_KEY"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: PRE_KEY" | "cat 1>&2"
        sub(/[[:space:]]+$/, "", envstr)
        printf("%s\n%s\n", envstr, strsep)
        envstr = ""
        next
      } else if (c == "\\") {
        state = "VALUE_ESCAPE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: VALUE_ESCAPE" | "cat 1>&2"
      } else {
        envstr = envstr c
      }
      break
    case "VALUE_ESCAPE":
      state = "VALUE"
      if (ENVIRON["DEBUG"]) print "DEBUG: enter state: VALUE" | "cat 1>&2"
      if (!c) {
        # eat newlines
        next
      } else {
        envstr = envstr c
      }
      break
    case "SINGLE_QUOTE_VALUE":
      if (!c) {
        envstr = envstr "\n"
        next
      } else if (c == "'\''") {
        state = "PRE_VALUE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: PRE_VALUE" | "cat 1>&2"
      } else {
        envstr = envstr c
      }
      break
    case "DOUBLE_QUOTE_VALUE":
      if (!c) {
        envstr = envstr "\n"
        next
      } else if (c == "\"") {
        state = "PRE_VALUE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: PRE_VALUE" | "cat 1>&2"
      } else if (c == "\\") {
        state = "DOUBLE_QUOTE_VALUE_ESCAPE"
        if (ENVIRON["DEBUG"]) print "DEBUG: enter state: DOUBLE_QUOTE_VALUE_ESCAPE" | "cat 1>&2"
      } else {
        envstr = envstr c
      }
      break
    case "DOUBLE_QUOTE_VALUE_ESCAPE":
      state = "DOUBLE_QUOTE_VALUE"
      if (ENVIRON["DEBUG"]) print "DEBUG: enter state: DOUBLE_QUOTE_VALUE" | "cat 1>&2"
      if (!c) {
        next
      } else if (index(SHELL_NEED_ESCAPE, c)) {
        envstr = envstr c
      } else {
        # keep escape character for values not requiring escape
        envstr = envstr "\\" c
      }
      break
    case "COMMENT":
      state = "PRE_KEY"
      if (ENVIRON["DEBUG"]) print "DEBUG: enter state: PRE_KEY" | "cat 1>&2"
      envstr = ""
      next
    }
}}
'
  for env_file_path in "$@"; do

    if ! [[ -r $env_file_path ]]; then
      continue
    fi

    local strsep="$(dd if=/dev/urandom bs=1 count=16 status=none | od -A n -t x1 | tr -d '[:space:]')"

    while grep "$strsep" "$env_file_path" &>/dev/null; do
      strsep="$(dd if=/dev/urandom bs=1 count=16 status=none | od -A n -t x1 | tr -d '[:space:]')"
    done

    local ichunk=0
    while IFS= read -r -d $'\n' chunk; do
      ichunk=`expr $ichunk + 1`

      if   [[ $chunk == $strsep ]]; then
        printf '\0'
        ichunk=0
        continue
      fi

      if [[ $ichunk -gt 1 ]]; then
        printf '\n%s' "$chunk"
      else
        printf '%s' "$chunk"
      fi

    done <<< "$(awk -v "strsep=$strsep" "$awk_prog" < "$env_file_path")"

  done
}

env_str_add()
{
  for env_str in "$@"; do
    ENV_STRS+=("$env_str")
  done
}

env_str_reset()
{
  ENV_STRS=()
}

env_exec()
{
  [[ $ENVEXEC_SKIP_SETUP ]] || _env_seq_setup
  exec env `test "$ENV_IGNORE_ENVIRON" && printf -- '-i'` "${ENV_SEQ[@]}" "$@"
}

env_eval()
{
  env_exec bash -c 'eval "$@"' - "$@"
}

ENV_SEQ=()
ENV_FILES=()
ENV_STRS=()
test "$ENV_IGNORE_ENVIRON" || ENV_IGNORE_ENVIRON=
