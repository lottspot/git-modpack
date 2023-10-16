#!/usr/bin/env bash
# = packlib =
#
# path::
#   * `path_realpath    PATH`
#   * `path_norm        PATH`
#   * `path_relto       DEST STARTDIR`
# env::
#   * `env_set_add      VAR=VAL...`
#   * `env_file_add     PATH...`
#   * `env_seq_setup`
#   * `${ENV_SEQ[*]}`
# property::
#   * `property_add     KEY VAL`
#   * `property_get     KEY`
#   * `property_get_all KEY`
#   * `proprties_load   PATH...`
#   * `proprties_write  PATH`
set -e

install_usage_spec="\
install.sh [options]

install script for %pack_name% package
--
  Options:
h,help                   show the help
version                  print the version number and exit
uninstall                remove an installation created by this script
reinstall                perform an uninstall -> install sequence
c,reconfigure            (re-)create git config includes of sources in configsdir
abspath                  use absolute paths for values installed into gitconfig
global                   convenience option for -p install.scope=global
local                    convenience option for -p install.scope=local
i,list-properties        list all install.properties values
k,get-property=key       lookup an install.properties value
p,with-property=key-val  override an install.properties value for this invocation
libdoc                   print the packlib synopsis
"

input_error()
{
  if [ "$input_errors" ]; then
    input_errors="$input_errors$(printf '\n%s\n' "$1")"
  else
    input_errors="$(printf '%s\n' "$1")"
  fi
}

assert_inputs_valid()
{
  if [ "$input_errors" ]; then
    printf 'fatal: input errors\n' >&2
    printf '%s\n' "$input_errors"  >&2
    exit 1
  fi
}

default_package_name()
{
  local packdir=$1
  local pack_basename=$(basename "$packdir")
  if [[ $pack_basename =~ ^\.+$ ]]; then
    pack_basename=$(basename "$(cd "$packdir" && pwd)")
  fi
  local pack_name=${pack_basename#.}
  pack_name=${pack_name#git-}
  printf '%s\n' "$pack_name"
}

default_install_scope()
{
  local gitconfig_scope=
  local tmpkey=x$(dd if=/dev/urandom bs=1 count=4 status=none | od -A n -t x1 | tr -d '[:space:]')
  git config --replace-all configpacktmp.$tmpkey true
  gitconfig_scope=$(
    git config --get --show-scope configpacktmp.$tmpkey |
    cut -d$'\t' -f1
  )
  git config --unset-all configpacktmp.$tmpkey
  printf '%s\n' "$gitconfig_scope"
}

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

core_newalias()
{
  if [[ ! $1 ]]; then
    printf 'usage: newalias ALIAS_NAME\n' >&2
    exit 1
  fi
  local helpdoc=$PACKDIR/docs/help.txt
  local coreconfig=$PACKDIR/$($PACKDIR/install.sh --get-property=package.configsdir)/core
  local awk_prog='
{ divcol = index($0, "::") }
END {
  aliaslen = length(newalias)
  aliaslen >= divcol ? divcol = aliaslen + 2 : divcol = divcol - (aliaslen +1)
  printf "%s" sprintf("%%%ds", divcol) "::\n", newalias, ""
}
'
  git config --file="$coreconfig" --add alias."$1" '!false'
  if [[ -w $helpdoc ]]; then
    awk -v newalias="$1" "$awk_prog" < "$helpdoc" >> "$helpdoc"
  fi
}

if [[ $BASH_SOURCE ]] && [[ $0 != $BASH_SOURCE ]]; then
  PACKDIR=$(dirname "$BASH_SOURCE")
  if readlink "$PACKDIR" &>/dev/null; then
    PACKDIR=$(readlink "$PACKDIR")
  fi
  ABSPACKDIR=$(path_realpath "$PACKDIR")
  return 0
fi

write_gitconfig()
{
  while read config_path; do
    test "$config_path" || continue

    if ! [[ $ENABLE_INSTALL_ABSPATHS ]]; then
      config_path=$(path_relto "$config_path" "$INSTALL_GITCONFIG_DIR")
    fi

    local path_args=("$config_path")
    if ! grep -- '--unset' &>/dev/null <<< "$*"; then
      path_args+=("$config_path")
      local write_op=set
    else
      local write_op=unset
    fi

    if ! git config "${GIT_CONFIG_OPTS[@]}" --fixed-value "$@" include.path "${path_args[@]}" && [[ $write_op == 'set'  ]]; then
      return 1
    fi
  done <<< "$(find "$ABSPACKDIR/$PACKAGE_CONFIGSDIR" -maxdepth 1 -mindepth 1 -type f ! -name '.*' ! -name install.sh ! -name install.properties 2>/dev/null)"
}

locate_gitconfig()
{
  local tmpkey=x$(dd if=/dev/urandom bs=1 count=4 status=none | od -A n -t x1 | tr -d '[:space:]')
  git config "${GIT_CONFIG_OPTS[@]}" --replace-all configpacktmp.$tmpkey true
  INSTALL_GITCONFIG_DIR=`dirname $(
    git config "${GIT_CONFIG_OPTS[@]}" --get --show-origin configpacktmp.$tmpkey |
    cut -d$'\t' -f1                                                              |
    sed -E 's/^file:(.*)/\1/g'
  )`
  git config "${GIT_CONFIG_OPTS[@]}" --unset-all configpacktmp.$tmpkey
}

mode_install()
{
  local packdir_installpath=
  local local_worktree=

  locate_gitconfig

  if [[ $INSTALL_SCOPE == local ]]; then
    local_worktree=$(git -C "$INSTALL_GITCONFIG_DIR" worktree list --porcelain | sed -n 1p | awk '{$1="";print substr($0, index($0, $2))}' || true)
  fi

  if [[ $local_worktree ]]; then
    packdir_installpath=$(path_relto "$ABSPACKDIR" "$local_worktree")
  else
    packdir_installpath=$ABSPACKDIR
  fi

  if [[ $ENABLE_INSTALL_ABSPATHS ]]; then
    packdir_installpath=$ABSPACKDIR
  fi

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'install.pre')"

  write_gitconfig
  git config "${GIT_CONFIG_OPTS[@]}" --replace-all configpack.$PACKAGE_NAME.packdir "$packdir_installpath"

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'install.post')"
}

