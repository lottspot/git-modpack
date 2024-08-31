PACKDIR=$(dirname "$0")

if readlink "$PACKDIR" &>/dev/null; then
  PACKDIR=$(readlink "$PACKDIR")
fi

ABSPACKDIR=$(path_realpath "$PACKDIR")
ini_path=$PACKDIR/install.ini
declare -A default_fields=(
  [package.name]=$(default_package_name "$PACKDIR")
  [package.configsdir]=.
  [package.progsdir]=.
)
ENABLE_INSTALL_ABSPATHS=

if [[ -e $ini_path ]]; then
  fields_load "$ini_path"
fi

# install.scope values are under the exclusive purview of the user
gitconfig_installscope=$(git config --get git-modpack.installScope 2>/dev/null || true)
if [[ $gitconfig_installscope ]]; then
  field_add install.scope "$gitconfig_installscope"
else
  field_add install.scope "$(default_install_scope)"
fi

usage_spec="\
$install_usage_spec
$(if pack_is_template; then printf '\n  %s\n' 'Template options:'; fi)
$(if pack_is_template; then printf '%s\n' 'r,rename=new-name rename this template into a package'; fi)
"

have_opt_scope=
eval "$(git rev-parse --parseopt --stuck-long -- "$@" <<< "$usage_spec" || echo exit $?)"
until [[ $1 == '--' ]]; do
  opt_name=${1%%=*}
  opt_arg=${1#*=}
  case $opt_name in
    --version         ) printf '%pack_name%: packaged with git-modpack version %s\n' "$(basename '%pack_version%')"; exit 0;;
    --reconfigure     ) modes+=(reconfigure)              ;;
    --uninstall       ) modes+=(uninstall)                ;;
    --reinstall       ) modes+=(uninstall install)        ;;
    --abspath         ) ENABLE_INSTALL_ABSPATHS=1         ;;
    --global          ) field_add install.scope global ; have_opt_scope=1;;
    --local           ) field_add install.scope local  ; have_opt_scope=1;;
    --list-fields     ) modes+=(list-fields)          ;;
    --get-field       )
      modes+=(get-field)
      get_field_name=$opt_arg
    ;;
    --ini             )
      field_name=${opt_arg%%=*}
      field_val=${opt_arg#*=}
      field_add "$field_name" "$field_val"
    ;;
    --rename          ) pack_rename "$opt_arg" && exit $? ;;
    --libdoc          ) modes+=(libdoc)                   ;;
  esac
  shift
done

for field_name in "${!default_fields[@]}"; do
  field_val=${default_fields[$field_name]}
  if [[ ! ${_FIELDS[$field_name]} ]]; then
    _FIELDS[$field_name]=$field_val
  fi
done

if ! [[ $modes ]]; then
  modes=(install)
fi

PACKAGE_NAME=$(field_get 'package.name')
PACKAGE_CONFIGSDIR=$(field_get 'package.configsdir')
GIT_CONFIG_OPTS=()
INSTALL_GITCONFIG_DIR=

CURRENT_INSTALLSCOPE=$(git config --get --show-scope modpack."$PACKAGE_NAME".packdir 2>/dev/null | awk '{print $1}')
if [[ ! $have_opt_scope ]] && [[ $CURRENT_INSTALLSCOPE ]]; then
  field_add install.scope "$CURRENT_INSTALLSCOPE"
fi

INSTALL_SCOPE=$(field_get 'install.scope')

case $INSTALL_SCOPE in
  local)
    GIT_CONFIG_OPTS+=(--local)
  ;;
  global)
    GIT_CONFIG_OPTS+=(--global)
  ;;
  EBOUNDARY)
    runtime_error "$(printf '%s\n'                         \
      "pack $PACKDIR is bound to a different git context." \
      "explicity re-bind it using --global or --local."    \
    )"
  ;;
  *)
    runtime_error "invalid install.scope: $INSTALL_SCOPE; must be one of: local, global"
  ;;
esac

assert_no_errors

for mode in "${modes[@]}"; do
  case $mode in
    install     ) mode_install                    ;;
    uninstall   ) mode_uninstall                  ;;
    reconfigure ) mode_reconfigure                ;;
    list-fields ) fields_list                     ;;
    get-field   ) field_get_all "$get_field_name" ;;
    libdoc      ) mode_libdoc                     ;;
  esac
done
