property_get()
{
  local prop_name=$1
  printf '%s\n' "${PROPERTIES[$prop_name]}" | tail -n1
}

property_get_all()
{
  local prop_name=$1
  printf '%s\n' "${PROPERTIES[$prop_name]}"
}

property_set()
{
  local prop_key=$1
  local prop_val=$2
  PROPERTIES[$prop_key]=$prop_val
}

property_add()
{
  local prop_key=$1
  local prop_val=$2
  if [[ ${PROPERTIES[$prop_key]} ]]; then
    PROPERTIES[$prop_key]=$(printf '%s\n%s\n' "${PROPERTIES[$prop_key]}" "$prop_val")
  else
    PROPERTIES[$prop_key]=$prop_val
  fi
}

properties_load()
{
  for loadpath in "$@"; do
    while read prop_key prop_val; do
      test "$prop_key" || continue
      property_add "$prop_key" "$prop_val"
    done <<< "$(git config -f "$loadpath" --get-regexp '.*')"
  done
}

properties_write()
{
  local dest=$1
  mkdir -p "$(dirname "$dest")"
  printf '# %s %s\n' 'vim:' 'filetype=gitconfig:' > "$dest"
  for property in "${!PROPERTIES[@]}"; do
    local var=$property
    local val=${PROPERTIES[$property]}
    git config -f "$dest" "$var" "$val"
  done
  printf '+ %s\n' "${PACK_PROPERTIES_PATH#$PACK_PATH/}"
}

properties_dump()
{
  for prop_name in "${!PROPERTIES[@]}"; do
    printf '%s %s\n' "$prop_name" "${PROPERTIES[$prop_name]}";
  done
}

properties_list()
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
awk "$awk_prog" <<< "$(properties_dump)"
}

declare -A PROPERTIES

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

_path_strip_base()
{
  local patharg=$1
  local pathbase=$2
  printf '%s\n' "${patharg#$pathbase}"
}

_paths_shared_base()
{
  local path1=$1
  local path2=$2
  awk_prog='
  BEGIN   { FS = "/"; base_depthsz = 0; }
  NR == 1 { for (depth = 1; depth <= NF; depth++) { path1[depth] = $depth }; path1_depthsz = NF; }
  NR == 2 { for (depth = 1; $depth == path1[depth]; depth++) { base[depth] = $depth; base_depthsz++; if (depth+1 > NF || depth+1 > path1_depthsz) break; }}
  END     {
    for (depth = 1; depth <= base_depthsz; depth++) {
      printf("%s", base[depth]);
      if (depth == 1 && base[depth] == "") {
	printf "/"
      }
      else if ((depth+1) <= base_depthsz) {
	printf "/"
      }
    }
    if (base_depthsz > 0) printf "\n";
  }
'
  awk "$awk_prog" <<-EOF
	$path1
	$path2
	EOF
}

_path_top_relto_stem()
{
  local stem=$1
  awk_prog='
  BEGIN { FS = "/" }
        {
	  for (depth = 1; depth <= NF; depth++)
	  {
	    if ($depth && $depth != ".")
	    {
	      printf "..";
	      if ((depth+2) <= NF) printf "/";
	    }
	  }
	  if (NF > 0) printf "\n";
	}
'
  awk "$awk_prog" <<-EOF
	$stem
	EOF
}

path_relto()
{
  local path_dest=$1
  local dir_start=$2
  local path_dest_norm=
  local dir_start_norm=
  local path_base=
  local stem_dest=
  local stem_start=
  local relpath=

  path_dest_norm=$(path_norm "$path_dest")
  dir_start_norm=$(path_norm "$dir_start")
  path_base=$(_paths_shared_base "$path_dest_norm" "$dir_start_norm")

  if ! [[ $path_base ]]; then
    if [[ $DEBUG ]]; then
      printf 'no shared base between paths: %s, %s\n' "$path_dest_norm" "$path_base_norm" >&2
    fi
    return 1
  fi

  if [[ $path_base == / ]]; then
    stem_dest=$path_dest_norm
    stem_start=$dir_start_norm
  else
    stem_dest=$(_path_strip_base "$path_dest_norm" "$path_base")
    stem_start=$(_path_strip_base "$dir_start_norm" "$path_base")
  fi

  if [[ $stem_start ]]; then
    relpath=$(_path_top_relto_stem "$stem_start")
  else
    relpath=
  fi

  if [[ $stem_dest ]] && [[ $stem_start ]]; then
    relpath+=$(printf '%s' "$stem_dest")
  elif [[ $stem_dest ]]; then
    relpath+=$(printf '.%s' "$stem_dest")
  fi

  if ! [[ $relpath ]]; then
    relpath=.
  fi

  if [[ $DEBUG ]]; then
    echo DEBUG dir_start=$dir_start                       >&2
    echo DEBUG path_dest=$path_dest                       >&2
    echo DEBUG dir_start_norm=$dir_start_norm             >&2
    echo DEBUG path_dest_norm=$path_dest_norm             >&2
    echo DEBUG path_base=$path_base                       >&2
    echo DEBUG stem_dest=$stem_dest                       >&2
    echo DEBUG stem_start=$stem_start                     >&2
    echo DEBUG relpath=$relpath                           >&2
  fi

  printf '%s\n' "$relpath"
}

env_file_add()
{
  for env_file_path in "$@"; do
    ENV_FILES+=("$env_file_path")
  done
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

env_set_add()
{
  for env_set in "$@"; do
    ENV_SETS+=("$env_set")
  done
}

env_seq_setup()
{
  local env_file_sets=()
  for env_file_path in "${ENV_FILES[@]}"; do

    if ! [[ -r $env_file_path ]]; then
      continue
    fi

    while read env_file_line; do
      if [[ $env_file_line =~ ^([[:alnum:]_]+)=(.*)$ ]]; then
        env_file_sets+=("$env_file_line")
      fi
    done < "$env_file_path"

  done

  ENV_SEQ=( "${env_file_sets[@]}" "${ENV_SETS[@]}" )
}

ENV_SEQ=()
ENV_FILES=()
ENV_SETS=()
