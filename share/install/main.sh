PACKDIR=$(dirname "$0")

if readlink "$PACKDIR" &>/dev/null; then
  PACKDIR=$(readlink "$PACKDIR")
fi

ABSPACKDIR=$(path_realpath "$PACKDIR")
properties_path=$PACKDIR/install.properties
declare -A default_properties=(
  [package.name]=$(default_package_name "$PACKDIR")
  [package.configsdir]=.
  [package.libexecdir]=libexec
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
    --version         ) printf '%pack_name%: packaged with git-configpack version %s\n' "$(basename '%pack_version%')"; exit 0;;
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
