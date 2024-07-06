#!/usr/bin/env bash
set -e

usage_spec="\
modpack-init [options] [-n|--name] PATH

Create a new modpack tree
--
  Options:
h                   show the help
n,name!=            package name (defaults to directory name)
i,ini!=name=val     assign install.ini value
t,template!         convenience option for: -n %pack_name%
a,all-resources!    include all optional resources in the modpack
with-maint!         include maintainer infrastructure in the modpack
"

die(){
  printf 'modpack-init: fatal: %s\n' "$*" >&2
  exit 1
}

copy_resource()
{
  local name=$1
  local destpath=$2
  local srcpath=$DISTDIR/$name
  mkdir -p "$(dirname "$destpath")"
  sed                                                  \
    -e "s,%pack_name%,${_FIELDS['package.name']},g" \
    -e "s,%pack_version%,$(cat "$PACKDIR/VERSION"),g"  < "$srcpath" > "$destpath"
  if [[ $(find "$srcpath" -prune -perm -00100 2>/dev/null) ]]; then
    chmod +x "$destpath"
  fi
  printf '+ %s\n' "${destpath#$NEWPACK_DESTPATH/}"
}

combine_resources()
{
  local destpath=$1
  shift
  local srcpaths=( "${@/#/$DISTDIR/}" )
  mkdir -p "$(dirname "$destpath")"
  sed                                                  \
    -e "s,%pack_name%,${_FIELDS['package.name']},g" \
    -e "s,%pack_version%,$(cat "$PACKDIR/VERSION"),g"  <<< "`cat "${srcpaths[@]}" 2>/dev/null`" > "$destpath"
  if [[ $(find "${srcpaths[@]}" -prune -perm -00100 2>/dev/null) ]]; then
    chmod +x "$destpath"
  fi
  printf '+ %s\n' "${destpath#$NEWPACK_DESTPATH/}"
}


source "$(git modpack-packdir)/install.sh"
PACKDIR=$(git modpack-packdir)
ABSPACKDIR=$(cd "$PACKDIR" && pwd)

# Parse options
eval "$(git rev-parse --parseopt --stuck-long -- "$@" <<< "$usage_spec" || echo exit $?)"
until [[ $1 == '--' ]]; do
  opt_name=${1%%=*}
  opt_arg=${1#*=}
  case $opt_name in
    --name ) newpack_name=$opt_arg;;
    --ini  )
      field_name=${opt_arg%%=*}
      field_val=${opt_arg#*=}
      _FIELDS[$field_name]=$field_val
    ;;
  --template      ) pack_is_template=1;;
  --with-maint    ) pack_wants_maint=1;;
  --all-resources )
    pack_wants_maint=1
    ;;
  esac
  shift
done

shift

# Parse operands
NEWPACK_DESTPATH=$1

# Program run

if ! [[ $NEWPACK_DESTPATH ]]; then
  printf 'error: PATH is required\n' >&2
  $0 -h
  exit 1
fi

NEWPACK_INI_PATH=$NEWPACK_DESTPATH/install.ini
DISTDIR=$PACKDIR/share

declare -A configs=(
  [core]=core.gitconfig
)

declare -A resources=(
  [install.sh]="
    install/header.sh
    install/defaults.sh
    install/packlib.sh
    install/packcore.sh
    install/sourceguard.sh
    install/gitconfig.sh
    install/mode.sh
    install/template.sh
    install/main.sh
  "
  [docs/help.txt]=help.txt
)

if [[ $pack_wants_maint ]]; then
  resources[VERSION]=maint.version
  resources[Makefile]=maint.mk
  resources[.gitignore]=maint.gitignore
  resources[.gitattributes]=maint.gitattributes
fi

declare -A default_fields=(
  ['package.configsdir']=configs
)

if [[ $newpack_name ]]; then
  _FIELDS['package.name']=$newpack_name
fi

if [[ $pack_is_template ]]; then
  _FIELDS['package.name']=%pack_name%
fi

if [[ ! ${_FIELDS['package.name']} ]]; then
  _FIELDS['package.name']=$(default_package_name "$NEWPACK_DESTPATH")
fi

for default_name in "${!default_fields[@]}"; do
  default_val=${default_fields[$default_name]}
  if [[ ! ${_FIELDS[$default_name]} ]]; then
    _FIELDS[$default_name]=$default_val
  fi
done

# validate install.scope value
install_mode=${_FIELDS['install.scope']}
if [[ $install_mode ]]; then
  "$(git modpack-packdir)/install.sh" --with-field "install.scope=$install_mode" --get-field install.scope >/dev/null
fi

if [[ ! -e $NEWPACK_INI_PATH ]]; then
  # explicitly specify PACK_PATH so fields_write knows how
  # to print a stripped resource path
  PACK_PATH=$NEWPACK_DESTPATH fields_write "$NEWPACK_INI_PATH"
fi

for conf_name in "${!configs[@]}"; do
  conf_srcs=( ${configs[$conf_name]} )
  package_configsdir=${_FIELDS['package.configsdir']}

  if [[ $package_configsdir ]]; then
    conf_path=$NEWPACK_DESTPATH/$package_configsdir/$conf_name
  else
    conf_path=$NEWPACK_DESTPATH/$conf_name
  fi

  if [[ ! -e $conf_path ]]; then
    if [[ ${#conf_srcs[*]} -gt 1 ]]; then
      combine_resources "$conf_path" "${conf_srcs[@]}"
    else
      copy_resource "${conf_srcs[0]}" "$conf_path"
    fi
  fi
done

for pack_subpath in "${!resources[@]}"; do
  resource_srcs=( ${resources[$pack_subpath]} )
  resource_path=$NEWPACK_DESTPATH/$pack_subpath
  if [[ ! -e $resource_path ]]; then
    if [[ ${#resource_srcs[*]} -gt 1 ]]; then
      combine_resources "$resource_path" "${resource_srcs[@]}"
    else
      copy_resource "${resource_srcs[0]}" "$resource_path"
    fi
  fi
done
