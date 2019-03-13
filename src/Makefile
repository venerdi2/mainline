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

include ../BRANDING.mak
include miscs.mak

vte_symbol = -D VTE_291
vte_version = vte-2.91

################################################################################

branding_symbols = -X -D'BRANDING_SHORTNAME="${BRANDING_SHORTNAME}"' -X -D'BRANDING_LONGNAME="${BRANDING_LONGNAME}"' -X -D'BRANDING_VERSION="${BRANDING_VERSION}"' -X -D'BRANDING_AUTHORNAME="${BRANDING_AUTHORNAME}"' -X -D'BRANDING_AUTHOREMAIL="${BRANDING_AUTHOREMAIL}"' -X -D'BRANDING_WEBSITE="${BRANDING_WEBSITE}"' -X -D'GETTEXT_PACKAGE="${BRANDING_SHORTNAME}"'

all: app app-gtk translations $(miscs)

app-gtk:
	valac ${branding_symbols} ${vte_symbol} --Xcc="-lm" \
		--pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gtk+-3.0 --pkg gee-0.8 --pkg json-glib-1.0 --pkg ${vte_version} \
		Common/*.vala Gtk/*.vala Utility/*.vala Utility/Gtk/*.vala -o ${BRANDING_SHORTNAME}-gtk

app:
	valac ${branding_symbols} --Xcc="-lm" \
		--pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gee-0.8 --pkg libsoup-2.4 --pkg json-glib-1.0 \
		Common/*.vala Console/*.vala Utility/*.vala -o ${BRANDING_SHORTNAME}

# $(miscs) is a special case.
# We want these files to be regenerated any time either the matching *.src file OR ../BRANDING.mak changes.
# We do NOT want "make clean" to delete any of the $(miscs) files. Especially not debian/*
# "make deb" needs the files in debian/* to all be generated before running any deb packaging/building tools.
# And, those tools themselves run "make clean" along the way internally,
# so "make clean" should not delete the debian/* files at least.
$(miscs): %: %.src ../BRANDING.mak
	sed -e 's/BRANDING_SHORTNAME/${BRANDING_SHORTNAME}/g' \
		-e ';s/BRANDING_LONGNAME/${BRANDING_LONGNAME}/g' \
		-e ';s/BRANDING_AUTHORNAME/${BRANDING_AUTHORNAME}/g' \
		-e ';s/BRANDING_AUTHOREMAIL/${BRANDING_AUTHOREMAIL}/g' \
		-e ';s|BRANDING_WEBSITE|${BRANDING_WEBSITE}|g' \
		-e ';s/BRANDING_VERSION/${BRANDING_VERSION}/g' \
		${@}.src >${@}

translations:
	find . -iname "*.vala" | xargs xgettext --from-code=UTF-8 --language=C --keyword=_ \
		--copyright-holder="${BRANDING_AUTHORNAME} (${BRANDING_AUTHOREMAIL})" \
		--package-name="${BRANDING_SHORTNAME}" \
		--package-version="${BRANDING_VERSION}" \
		--msgid-bugs-address="${BRANDING_AUTHOREMAIL}" \
		--escape --sort-output -o ../${BRANDING_SHORTNAME}.pot
	for lang in ${translations} ; do \
		msgmerge --update -v ../po/${BRANDING_SHORTNAME}-$$lang.po ../${BRANDING_SHORTNAME}.pot ; \
	done

# Intentionally do not remove the files created by $(miscs)
clean:
	rm -rfv ../release/* *.c *.o *.mo
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

	# binary
	install -m 0755 ${BRANDING_SHORTNAME} "$(DESTDIR)$(bindir)"
	install -m 0755 ${BRANDING_SHORTNAME}-gtk "$(DESTDIR)$(bindir)"

	# shared files
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/${BRANDING_SHORTNAME}" ./share/${BRANDING_SHORTNAME}/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/${BRANDING_SHORTNAME}/*

	# polkit policy file
	#install -m 0644 ./share/polkit-1/actions/${BRANDING_SHORTNAME}.policy "$(DESTDIR)$(polkitdir)"

	# launcher
	install -m 0755 ${BRANDING_SHORTNAME}.desktop "$(DESTDIR)$(launcherdir)"
	
	# app icon
	install -m 0755 ./share/pixmaps/${BRANDING_SHORTNAME}.* "$(DESTDIR)$(sharedir)/pixmaps"

	# translations
	for lang in ${translations}; do \
		mkdir -p "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES"; \
		msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES/${BRANDING_SHORTNAME}.mo" ../po/${BRANDING_SHORTNAME}-$$lang.po ; \
	done

uninstall:

	# binary
	rm -f "$(DESTDIR)$(bindir)/${BRANDING_SHORTNAME}"

	# shared files
	rm -rf "$(DESTDIR)$(sharedir)/${BRANDING_SHORTNAME}"

	# polkit policy file
	#rm -f "$(DESTDIR)$(polkitdir)/${BRANDING_SHORTNAME}.policy"

	# launcher
	rm -f "$(DESTDIR)$(launcherdir)/${BRANDING_SHORTNAME}.desktop"
	
	# app icon
	rm -f "$(DESTDIR)$(sharedir)/pixmaps/${BRANDING_SHORTNAME}.png"

	# translations
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/${BRANDING_SHORTNAME}.mo

	# startup scripts
	rm -f $(DESTDIR)/home/*/.config/${BRANDING_SHORTNAME}/${BRANDING_SHORTNAME}-notify.sh
	rm -f $(DESTDIR)/home/*/.config/autostart/${BRANDING_SHORTNAME}.desktop
