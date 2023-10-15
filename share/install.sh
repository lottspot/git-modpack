#!/usr/bin/env bash
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
i,list-properties        list all install.properties values
k,get-property=key       lookup an install.properties value
p,with-property=key-val  override an install.properties value for this invocation
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

if [[ $BASH_SOURCE ]] && [[ $0 != $BASH_SOURCE ]]; then
  PACKDIR=$(dirname "$BASH_SOURCE")
  if readlink "$PACKDIR" &>/dev/null; then
    PACKDIR=$(readlink "$PACKDIR")
  fi
  ABSPACKDIR=$(cd "$PACKDIR" && pwd)
  INSTALLDIR=$(git %pack_name%-installdir 2>/dev/null || true)
  return 0
fi

write_gitconfig()
{
  while read config_path; do
    test "$config_path" || continue
    config_path=$(sed 's|/./|/|g' <<< "$config_path")
    local path_args=("$config_path")
    if ! grep -- '--unset' &>/dev/null <<< "$*"; then
      path_args+=("$config_path")
    fi
    git config "${GIT_CONFIG_OPTS[@]}" --fixed-value "$@" include.path "${path_args[@]}"
  done <<< "$(find "$ABSPACKDIR/$PACKAGE_CONFIGSDIR" -maxdepth 1 -mindepth 1 -type f ! -name '.*' ! -name install.sh ! -name install.properties 2>/dev/null)"
}

mode_install()
{
  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'install.pre')"

  if [[ ! -e $INSTALLDIR ]]; then
    mkdir -p "$(dirname "$INSTALLDIR")"
    ln -s "$ABSPACKDIR" "$INSTALLDIR"
    printf '+ %s\n' "$INSTALLDIR"
  fi

  write_gitconfig
  git config "${GIT_CONFIG_OPTS[@]}" --replace-all configpack.$PACKAGE_NAME.installdir "$INSTALLDIR"

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'install.post')"
}

mode_uninstall()
{
  local was_installed=
  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'uninstall.pre')"

  if find "$INSTALLDIR" -prune &>/dev/null; then
    was_installed=1
  fi

  if [[ $INSTALLDIR != $PACKDIR ]]; then
    rm -f "$INSTALLDIR"
  fi

  if [[ $was_installed ]] && ! find "$INSTALLDIR" -prune &>/dev/null; then
    printf -- '- %s\n' "$INSTALLDIR"
  fi

  write_gitconfig --unset
  git config "${GIT_CONFIG_OPTS[@]}" --unset-all configpack.$PACKAGE_NAME.installdir

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'uninstall.post')"
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

ABSPACKDIR=$(cd "$PACKDIR" && pwd)
INSTALLDIR=
properties_path=$PACKDIR/install.properties
declare -A default_properties=(
  [package.name]=$(default_package_name "$PACKDIR")
  [package.configsdir]=.
  [install.mode]=static-local
)

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
    --reconfigure     ) modes+=(reconfigure)       ;;
    --uninstall       ) modes+=(uninstall)         ;;
    --reinstall       ) modes+=(uninstall install) ;;
    --list-properties ) modes+=(list-properties)   ;;
    --get-property    )
      modes+=(get-property)
      get_prop_name=$opt_arg
    ;;
    --with-property   )
      propkey=${opt_arg%%=*}
      propval=${opt_arg#*=}
      property_add "$propkey" "$propval"
    ;;
    --rename          ) pack_rename "$opt_arg" && exit $?;;
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
INSTALL_MODE=$(property_get 'install.mode')
GIT_CONFIG_OPTS=()

case $INSTALL_MODE in
  local)
    INSTALLDIR=$(git rev-parse --git-path "$PACKAGE_NAME")
    GIT_CONFIG_OPTS+=(--local)
  ;;
  global)
    INSTALLDIR=$HOME/.local/share/git-$PACKAGE_NAME
    GIT_CONFIG_OPTS+=(--global)
  ;;
  static-local)
    INSTALLDIR=$PACKDIR
    GIT_CONFIG_OPTS+=(--local)
  ;;
  static-global)
    INSTALLDIR=$PACKDIR
    GIT_CONFIG_OPTS+=(--global)
  ;;
  *)
    input_error "invalid install.mode: $INSTALL_MODE; must be one of: local, global, static-local, static-global"
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
  esac
done
