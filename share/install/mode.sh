mode_install()
{
  local packdir_installpath=
  local local_worktree=

  locate_gitconfig

  if [[ $INSTALL_SCOPE == local ]]; then
    local_worktree=$(git -C "$INSTALL_GITCONFIG_DIR" worktree list --porcelain | sed -n 1p | awk '{$1="";print substr($0, index($0, $2))}' || true)
  fi

  if [[ $local_worktree ]]; then
    packdir_installpath=$(path_relfrom "$ABSPACKDIR" "$local_worktree")
  else
    packdir_installpath=$ABSPACKDIR
  fi

  if [[ $ENABLE_INSTALL_ABSPATHS ]]; then
    packdir_installpath=$ABSPACKDIR
  fi

  while read hook; do
    ( eval "$hook" )
  done <<< "$(field_get_all 'install.pre')"

  write_gitconfig
  git config "${GIT_CONFIG_OPTS[@]}" --replace-all modpack.$PACKAGE_NAME.packdir "$packdir_installpath"

  while read hook; do
    ( eval "$hook" )
  done <<< "$(field_get_all 'install.post')"
}

mode_uninstall()
{
  while read hook; do
    ( eval "$hook" )
  done <<< "$(field_get_all 'uninstall.pre')"

  write_gitconfig --unset
  git config "${GIT_CONFIG_OPTS[@]}" --unset-all modpack.$PACKAGE_NAME.packdir || true

  while read hook; do
    ( eval "$hook" )
  done <<< "$(field_get_all 'uninstall.post')"
}

mode_reconfigure()
{
  if [[ $CURRENT_INSTALLSCOPE ]]; then
    write_gitconfig
  fi
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
