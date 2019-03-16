# Makefile for github.com/aljex fork of ukuu

include BRANDING.mak

SHELL=/bin/bash
CFLAGS=--std=c99

prefix=/usr
bindir=$(prefix)/bin
sharedir=$(prefix)/share
localedir=$(sharedir)/locale
launcherdir=$(sharedir)/applications
polkitdir=$(sharedir)/polkit-1/actions
mandir=$(sharedir)/man
man1dir=$(mandir)/man1

translations = es fr hr nl pl ru sv tr

vte_version = vte-2.91
glib_version = glib-2.0
gio_version = gio-unix-2.0
gtk_version = gtk+-3.0
json-glib_version = json-glib-1.0
gee_version = gee-0.8

host_dist:=$(shell lsb_release -sc)
host_arch:=$(shell dpkg --print-architecture)
pkg_version=$(shell dpkg-parsechangelog -S Version)

branding_symbols := -X -D'BRANDING_SHORTNAME="${BRANDING_SHORTNAME}"' -X -D'BRANDING_LONGNAME="${BRANDING_LONGNAME}"' -X -D'BRANDING_VERSION="${BRANDING_VERSION}"' -X -D'BRANDING_AUTHORNAME="${BRANDING_AUTHORNAME}"' -X -D'BRANDING_AUTHOREMAIL="${BRANDING_AUTHOREMAIL}"' -X -D'BRANDING_WEBSITE="${BRANDING_WEBSITE}"' -X -D'GETTEXT_PACKAGE="${BRANDING_SHORTNAME}"'
misc_files := README.md ${BRANDING_SHORTNAME}.desktop debian/control debian/copyright
# ... share/polkit-1/actions/${BRANDING_SHORTNAME}.policy

################################################################################

all: ${misc_files} app app-gtk translations

app-gtk:
	valac ${branding_symbols} --Xcc="-lm" \
		--pkg ${glib_version} --pkg ${gio_version} --pkg posix --pkg ${gee_version} --pkg ${json-glib_version} --pkg ${gtk_version} --pkg ${vte_version} \
		src/Common/*.vala src/Gtk/*.vala src/Utility/*.vala src/Utility/Gtk/*.vala -o ${BRANDING_SHORTNAME}-gtk

app:
	valac ${branding_symbols} --Xcc="-lm" \
		--pkg ${glib_version} --pkg ${gio_version} --pkg posix --pkg ${gee_version} --pkg ${json-glib_version} \
		src/Common/*.vala src/Console/*.vala src/Utility/*.vala -o ${BRANDING_SHORTNAME}

$(misc_files): %: %.src BRANDING.mak
	sed -e 's/BRANDING_SHORTNAME/${BRANDING_SHORTNAME}/g' \
		-e ';s/BRANDING_LONGNAME/${BRANDING_LONGNAME}/g' \
		-e ';s/BRANDING_AUTHORNAME/${BRANDING_AUTHORNAME}/g' \
		-e ';s/BRANDING_AUTHOREMAIL/${BRANDING_AUTHOREMAIL}/g' \
		-e ';s|BRANDING_WEBSITE|${BRANDING_WEBSITE}|g' \
		-e ';s/BRANDING_VERSION/${BRANDING_VERSION}/g' \
		-e ';s|BRANDING_GITREPO|${BRANDING_GITREPO}|g' \
		${@}.src >${@}

translations:
	find . -iname "*.vala" | xargs xgettext --from-code=UTF-8 --language=C --keyword=_ \
		--copyright-holder="${BRANDING_AUTHORNAME} (${BRANDING_AUTHOREMAIL})" \
		--package-name="${BRANDING_SHORTNAME}" \
		--package-version="${BRANDING_VERSION}" \
		--msgid-bugs-address="${BRANDING_AUTHOREMAIL}" \
		--escape --sort-output -o po/_messages.pot
	for lang in ${translations} ; do \
		msgmerge --update -v po/$$lang.po po/_messages.pot ; \
	done

clean:
	rm -rfv release *.c *.o *.po~
	rm -fv ${BRANDING_SHORTNAME} ${BRANDING_SHORTNAME}-gtk

install:
	mkdir -p "$(DESTDIR)$(bindir)"
	mkdir -p "$(DESTDIR)$(sharedir)"
	mkdir -p "$(DESTDIR)$(mandir)"
	mkdir -p "$(DESTDIR)$(man1dir)"
	mkdir -p "$(DESTDIR)$(launcherdir)"
	mkdir -p "$(DESTDIR)$(polkitdir)"
	mkdir -p "$(DESTDIR)$(sharedir)/glib-2.0/schemas/"
	mkdir -p "$(DESTDIR)$(sharedir)/${BRANDING_SHORTNAME}"
	mkdir -p "$(DESTDIR)$(sharedir)/pixmaps"
	install -m 0755 ${BRANDING_SHORTNAME} "$(DESTDIR)$(bindir)"
	install -m 0755 ${BRANDING_SHORTNAME}-gtk "$(DESTDIR)$(bindir)"
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/${BRANDING_SHORTNAME}" share/${BRANDING_SHORTNAME}/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/${BRANDING_SHORTNAME}/*
	#install -m 0644 share/polkit-1/actions/${BRANDING_SHORTNAME}.policy "$(DESTDIR)$(polkitdir)"
	install -m 0755 ${BRANDING_SHORTNAME}.desktop "$(DESTDIR)$(launcherdir)"
	install -m 0755 share/pixmaps/${BRANDING_SHORTNAME}.* "$(DESTDIR)$(sharedir)/pixmaps"
	for lang in ${translations}; do \
		mkdir -p "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES"; \
		msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES/${BRANDING_SHORTNAME}.mo" po/$$lang.po ; \
	done

uninstall:
	rm -f "$(DESTDIR)$(bindir)/${BRANDING_SHORTNAME}"
	rm -rf "$(DESTDIR)$(sharedir)/${BRANDING_SHORTNAME}"
	#rm -f "$(DESTDIR)$(polkitdir)/${BRANDING_SHORTNAME}.policy"
	rm -f "$(DESTDIR)$(launcherdir)/${BRANDING_SHORTNAME}.desktop"
	rm -f "$(DESTDIR)$(sharedir)/pixmaps/${BRANDING_SHORTNAME}.*"
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/${BRANDING_SHORTNAME}.mo
	rm -f $(DESTDIR)/home/*/.config/${BRANDING_SHORTNAME}/${BRANDING_SHORTNAME}-notify.sh
	rm -f $(DESTDIR)/home/*/.config/autostart/${BRANDING_SHORTNAME}.desktop

deb-src: clean ${misc_files}
	dpkg-source --build .
	mkdir -pv release/deb-src
	mv -fv ../${BRANDING_SHORTNAME}_$(pkg_version).dsc release/deb-src/
	mv -fv ../${BRANDING_SHORTNAME}_$(pkg_version).tar.* release/deb-src/
	ls -l release/deb-src

deb: deb-src
	mkdir -pv release/deb
	pbuilder-dist ${host_dist} build release/deb-src/${BRANDING_SHORTNAME}_$(pkg_version).dsc --buildresult release/deb
	ls -lv release/deb

install-deb:
	sudo dpkg -i release/deb/${BRANDING_SHORTNAME}_$(pkg_version)_${host_arch}.deb
.PHONY: install-deb

uninstall-deb:
	sudo dpkg -r ${BRANDING_SHORTNAME}
.PHONY: uninstall-deb
