#
# Copyright (c) 2012, Joyent, Inc. All rights reserved.
#
# Makefile: basic Makefile for manta compute engine
#
# This Makefile contains only repo-specific logic and uses included makefiles
# to supply common targets (javascriptlint, jsstyle, restdown, etc.), which are
# used by other repos as well. You may well need to rewrite most of this file,
# but you shouldn't need to touch the included makefiles.
#
# If you find yourself adding support for new targets that could be useful for
# other projects too, you should add these to the original versions of the
# included Makefiles (in eng.git) so that other teams can use them too.
#

#
# While we only support developing on SmartOS, where we have sdcnode builds
# available, it's convenient to be able to use tools like "mrjob" and the like
# from Mac laptops without having to set up a complete dev environment.  The
# junk about the dependencies is especially regrettable, but reality until we
# have a better solution via npm or multiple npm packages.
#
ifeq ($(shell uname -s),Darwin)
	USE_LOCAL_NODE=true
	DEPS_EXTRADEPS=rmdeps
else
	USE_LOCAL_NODE=false
endif

#
# Tools
#
BASHSTYLE	 = $(NODE) tools/bashstyle
CATEST		 = tools/catest
CC      	 = gcc

#
# Files
#
BASH_FILES	 = \
    npm/postinstall.sh		\
    npm/preuninstall.sh		\
    sbin/mrerrors		\
    sbin/mrgroups		\
    sbin/mrjobreport		\
    sbin/mrlogexpire.sh		\
    sbin/mrzonedisable		\
    sbin/mrzones		\
    tools/mragentconf		\
    tools/mrdeploycompute	\
    tools/mrzone		\
    tools/mrzoneremove

DOC_FILES	 = index.restdown
JSON_FILES	:= $(shell find src etc -name '*.json') \
                   sapi_manifests/marlin/manifest.json  \
                   sapi_manifests/marlin/template
JS_FILES	:= $(shell find src lib test -name '*.js')
JS_FILES	+= \
    sbin/mlocate \
    sbin/mrerrorsummary \
    sbin/mrjob 	\
    sbin/mrmeter \
    tools/mrpound

JSL_CONF_NODE	 = tools/jsl.node.conf
JSL_FILES_NODE   = $(JS_FILES)
JSSTYLE_FILES	 = $(JS_FILES)
SMF_MANIFESTS_IN = \
    smf/manifests/marlin-agent.xml.in \
    smf/manifests/marlin-lackey.xml.in

#
# v8plus uses the CTF tools as part of its build, but they can safely be
# overridden here so that this works in dev zones without them.
#
NPM_ENV		 = MAKE_OVERRIDES="CTFCONVERT=/bin/true CTFMERGE=/bin/true"

include ./tools/mk/Makefile.defs
include ./tools/mk/Makefile.smf.defs
include ./tools/mk/Makefile.node_deps.defs

ifneq ($(USE_LOCAL_NODE),true)
    REPO_MODULES     = src/node-hyprlofs
    NODE_PREBUILT_VERSION = v0.8.22
    NODE_PREBUILT_TAG = zone

    include ./tools/mk/Makefile.node_prebuilt.defs
else
    NPM_EXEC :=
    NPM = npm
endif

#
# Repo-specific targets
#
CFLAGS		+= -Wall -Werror
EXECS   	 = src/mallocbomb/mallocbomb
CLEANFILES	+= $(EXECS)

.PHONY: all
all: $(SMF_MANIFESTS) deps $(EXECS) scripts

.PHONY: deps
deps: $(DEPS_EXTRADEPS) | $(REPO_DEPS) $(NPM_EXEC)
	$(NPM_ENV) $(NPM) --no-rebuild install

# As discussed above, this is highly regrettable.
.PHONY: rmdeps
rmdeps:
	json -e "this.optionalDependencies['hyprlofs'] = undefined" \
	    < package.json > package.json.1 && mv package.json.1 package.json
	json -e "this.optionalDependencies['illumos_contract'] = undefined" \
	    < package.json > package.json.1 && mv package.json.1 package.json
	json -e "this.dependencies['kstat'] = undefined" \
	    < package.json > package.json.1 && mv package.json.1 package.json
	json -e "this.dependencies['statvfs'] = undefined" \
	    < package.json > package.json.1 && mv package.json.1 package.json
	json -e "this.dependencies['zoneid'] = undefined" \
	    < package.json > package.json.1 && mv package.json.1 package.json
	json -e "this.dependencies['zsock-async'] = undefined" \
	    < package.json > package.json.1 && mv package.json.1 package.json
	rm -f package.json.1

.PHONY: test
test: all
	tools/catest -a

src/mallocbomb/mallocbomb: src/mallocbomb/mallocbomb.c

DISTCLEAN_FILES += node_modules

include ./Makefile.mg.targ
include ./tools/mk/Makefile.node_deps.targ
include ./tools/mk/Makefile.deps
include ./tools/mk/Makefile.smf.targ
include ./tools/mk/Makefile.targ

ifneq ($(USE_LOCAL_NODE),true)
    include ./tools/mk/Makefile.node_prebuilt.targ
endif
