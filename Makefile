# Makefile for github.com/aljex fork of ukuu

include BRANDING.mak
include src/miscs.mak

'': all
.PHONY: all deb-src deb

# FIXME these globbing patters are unsafe
# FIXME allowing dpkg-source to generate files in the parent outside the source tree is unsafe
# FIXME dpkg-source is supposed to be running "make clean" itself but isn't
# FIXME locations & paths are convoluted for miscs.mak and the files listed in it,
# it's a work-around for the way the context switches between here & src/makefile
deb-src: clean ${miscs}
	dpkg-source --build .
	mkdir -p release/deb-src
	mv -f ../${BRANDING_SHORTNAME}*.dsc release/deb-src/
	mv -f ../${BRANDING_SHORTNAME}*.tar.* release/deb-src/
	ls -l release/deb-src

deb: deb-src
	mkdir -p release/deb
	pbuilder-dist `lsb_release -sc` build release/deb-src/${BRANDING_SHORTNAME}*.dsc --buildresult release/deb
	ls -l release/deb

debian/%: debian/%.src BRANDING.mak
	$(MAKE) -C src ../${@}

.DEFAULT:
	$(MAKE) -C src ${@}
