initcmd_tests        += configpack-init-outer-global
initcmd_tests        += configpack-init-outer-local
initcmd_tests        += configpack-init-inner-local
initcmd_tests        += configpack-init-inner-global
initcmd_inner_cache  += $(CURDIR)/.cache/configpack-init
initcmd_outer_cache  += $(HOME)/.cache/git-configpack-tests

SUITES               += configpack-init
TESTS                += $(initcmd_tests)
CACHEDIRS            += '$(initcmd_inner_cache)' '$(initcmd_outer_cache)'
REQUIRES_SETUP       += configpack-init-setup

initcmd_local_toplevel    := $(initcmd_inner_cache)/project
initcmd_gitconfig_path    := $(initcmd_inner_cache)/global.gitconfig
initcmd_outer_global_pack := $(initcmd_outer_cache)/git-outer-global
initcmd_outer_local_pack  := $(initcmd_inner_cache)/git-outer-local
initcmd_inner_local_pack  := $(initcmd_local_toplevel)/git-inner-local
initcmd_inner_global_pack := $(initcmd_local_toplevel)/git-inner-global

configpack-init              : $(initcmd_tests)
configpack-init-outer-global : $(initcmd_outer_global_pack)
configpack-init-outer-local  : $(initcmd_outer_local_pack)
configpack-init-outer-local  : $(initcmd_local_toplevel)
configpack-init-inner-local  : $(initcmd_inner_local_pack)
configpack-init-inner-global : $(initcmd_inner_global_pack)
$(initcmd_tests)             : configpack-init-setup
$(initcmd_inner_local_pack)  : $(initcmd_local_toplevel)

initcmd_environ                := GIT_CONFIG_GLOBAL='$(initcmd_gitconfig_path)' GIT_DIR='$(initcmd_local_toplevel)/.git'
initcmd_git                    := $(initcmd_environ) git
initcmd_top_installsh          := $(initcmd_environ) $(SHELL) '$(CURDIR)/../install.sh'
initcmd_outer_global_installsh := $(initcmd_environ) $(SHELL) '$(initcmd_outer_global_pack)/install.sh' --global
initcmd_outer_local_installsh  := $(initcmd_environ) $(SHELL) '$(initcmd_outer_local_pack)/install.sh' --local
initcmd_inner_global_installsh := $(initcmd_environ) $(SHELL) '$(initcmd_inner_global_pack)/install.sh' --global
initcmd_inner_local_installsh  := $(initcmd_environ) $(SHELL) '$(initcmd_inner_local_pack)/install.sh' --local

configpack-init-outer-global:
	( cd '$(initcmd_outer_cache)' && $(initcmd_outer_global_installsh) )
	$(initcmd_git) -C '$(initcmd_outer_cache)' help-outer-global
	stat -c %i "`$(initcmd_git) -C '$(initcmd_outer_cache)' outer-global-packdir`" | xargs expr `stat -c %i '$(initcmd_outer_global_pack)'` = # test outer-global-packdir
	stat -c %i "`$(initcmd_git) -C '$(initcmd_outer_cache)' outer-global-configsdir`" | xargs expr `stat -c %i '$(initcmd_outer_global_pack)/configs'` = # test outer-global-configsdir
	stat -c %i "`$(initcmd_git) -C '$(initcmd_outer_cache)' outer-global-libexecdir`" | xargs expr `stat -c %i '$(initcmd_outer_global_pack)/libexec'` = # test outer-global-libexecdir

configpack-init-outer-local:
	( cd '$(initcmd_local_toplevel)' && $(initcmd_outer_local_installsh) )
	$(initcmd_git) -C '$(initcmd_local_toplevel)' help-outer-local
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' outer-local-packdir`" | xargs expr `stat -c %i '$(initcmd_outer_local_pack)'` = # test outer-local-packdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' outer-local-configsdir`" | xargs expr `stat -c %i '$(initcmd_outer_local_pack)/configs'` = # test outer-local-configsdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' outer-local-libexecdir`" | xargs expr `stat -c %i '$(initcmd_outer_local_pack)/libexec'` = # test outer-local-libexecdir

configpack-init-inner-global:
	( cd '$(initcmd_local_toplevel)' && $(initcmd_inner_global_installsh) )
	$(initcmd_git) -C '$(initcmd_local_toplevel)' help-inner-global
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' inner-global-packdir`" | xargs expr `stat -c %i '$(initcmd_inner_global_pack)'` = # test embeddedpack-packdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' inner-global-configsdir`" | xargs expr `stat -c %i '$(initcmd_inner_global_pack)/configs'` = # test embeddedpack-configsdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' inner-global-libexecdir`" | xargs expr `stat -c %i '$(initcmd_inner_global_pack)/libexec'` = # test embeddedpack-libexecdir

configpack-init-inner-local:
	( cd '$(initcmd_local_toplevel)' && $(initcmd_inner_local_installsh) )
	$(initcmd_git) -C '$(initcmd_local_toplevel)' help-inner-local
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' inner-local-packdir`" | xargs expr `stat -c %i '$(initcmd_inner_local_pack)'` = # test embeddedpack-packdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' inner-local-configsdir`" | xargs expr `stat -c %i '$(initcmd_inner_local_pack)/configs'` = # test embeddedpack-configsdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' inner-local-libexecdir`" | xargs expr `stat -c %i '$(initcmd_inner_local_pack)/libexec'` = # test embeddedpack-libexecdir
	$(initcmd_git) -C '$(initcmd_local_toplevel)' add -A && $(initcmd_git) -C '$(initcmd_local_toplevel)' commit -m 'initial commit'
	$(MAKE) -C '$(initcmd_inner_local_pack)' clean dist
	find '$(initcmd_inner_local_pack)'/git-inner-local-* -type f -exec tar -tf {} git-inner-local/VERSION \; -quit | xargs expr git-inner-local/VERSION '=' # inner-local dist tree HAS version file

configpack-init-setup:
	printf '[user]\nemail=foo@example.com\nname=Foo Bar\n' > '$(initcmd_gitconfig_path)'
	$(initcmd_top_installsh)
	$(initcmd_git) configpack-init -h | tee /dev/stderr | grep '^usage:' >/dev/null

$(initcmd_local_toplevel): configpack-init-setup
	$(initcmd_git) init '$@'

$(initcmd_outer_local_pack) $(initcmd_outer_global_pack) $(initcmd_inner_local_pack) $(initcmd_inner_global_pack): configpack-init-setup
	$(initcmd_environ) $(SHELL) '$(CURDIR)/../libexec/init.sh' --all-resources '$@'

.PHONY: configpack-init-setup
