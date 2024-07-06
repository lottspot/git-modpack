# test cases
initcmd_tests        += modpack-init-outer-global
initcmd_tests        += modpack-init-inner-local
initcmd_tests        += modpack-init-inner-global
initcmd_tests        += modpack-init-global-reinstall
initcmd_tests        += modpack-init-local-reinstall

# path definitions
initcmd_inner_cache          := .cache/modpack-init
initcmd_outer_cache          := $(HOME)/.cache/git-modpack-tests
initcmd_local_toplevel       := $(initcmd_inner_cache)/project
initcmd_gitconfig_path       := $(initcmd_inner_cache)/global.gitconfig
initcmd_outer_global_pack    := $(initcmd_outer_cache)/git-outer-global
initcmd_inner_outoftree_pack := $(initcmd_inner_cache)/git-inner-outoftree
initcmd_inner_embedded_pack  := $(initcmd_local_toplevel)/git-inner-embedded
initcmd_inner_global_pack    := $(initcmd_local_toplevel)/git-inner-global
initcmd_inner_relpath_pack   := $(initcmd_local_toplevel)/git-inner-relpath

# path groupings
initcmd_cachedirs += $(initcmd_inner_cache)
initcmd_cachedirs += $(initcmd_outer_cache)

# stacks

initcmd_stack_outer += $(initcmd_gitconfig_path)
initcmd_stack_outer += $(initcmd_outer_global_pack)

initcmd_stack_inner += $(initcmd_local_toplevel)
initcmd_stack_inner += $(initcmd_inner_embedded_pack)
initcmd_stack_inner += $(initcmd_inner_outoftree_pack)
initcmd_stack_inner += $(initcmd_inner_global_pack)
initcmd_stack_inner += $(initcmd_inner_relpath_pack)

# stack groupings
initcmd_stacks      += $(initcmd_stack_outer)
initcmd_stacks      += $(initcmd_stack_inner)

# exports

SUITES               += modpack-init
TESTS                += $(initcmd_tests)
CACHEDIRS            += $(initcmd_cachedirs)
REQUIRES_SETUP       += $(initcmd_stacks)

modpack-init       : $(initcmd_tests)

# stack assignment
modpack-init-outer-global    : $(initcmd_stack_outer)
modpack-init-inner-global    : $(initcmd_stack_inner)
modpack-init-inner-local     : $(initcmd_stack_inner)
modpack-init-inner-relpath   : $(initcmd_stack_inner)
$(initcmd_inner_outoftree_pack) : $(initcmd_local_toplevel)
$(initcmd_inner_global_pack)    : $(initcmd_local_toplevel)
$(initcmd_inner_embedded_pack)  : $(initcmd_local_toplevel)

# ordering
modpack-init-global-reinstall : modpack-init-outer-global
modpack-init-global-reinstall : modpack-init-inner-global
modpack-init-local-reinstall  : modpack-init-inner-local

# contexts

initcmd_environ   := GIT_CONFIG_GLOBAL='$(CURDIR)/$(initcmd_gitconfig_path)'
initcmd_environ   += GIT_DIR='$(CURDIR)/$(initcmd_local_toplevel)/.git'

initcmd_ctx_inner := cd '$(CURDIR)/$(initcmd_local_toplevel)' &&
initcmd_ctx_inner += $(initcmd_environ)

initcmd_ctx_outer := cd '$(initcmd_outer_cache)' &&
initcmd_ctx_outer += $(initcmd_environ)

# tests

modpack-init-outer-global:
	test $$(stat -c %i '$(initcmd_outer_global_pack)') -eq $$($(initcmd_ctx_outer) stat -c %i "`$(initcmd_ctx_outer) git outer-global-packdir`")
	test $$(stat -c %i '$(initcmd_outer_global_pack)/configs') -eq $$($(initcmd_ctx_outer) stat -c %i "`$(initcmd_ctx_outer) git outer-global-configsdir`")
	test $$(stat -c %i '$(initcmd_outer_global_pack)/libexec') -eq $$($(initcmd_ctx_outer) stat -c %i "`$(initcmd_ctx_outer) git outer-global-libexecdir`")

