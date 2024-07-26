all:

WGET = wget
CURL = curl
GIT = git
PERL = ./perl

updatenightly: local/bin/pmbp.pl
	$(CURL) -s -S -L -f https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules t_deps/modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config
	$(CURL) -sSLf https://raw.githubusercontent.com/wakaba/ciconfig/master/ciconfig | RUN_GIT=1 REMOVE_UNUSED=1 perl
	$(MAKE) build
	$(GIT) add ./tesica viewer

## ------ Setup ------

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L -f https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
            --create-perl-command-shortcut @perl \
            --create-perl-command-shortcut @prove

build: build-tesica build-js

build-tesica: deps-fatpack ./tesica

deps-fatpack:
	$(PERL) local/bin/pmbp.pl $(PMBP_OPTIONS) \
	    --install-module App::FatPacker \
	    --create-perl-command-shortcut @local/fatpack=fatpack

## For modules that have .packlist
local/fatpacker.trace: bin/tesica.pl lib/*.pm
	local/fatpack trace --to=$@ bin/tesica.pl
## For the other modules
local/module-list.sh: bin/create-module-list.pl bin/tesica.pl lib/*.pm
	$(PERL) $< > $@
local/fatpacker.packlists: local/fatpacker.trace
	local/fatpack packlists-for `cat $<` > $@

PERL_ARCHNAME = $(shell $(PERL) -MConfig -e 'print $$Config{archname}')

local/fatlib-files: local/fatpacker.packlists local/module-list.sh \
    intermediate/AnyEvent-constants.pm
	cd local && ./fatpack tree `cat ../local/fatpacker.packlists`
	bash local/module-list.sh
	cp -a local/fatlib/$(PERL_ARCHNAME)/* local/fatlib/
	rm -fr local/fatlib/$(PERL_ARCHNAME)
	rm -fr local/fatlib/Socket.pm
	rm -fr local/fatlib/auto
	rm local/fatlib/AnyEvent/*.pod local/fatlib/AnyEvent/constants.pl
	mv local/fatlib/AnyEvent/Util/idna.pl local/fatlib/AnyEvent/Util/idna.pm
	mv local/fatlib/AnyEvent/Util/uts46data.pl local/fatlib/AnyEvent/Util/uts46data.pm
	cp intermediate/AnyEvent-constants.pm local/fatlib/AnyEvent/constants.pm
	perl -i -pe 's{(AnyEvent/[^.]+)\.pl}{\1.pm}' local/fatlib/AnyEvent.pm
	ls -R local/fatlib

./tesica: bin/tesica.pl local/fatlib-files
	echo '#!/usr/bin/env perl' > $@
	cd local && ./fatpack file ../$< >> ../$@
	-git diff tesica | cat
	perl -c $@
	chmod u+x $@

intermediate/AnyEvent-constants.pm:
	$(WGET) -O local/aec.txt https://github.com/creaktive/dePAC/raw/master/AnyEvent/constants.pm
	$(WGET) -O local/aec-license.txt https://github.com/creaktive/dePAC/raw/master/LICENSE
	cat local/aec.txt > $@
	echo '' >> $@
	echo '=pod' >> $@
	echo '' >> $@
	cat local/aec-license.txt >> $@
	echo '' >> $@
	echo '=cut' >> $@

build-js: viewer/page-components.js viewer/time.js viewer/unit-number.js

viewer/page-components.js: local/generated
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/html-page-components/master/src/page-components.js
viewer/time.js: local/generated
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/timejs/master/src/time.js
viewer/unit-number.js: local/generated
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/html-unit-number/master/src/unit-number.js

local/generated:
	touch $@

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main: test-main-files test-main-compiled

test-main-files:
	TEST_SHOW_OUTPUT=$$CI $(PROVE) t/*.t

test-main-compiled:
	TEST_COMPILED_TESICA=1 $(PROVE) --verbose t/*.t

## License: Public Domain.
