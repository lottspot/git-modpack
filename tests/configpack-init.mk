initcmd_tests        += configpack-init-global
initcmd_tests        += configpack-init-local
initcmd_tests        += configpack-init-embedded
initcmd_local_cache  += $(CURDIR)/.cache/configpack-init
initcmd_global_cache += $(HOME)/.cache/git-configpack-tests

SUITES               += configpack-init
TESTS                += $(initcmd_tests)
CACHEDIRS            += '$(initcmd_local_cache)' '$(initcmd_global_cache)'
REQUIRES_SETUP       += configpack-init-setup

initcmd_global_pack        := $(initcmd_global_cache)/git-globalpack
initcmd_local_pack         := $(initcmd_local_cache)/git-localpack
initcmd_local_toplevel     := $(initcmd_local_cache)/project
initcmd_embedded_pack      := $(initcmd_local_toplevel)/git-embedpack
initcmd_gitconfig_path     := $(initcmd_local_cache)/global.gitconfig
initcmd_environ            := GIT_CONFIG_GLOBAL='$(initcmd_gitconfig_path)' GIT_DIR='$(initcmd_local_toplevel)/.git'
initcmd_git                := $(initcmd_environ) git
initcmd_top_installsh      := $(initcmd_environ) '$(CURDIR)/../install.sh'
initcmd_global_installsh   := $(initcmd_environ) '$(initcmd_global_pack)/install.sh'
initcmd_local_installsh    := $(initcmd_environ) '$(initcmd_local_pack)/install.sh'
initcmd_embedded_installsh := $(initcmd_environ) '$(initcmd_embedded_pack)/install.sh'

configpack-init          : $(initcmd_tests)
configpack-init-global   : $(initcmd_global_pack)
configpack-init-local    : $(initcmd_local_pack)
configpack-init-local    : $(initcmd_local_toplevel)
configpack-init-embedded : $(initcmd_embedded_pack)
$(initcmd_tests)         : configpack-init-setup
$(initcmd_embedded_pack) : $(initcmd_local_toplevel)

configpack-init-global:
	( cd '$(initcmd_global_cache)' && $(initcmd_global_installsh) )
	$(initcmd_git) -C '$(initcmd_global_cache)' help-globalpack
	stat -c %i "`$(initcmd_git) -C '$(initcmd_global_cache)' globalpack-packdir`" | xargs expr `stat -c %i '$(initcmd_global_pack)'` = # test globalpack-packdir
	stat -c %i "`$(initcmd_git) -C '$(initcmd_global_cache)' globalpack-configsdir`" | xargs expr `stat -c %i '$(initcmd_global_pack)/configs'` = # test globalpack-configsdir
	stat -c %i "`$(initcmd_git) -C '$(initcmd_global_cache)' globalpack-libexecdir`" | xargs expr `stat -c %i '$(initcmd_global_pack)/libexec'` = # test globalpack-libexecdir

configpack-init-local:
	( cd '$(initcmd_local_toplevel)' && $(initcmd_local_installsh) )
	$(initcmd_git) -C '$(initcmd_local_toplevel)' help-localpack
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' localpack-packdir`" | xargs expr `stat -c %i '$(initcmd_local_pack)'` = # test localpack-packdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' localpack-configsdir`" | xargs expr `stat -c %i '$(initcmd_local_pack)/configs'` = # test localpack-configsdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' localpack-libexecdir`" | xargs expr `stat -c %i '$(initcmd_local_pack)/libexec'` = # test localpack-libexecdir

configpack-init-embedded:
	( cd '$(initcmd_local_toplevel)' && $(initcmd_embedded_installsh) )
	$(initcmd_git) -C '$(initcmd_local_toplevel)' help-embedpack
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' embedpack-packdir`" | xargs expr `stat -c %i '$(initcmd_embedded_pack)'` = # test embeddedpack-packdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' embedpack-configsdir`" | xargs expr `stat -c %i '$(initcmd_embedded_pack)/configs'` = # test embeddedpack-configsdir
	cd $(initcmd_local_toplevel) && stat -c %i "`$(initcmd_git) -C '$(initcmd_local_toplevel)' embedpack-libexecdir`" | xargs expr `stat -c %i '$(initcmd_embedded_pack)/libexec'` = # test embeddedpack-libexecdir
	$(initcmd_git) -C '$(initcmd_local_toplevel)' add -A && $(initcmd_git) -C '$(initcmd_local_toplevel)' commit -m 'initial commit'
	$(MAKE) -C '$(initcmd_embedded_pack)' clean dist
	find '$(initcmd_embedded_pack)'/git-embedpack-* -type f -exec tar -tf {} git-embedpack/VERSION \; -quit | xargs expr git-embedpack/VERSION '=' # embedpack dist tree HAS version file

configpack-init-setup:
	printf '[user]\nemail=foo@example.com\nname=Foo Bar\n' > '$(initcmd_gitconfig_path)'
	$(initcmd_top_installsh)

$(initcmd_local_toplevel): configpack-init-setup
	$(initcmd_git) init '$@'

$(initcmd_local_pack) $(initcmd_global_pack) $(initcmd_embedded_pack): configpack-init-setup
	$(initcmd_git) configpack-init --all-resources '$@'

.PHONY: configpack-init-setup