modpack-init-inner-global:
	test $$(stat -c %i '$(initcmd_inner_global_pack)') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-global-packdir`")
	test $$(stat -c %i '$(initcmd_inner_global_pack)/configs') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-global-configsdir`")
	test $$(stat -c %i '$(initcmd_inner_global_pack)/libexec') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-global-libexecdir`")
	$(MAKE) -C '$(initcmd_inner_global_pack)' clean dist
	find '$(initcmd_inner_global_pack)'/git-inner-global-* -type f -exec tar -tf {} git-inner-global/VERSION \; -quit | xargs expr git-inner-global/VERSION '=' # inner-global dist tree HAS version file

modpack-init-inner-local:
	test $$(stat -c %i '$(initcmd_inner_embedded_pack)') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-embedded-packdir`")
	test $$(stat -c %i '$(initcmd_inner_embedded_pack)/configs') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-embedded-configsdir`")
	test $$(stat -c %i '$(initcmd_inner_embedded_pack)/libexec') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-embedded-libexecdir`")
	test $$(stat -c %i '$(initcmd_inner_outoftree_pack)') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-outoftree-packdir`")
	test $$(stat -c %i '$(initcmd_inner_outoftree_pack)/configs') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-outoftree-configsdir`")
	test $$(stat -c %i '$(initcmd_inner_outoftree_pack)/libexec') -eq $$($(initcmd_ctx_inner) stat -c %i "`$(initcmd_ctx_inner) git inner-outoftree-libexecdir`")
	test -e '$(initcmd_inner_relpath_pack)/install.sh'

modpack-init-global-reinstall:
	$(initcmd_ctx_outer) $(SHELL) '$(initcmd_outer_global_pack)'/install.sh --reconfig
	cd '$(dir $(initcmd_gitconfig_path))' && while read p; do stat "$$p"; done < <($(initcmd_ctx_outer) git config --global --get-all include.path)
	$(initcmd_ctx_outer) $(SHELL) '$(initcmd_outer_global_pack)'/install.sh --reinstall
	cd '$(dir $(initcmd_gitconfig_path))' && while read p; do stat "$$p"; done < <($(initcmd_ctx_outer) git config --global --get-all include.path)

modpack-init-local-reinstall:
	$(initcmd_ctx_inner) $(SHELL) '$(CURDIR)/$(initcmd_inner_outoftree_pack)'/install.sh --reconfig
	cd '$(initcmd_local_toplevel)/.git' && while read p; do stat "$$p"; done < <($(initcmd_ctx_inner) git config --local --get-all include.path)
	$(initcmd_ctx_inner) $(SHELL) '$(CURDIR)/$(initcmd_inner_outoftree_pack)'/install.sh --reinstall
	cd '$(initcmd_local_toplevel)/.git' && while read p; do stat "$$p"; done < <($(initcmd_ctx_inner) git config --local --get-all include.path)

# stack elements

$(initcmd_inner_global_pack)                              : $(initcmd_local_toplevel)
$(initcmd_inner_embedded_pack)                            : $(initcmd_local_toplevel)
$(initcmd_inner_outoftree_pack_pack)                      : $(initcmd_local_toplevel)
$(initcmd_inner_relpath_pack)                             : $(initcmd_local_toplevel)
$(filter-out $(initcmd_gitconfig_path),$(initcmd_stacks)) : $(initcmd_gitconfig_path)

$(initcmd_gitconfig_path):
	printf '%s\n'   '[user]'                 > '$@'
	printf '\t%s\n' 'email=foo@example.com' >> '$@'
	printf '\t%s\n' 'name=Foo Bar'          >> '$@'
	$(initcmd_environ) $(SHELL) '$(CURDIR)/../install.sh'
	$(initcmd_environ) git modpack-init -h | wc -c | xargs expr

$(initcmd_local_toplevel):
	$(initcmd_environ) git init '$@'

$(initcmd_outer_global_pack):
	$(initcmd_environ) $(SHELL) '$(CURDIR)/../libexec/init.sh' --all-resources -i install.scope=global '$@'
	cd '$(initcmd_outer_cache)' && $(initcmd_environ) $(SHELL) '$@/install.sh'
	$(initcmd_ctx_outer) git help-$(@F:git-%=%) | wc -c | xargs expr

$(initcmd_inner_global_pack):
	$(initcmd_ctx_inner) $(SHELL) '$(CURDIR)/../libexec/init.sh' --all-resources -i install.scope=global '$(CURDIR)/$@'
	$(initcmd_ctx_inner) $(SHELL) '$(CURDIR)/$@/install.sh'
	$(initcmd_ctx_inner) git help-$(@F:git-%=%) | wc -c | xargs expr
	if ! [[ `$(initcmd_ctx_inner) git rev-list -1 HEAD --` ]]; then $(initcmd_ctx_inner) git add -A && $(initcmd_ctx_inner) git commit -m 'initial commit'; fi

$(initcmd_inner_outoftree_pack) $(initcmd_inner_embedded_pack):
	$(initcmd_ctx_inner) $(SHELL) '$(CURDIR)/../libexec/init.sh' --all-resources '$(CURDIR)/$@'
	$(initcmd_ctx_inner) $(SHELL) '$(CURDIR)/$@/install.sh'
	$(initcmd_ctx_inner) git help-$(@F:git-%=%) | wc -c | xargs expr

$(initcmd_inner_relpath_pack):
	mkdir -p '$@'
	cd '$@' && GIT_CONFIG_GLOBAL='$(CURDIR)/$(initcmd_gitconfig_path)' git modpack-init -n '$(shell basename '$@')' .