mode_uninstall()
{
  locate_gitconfig

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'uninstall.pre')"

  write_gitconfig --unset
  git config "${GIT_CONFIG_OPTS[@]}" --unset-all configpack.$PACKAGE_NAME.packdir || true

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'uninstall.post')"
}

mode_libdoc()
{
  local awk_prog='
BEGIN { processing = 0 }
# adoc title
/^# = [^[:space:]]/ { processing = 1 }
# non-comment line
/^[^#]/             { processing = 0 }
processing          { print substr($0, 3) }
'
  awk "$awk_prog" < "$0"
}

pack_is_template()
{
  if grep '[%]pack_name[%]' <<< "${PROPERTIES['package.name']}" >/dev/null; then
    return 0
  else
    return 1
  fi
}

pack_rename()
{
  local new_name=$1
  local packrename_dir=$PACKDIR/.packrename
  find "$PACKDIR" -type f ! -path '*/.*' -exec sed -i.packrename -e "s/[%]pack_name[%]/$new_name/g" {} +
  find "$PACKDIR" -type f -name '*.packrename' | while read packrename_src; do
    packrename_stem=${packrename_src#$PACKDIR}
    packrename_base=${packrename_stem%.packrename}
    packrename_dest=$packrename_dir/$packrename_base
    mkdir -p "$(dirname "$packrename_dest")"
    mv "$packrename_src" "$packrename_dest"
    printf '+ %s\n' "$packrename_dest"
  done
}

PACKDIR=$(dirname "$0")

if readlink "$PACKDIR" &>/dev/null; then
  PACKDIR=$(readlink "$PACKDIR")
fi

ABSPACKDIR=$(path_realpath "$PACKDIR")
properties_path=$PACKDIR/install.properties
declare -A default_properties=(
  [package.name]=$(default_package_name "$PACKDIR")
  [package.configsdir]=.
  [install.scope]=$(default_install_scope)
)
ENABLE_INSTALL_ABSPATHS=

if [[ -e $properties_path ]]; then
  properties_load "$properties_path"
fi

usage_spec="\
$install_usage_spec
$(if pack_is_template; then printf '\n  %s\n' 'Template options:'; fi)
$(if pack_is_template; then printf '%s\n' 'r,rename=new-name rename this template into a package'; fi)
"

eval "$(git rev-parse --parseopt --stuck-long -- "$@" <<< "$usage_spec" || echo exit $?)"
until [[ $1 == '--' ]]; do
  opt_name=${1%%=*}
  opt_arg=${1#*=}
  case $opt_name in
    --version         ) printf '%pack_name%: packaged with git-configpack version %s\n' '%pack_version%'; exit 0;;
    --reconfigure     ) modes+=(reconfigure)              ;;
    --uninstall       ) modes+=(uninstall)                ;;
    --reinstall       ) modes+=(uninstall install)        ;;
    --abspath         ) ENABLE_INSTALL_ABSPATHS=1         ;;
    --global          ) property_add install.scope global ;;
    --local           ) property_add install.scope local  ;;
    --list-properties ) modes+=(list-properties)          ;;
    --get-property    )
      modes+=(get-property)
      get_prop_name=$opt_arg
    ;;
    --with-property   )
      propkey=${opt_arg%%=*}
      propval=${opt_arg#*=}
      property_add "$propkey" "$propval"
    ;;
    --rename          ) pack_rename "$opt_arg" && exit $? ;;
    --libdoc          ) modes+=(libdoc)                   ;;
  esac
  shift
done

for prop_name in "${!default_properties[@]}"; do
  prop_val=${default_properties[$prop_name]}
  if [[ ! ${PROPERTIES[$prop_name]} ]]; then
    PROPERTIES[$prop_name]=$prop_val
  fi
done

if ! [[ $modes ]]; then
  modes=(install)
fi

PACKAGE_NAME=$(property_get 'package.name')
PACKAGE_CONFIGSDIR=$(property_get 'package.configsdir')
INSTALL_SCOPE=$(property_get 'install.scope')
GIT_CONFIG_OPTS=()
INSTALL_GITCONFIG_DIR=

case $INSTALL_SCOPE in
  local)
    GIT_CONFIG_OPTS+=(--local)
  ;;
  global)
    GIT_CONFIG_OPTS+=(--global)
  ;;
  *)
    input_error "invalid install.scope: $INSTALL_SCOPE; must be one of: local, global"
  ;;
esac

assert_inputs_valid

for mode in "${modes[@]}"; do
  case $mode in
    install         ) mode_install                      ;;
    uninstall       ) mode_uninstall                    ;;
    reconfigure     ) write_gitconfig                   ;;
    list-properties ) properties_list                   ;;
    get-property    ) property_get_all "$get_prop_name" ;;
    libdoc          ) mode_libdoc                       ;;
  esac
done
