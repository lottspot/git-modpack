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
