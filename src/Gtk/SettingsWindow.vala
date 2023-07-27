
using l.misc;

public class SettingsWindow : Gtk.Window {

	public SettingsWindow(Gtk.Window parent) {

		const int SPACING = 6;

		this.set_transient_for(parent);
		this.set_modal(true);
		this.title = BRANDING_LONGNAME + " " +_("Configuration");
		this.window_position = Gtk.WindowPosition.CENTER_ON_PARENT;

		// vbox_main holds the notebook and the close button
		var vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		this.add(vbox_main);

		// notebook holds a page for each settings section
		var notebook = new Gtk.Notebook();
		vbox_main.add(notebook);

		// close button
		var btn_close = new Gtk.Button.with_label(_("Done"));
		btn_close.clicked.connect(()=>{ close(); });
		vbox_main.add(btn_close);

		// fill the notebook pages
		Gtk.Box pgbox;
		Gtk.Box hbox;
		Gtk.Label pgtitle;
		Gtk.Label label;

		//==============================================================
		// Page 1 - FILTERS
		//==============================================================

		//pgtitle = new Gtk.Label("<b>" + _("Filters") + "</b>");
		//pgtitle.set_use_markup(true);
		pgtitle = new Gtk.Label(_("Filters"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

		// hide unstable
		var chk_hide_rc = new Gtk.CheckButton.with_label(_("Hide unstable and RC releases"));
		//chk_hide_rc.set_tooltip_text(_("..."));
		chk_hide_rc.active = App.hide_unstable;
		chk_hide_rc.toggled.connect(()=>{ App.hide_unstable = chk_hide_rc.active; });
		pgbox.add(chk_hide_rc);

		// hide invalid
		var chk_hide_invalid = new Gtk.CheckButton.with_label(_("Hide failed or incomplete builds"));
		chk_hide_invalid.set_tooltip_text(
			_("If a kernel version exists on the mainline-ppa site, but is an incomplete or failed build for your arch (%s), then don't show it in the list.").printf(LinuxKernel.NATIVE_ARCH)
		);
		chk_hide_invalid.active = App.hide_invalid;
		chk_hide_invalid.toggled.connect(()=>{ App.hide_invalid = chk_hide_invalid.active; });
		pgbox.add(chk_hide_invalid);

		// hide flavors
		var chk_hide_flavors = new Gtk.CheckButton.with_label(_("Hide flavors other than \"generic\""));
		chk_hide_flavors.set_tooltip_text(
			_("Don't show the alternative flavors like \"lowlatency\", \"generic-64k\", \"generic-lpae\", \"server\", \"virtual\", etc.")
		);
		chk_hide_flavors.active = App.hide_flavors;
		chk_hide_flavors.toggled.connect(()=>{ App.hide_flavors = chk_hide_flavors.active; });
		pgbox.add(chk_hide_flavors);

		// kernel version threshold
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add(hbox);
		label = new Gtk.Label(_("Show"));
		hbox.add(label);
		var adj_prevm = new Gtk.Adjustment(App.previous_majors, -1, LinuxKernel.kernel_latest_available.version_major , 1, 1, 0);
		var spn_prevm = new Gtk.SpinButton (adj_prevm, 1, 0);
		spn_prevm.changed.connect(()=>{ App.previous_majors = (int)spn_prevm.get_value(); });
		hbox.add(spn_prevm);
		label = new Gtk.Label(_("previous major versions  ( -1 = all )"));
		hbox.add(label);
		//hbox.set_tooltip_text(_("...show previous majors tooltip text..."));

		//==============================================================
		// Page 2 - NOTIFICATIONS
		//==============================================================

		pgtitle = new Gtk.Label(_("Notification"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

		// notify major
		var chk_notify_major = new Gtk.CheckButton.with_label(_("Notify if a major release is available"));
		chk_notify_major.active = App.notify_major;
		chk_notify_major.toggled.connect(()=>{ App.notify_major = chk_notify_major.active; });
		pgbox.add(chk_notify_major);

		// notify point
		var chk_notify_minor = new Gtk.CheckButton.with_label(_("Notify if a point release is available"));
		chk_notify_minor.active = App.notify_minor;
		chk_notify_minor.toggled.connect(()=>{ App.notify_minor = chk_notify_minor.active; });
		pgbox.add(chk_notify_minor);

		// notification interval
		if (Main.VERBOSE>1) {
			label = new Gtk.Label("( VERBOSE="+Main.VERBOSE.to_string()+" : "+_("Seconds interval enabled for debugging")+" )");
			label.xalign = 0;
			pgbox.add(label);
		}
		// replace invalid debug-only values with valid values
		int max_intervals = 52;
		if (Main.VERBOSE>1) {
			// debug allows seconds, allow up to 1 hour of seconds
			max_intervals = 3600;
		} else {
			if (App.notify_interval_unit == 3) {
				App.notify_interval_value = DEFAULT_NOTIFY_INTERVAL_VALUE;
				App.notify_interval_unit = DEFAULT_NOTIFY_INTERVAL_UNIT;
			}
		}
		//
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add(hbox);
		//
		label = new Gtk.Label(_("Check every"));
		hbox.add(label);
		// value
		var adj_interval = new Gtk.Adjustment(App.notify_interval_value, 1, max_intervals, 1, 1, 0);
		var spn_interval = new Gtk.SpinButton(adj_interval, 1, 0);
		spn_interval.changed.connect(()=>{ App.notify_interval_value = (int)spn_interval.get_value(); });
		hbox.add(spn_interval);
		// units
		var cbt_units = new Gtk.ComboBoxText();
		cbt_units.append_text(_("Hours"));
		cbt_units.append_text(_("Days"));
		cbt_units.append_text(_("Weeks"));
		if (Main.VERBOSE>1) cbt_units.append_text(_("Seconds"));
		cbt_units.active = App.notify_interval_unit;
		cbt_units.changed.connect(() => { App.notify_interval_unit = cbt_units.active; });
		hbox.add(cbt_units);
		//hbox.set_tooltip_text(_("...notification interval tooltip text..."));

		//==============================================================
		// Page 3 - NETWORK
		//==============================================================

		pgtitle = new Gtk.Label(_("Network"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

        // connect timeout
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add(hbox);
		//
		label = new Gtk.Label(_("Internet connection timeout in"));
		hbox.add(label);
		//
		var adj_ict = new Gtk.Adjustment(App.connect_timeout_seconds, 1, 60, 1, 1, 0);
		var spn_ict = new Gtk.SpinButton (adj_ict, 1, 0);
		spn_ict.changed.connect(()=>{ App.connect_timeout_seconds = (int)spn_ict.get_value(); });
		hbox.add(spn_ict);
		//
		label = new Gtk.Label(_("seconds"));
		hbox.add(label);
		//hbox.set_tooltip_text(_("...http connect timeout tooltip text..."));

		// concurrent downloads
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add (hbox);
		//
		label = new Gtk.Label(_("Max concurrent downloads"));
		hbox.add(label);
		//
		var adj_pdl = new Gtk.Adjustment(App.concurrent_downloads, 1, 25, 1, 1, 0);
		var spn_pdl = new Gtk.SpinButton (adj_pdl, 1, 0);
		spn_pdl.changed.connect(()=>{ App.concurrent_downloads = (int)spn_pdl.get_value(); });
		hbox.add(spn_pdl);
		//hbox.set_tooltip_text(_("...concurrent downloads tooltip text..."));

		// verify checksums
		var chk_checksums = new Gtk.CheckButton.with_label(_("Verify Downloads with the CHECKSUMS files"));
		chk_checksums.active = App.verify_checksums;
		chk_checksums.set_tooltip_text(_("Use the sha-256 hashes from the CHECKSUMS file to verify the .deb file downloads."));
		chk_checksums.toggled.connect(()=>{ App.verify_checksums = chk_checksums.active; });
		pgbox.add(chk_checksums);

		// keep downloads
		var chk_keep = new Gtk.CheckButton.with_label(_("Keep Downloads"));
		chk_keep.set_tooltip_text(_(
			"Retain downloaded .deb files after install and re-use them for uninstall/reinstall instead of downloading again.\n"
			+ "\n"
			+ "They are still deleted once they become older than the \"Show previous major versions\" setting, or if they have been updated on the mainline-ppa site."
		));
		chk_keep.active = App.keep_downloads;
		chk_keep.toggled.connect(()=>{ App.keep_downloads = chk_keep.active; });
		pgbox.add(chk_keep);

		// proxy
		label = new Gtk.Label(_("Proxy"));
		label.xalign = 0;
		pgbox.add(label);

		var ent_proxy = new Gtk.Entry ();
		ent_proxy.set_placeholder_text("[http://][USER:PASSWORD@]HOST[:PORT]");
		//ent_proxy.set_tooltip_text(_("..."));
		ent_proxy.set_text(App.all_proxy);
		ent_proxy.activate.connect(()=>{ App.all_proxy = ent_proxy.get_text(); });
		pgbox.add(ent_proxy);

		// ppa url
		label = new Gtk.Label("mainline-ppa url");
		label.xalign = 0;
		pgbox.add(label);

		var ent_ppaurl = new Gtk.Entry ();
		//ent_ppaurl.set_tooltip_text(_("..."));
		ent_ppaurl.set_text(App.ppa_uri);
		ent_ppaurl.activate.connect(()=>{
			App.ppa_uri = ent_ppaurl.get_text().strip();
			if (App.ppa_uri=="") {
				App.ppa_uri = DEFAULT_PPA_URI;
				ent_ppaurl.set_text(App.ppa_uri);
			}
		});
		pgbox.add(ent_ppaurl);

		//==============================================================
		// Page 4 - EXTERNAL COMMANDS
		//==============================================================

		pgtitle = new Gtk.Label(_("External Commands"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

		// auth command
		label = new Gtk.Label("auth command");
		label.xalign = 0;
		pgbox.add(label);

		var cbt_authcmd = new Gtk.ComboBoxText.with_entry();
		cbt_authcmd.active = -1;
		for (int i=0;i<DEFAULT_AUTH_CMDS.length;i++) {
			cbt_authcmd.append_text(DEFAULT_AUTH_CMDS[i]);
			if (App.auth_cmd == DEFAULT_AUTH_CMDS[i]) cbt_authcmd.active = i;
		}
		if (cbt_authcmd.active<0) {
			cbt_authcmd.append_text(App.auth_cmd);
			cbt_authcmd.active = DEFAULT_AUTH_CMDS.length;
		} else {
			cbt_authcmd.append_text("");
		}
		cbt_authcmd.changed.connect(() => {
			string s = cbt_authcmd.get_active_text().strip();
			if (s != App.auth_cmd) App.auth_cmd = s;
		});
		cbt_authcmd.set_tooltip_text(_(
			"Command used to run dpkg with root permissions.\n"
			+ "\n"
			+ "If the auth programs commandline syntax requires the execute command to be enclosed in quotes rather than merely appended to the end of the command line, you can include a single %s in the string, and it will be replaced with the dpkg command, otherwise it will be appended to the end.\n"
			+ "See \"su -c\" in the drop down list for an example of that."
		));
		pgbox.add(cbt_authcmd);

		// xterm command
		label = new Gtk.Label("terminal window");
		label.xalign = 0;
		pgbox.add(label);

		var cbt_termcmd = new Gtk.ComboBoxText.with_entry();
		cbt_termcmd.active = -1;
		for (int i=0;i<DEFAULT_TERM_CMDS.length;i++) {
			cbt_termcmd.append_text(DEFAULT_TERM_CMDS[i]);
			if (App.term_cmd == DEFAULT_TERM_CMDS[i]) cbt_termcmd.active = i;
		}
		if (cbt_termcmd.active<0) {
			cbt_termcmd.append_text(App.term_cmd);
			cbt_termcmd.active = DEFAULT_TERM_CMDS.length;
		} else {
			cbt_termcmd.append_text("");
		}
		cbt_termcmd.changed.connect(() => {
			string s = cbt_termcmd.get_active_text().strip();
			if (s != App.term_cmd) App.term_cmd = s;
		});
		cbt_termcmd.set_tooltip_text(
			_("Terminal command used to run")+" \""+BRANDING_SHORTNAME+" --install ...\"\n"
			+ _("Example")+": \"xterm -e\" "+_("will result in")+" \"xterm -e "+BRANDING_SHORTNAME+" --pause --install 6.3.7\"\n"
			+ "\n"
			+ _("If the terminal programs commandline syntax requires the execute command to be enclosed in quotes rather than merely appended to the end of the command line, you can include a single %s in the string, and it will be replaced with the install command, otherwise it will be appended to the end.\n"
			+ "See mate-terminal in the drop down list for an example of that.\n"
			+ "\n"
			+ "You may write any commandline you want, but the specified program must stay in the foreground and block while the command is running, not fork and return immediately.\n"
			+ "Most terminal programs work fine by default, but some require special command line flags, and some are not usable at all.\n"
			+ "\n"
			+ "Examples:\n"
			+ "gnome-terminal can be made to block by using it's --wait option.\n"
			+ "xfce4-terminal can not be made to block.\n"
			+ "\n"
			+ "Edit the command to customize the appearance of the terminal.")
		);

		pgbox.add(cbt_termcmd);

	}

}
