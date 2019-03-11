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

branding_shortname = ukuu
branding_longname = Ubuntu Kernel Update Utility
branding_version = 18.9
branding_authorname = Brian K. White
branding_authoremail = bw.aljex@gmail.com
branding_website = https://github.com/aljex/ukuu

vte_symbol = -D VTE_291
vte_version = vte-2.91

################################################################################

branding_defines = -X -D'BRANDING_SHORTNAME="${branding_shortname}"' -X -D'BRANDING_LONGNAME="${branding_longname}"' -X -D'BRANDING_VERSION="${branding_version}"' -X -D'BRANDING_AUTHORNAME="${branding_authorname}"' -X -D'BRANDING_AUTHOREMAIL="${branding_authoremail}"' -X -D'BRANDING_WEBSITE="${branding_website}"' -X -D'GETTEXT_PACKAGE="${branding_shortname}"'

all: app app-gtk translations

app-gtk:
	valac ${branding_defines} ${vte_symbol} --Xcc="-lm" \
		--pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gtk+-3.0 --pkg gee-0.8 --pkg json-glib-1.0 --pkg ${vte_version} \
		Common/*.vala Gtk/*.vala Utility/*.vala Utility/Gtk/*.vala -o ${branding_shortname}-gtk

app:
	valac ${branding_defines} --Xcc="-lm" \
		--pkg glib-2.0 --pkg gio-unix-2.0 --pkg posix --pkg gee-0.8 --pkg libsoup-2.4 --pkg json-glib-1.0 \
		Common/*.vala Console/*.vala Utility/*.vala -o ${branding_shortname}

translations:
	find . -iname "*.vala" | xargs xgettext --from-code=UTF-8 --language=C --keyword=_ \
		--copyright-holder="${branding_authorname} (${branding_authoremail})" \
		--package-name="${branding_shortname}" \
		--package-version="${branding_version}" \
		--msgid-bugs-address="${branding_authoremail}" \
		--escape --sort-output -o ../${branding_shortname}.pot
	for lang in ${translations} ; do \
		msgmerge --update -v ../po/${branding_shortname}-$$lang.po ../${branding_shortname}.pot ; \
	done

clean:
	rm -rfv ../release/{source,i386,amd64,armel,armhf}
	rm -rfv ../release/*.{run,deb}
	rm -rfv *.c *.o *.mo
	rm -fv ${branding_shortname} ${branding_shortname}-gtk

install:
	mkdir -p "$(DESTDIR)$(bindir)"
	mkdir -p "$(DESTDIR)$(sharedir)"
	mkdir -p "$(DESTDIR)$(mandir)"
	mkdir -p "$(DESTDIR)$(man1dir)"
	mkdir -p "$(DESTDIR)$(launcherdir)"
	mkdir -p "$(DESTDIR)$(polkitdir)"
	mkdir -p "$(DESTDIR)$(sharedir)/glib-2.0/schemas/"
	mkdir -p "$(DESTDIR)$(sharedir)/${branding_shortname}"
	mkdir -p "$(DESTDIR)$(sharedir)/pixmaps"

	# binary
	install -m 0755 ${branding_shortname} "$(DESTDIR)$(bindir)"
	install -m 0755 ${branding_shortname}-gtk "$(DESTDIR)$(bindir)"
	install -m 0755 ${branding_shortname}-uninstall "$(DESTDIR)$(bindir)"

	# shared files
	cp -dpr --no-preserve=ownership -t "$(DESTDIR)$(sharedir)/${branding_shortname}" ./share/${branding_shortname}/*
	chmod --recursive 0755 $(DESTDIR)$(sharedir)/${branding_shortname}/*

	# polkit policy file
	#install -m 0644 ./share/polkit-1/actions/in.teejeetech.pkexec.ukuu.policy "$(DESTDIR)$(polkitdir)"

	# launcher
	install -m 0755 ${branding_shortname}.desktop "$(DESTDIR)$(launcherdir)"
	
	# app icon
	install -m 0755 ./share/pixmaps/${branding_shortname}.* "$(DESTDIR)$(sharedir)/pixmaps"

	# translations
	for lang in ${translations}; do \
		mkdir -p "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES"; \
		msgfmt --check --verbose -o "$(DESTDIR)$(localedir)/$$lang/LC_MESSAGES/${branding_shortname}.mo" ../po/${branding_shortname}-$$lang.po ; \
	done

uninstall:

	# binary
	rm -f "$(DESTDIR)$(bindir)/${branding_shortname}"
	rm -f "$(DESTDIR)$(bindir)/${branding_shortname}-uninstall"

	# shared files
	rm -rf "$(DESTDIR)$(sharedir)/${branding_shortname}"

	# polkit policy file
	#rm -f "$(DESTDIR)$(polkitdir)/in.teejeetech.pkexec.ukuu.policy"

	# launcher
	rm -f "$(DESTDIR)$(launcherdir)/${branding_shortname}.desktop"
	
	# app icon
	rm -f "$(DESTDIR)$(sharedir)/pixmaps/${branding_shortname}.png"

	# translations
	rm -f $(DESTDIR)$(localedir)/*/LC_MESSAGES/${branding_shortname}.mo

	# startup scripts
	rm -f $(DESTDIR)/home/*/.config/${branding_shortname}-notify.sh
	rm -f $(DESTDIR)/home/*/.config/autostart/${branding_shortname}.desktop
