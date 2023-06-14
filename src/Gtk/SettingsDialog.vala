/*
 * OneClickSettingsDialog.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using l.gtk;
using l.misc;

public class SettingsDialog : Gtk.Dialog {

	public SettingsDialog.with_parent(Gtk.Window parent) {

		int SPACING = 6;

		set_transient_for(parent);
		set_modal(true);
		window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
		icon = get_app_icon(16);
		title = BRANDING_LONGNAME + " " + _("Settings");

		var vbox_main = get_content_area();
		vbox_main.spacing = SPACING;
		vbox_main.margin = SPACING*2;

		// notification
		var label = new Gtk.Label("<b>" + _("Notification") + "</b>");
		label.set_use_markup(true);
		vbox_main.add(label);

		// notify major
		var chk_notify_major = new Gtk.CheckButton.with_label(_("Notify if a major release is available"));
		chk_notify_major.active = App.notify_major;
		chk_notify_major.toggled.connect(()=>{ App.notify_major = chk_notify_major.active; });
		vbox_main.add(chk_notify_major);

		// notify point
		var chk_notify_minor = new Gtk.CheckButton.with_label(_("Notify if a point release is available"));
		chk_notify_minor.active = App.notify_minor;
		chk_notify_minor.toggled.connect(()=>{ App.notify_minor = chk_notify_minor.active; });
		vbox_main.add(chk_notify_minor);

		// notification interval
		if (Main.VERBOSE>1) {
			label = new Gtk.Label("( VERBOSE="+Main.VERBOSE.to_string()+" : "+_("Seconds interval enabled for debugging")+" )");
			label.xalign = 0;
			vbox_main.add(label);
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
		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		vbox_main.add(hbox);
		//
		label = new Gtk.Label(_("Check every"));
		hbox.add(label);
		// value
		var adj = new Gtk.Adjustment(App.notify_interval_value, 1, max_intervals, 1, 1, 0);
		var spn_notify_value = new Gtk.SpinButton (adj, 1, 0);
		spn_notify_value.changed.connect(()=>{ App.notify_interval_value = (int)spn_notify_value.get_value(); });
		hbox.add(spn_notify_value);
		// units
		var cbt_notify_unit = new Gtk.ComboBoxText();
		cbt_notify_unit.append_text(_("Hours"));
		cbt_notify_unit.append_text(_("Days"));
		cbt_notify_unit.append_text(_("Weeks"));
		if (Main.VERBOSE>1) cbt_notify_unit.append_text(_("Seconds"));
		cbt_notify_unit.active = App.notify_interval_unit;
		cbt_notify_unit.changed.connect(() => { App.notify_interval_unit = cbt_notify_unit.active; });
		hbox.add(cbt_notify_unit);
		//
		//hbox.set_tooltip_text(_("...notification interval tooltip text..."));

		// filters
		label = new Gtk.Label("\n<b>" + _("Filters") + "</b>");
		label.set_use_markup(true);
		vbox_main.add(label);

		// hide unstable
		var chk_hide_unstable = new Gtk.CheckButton.with_label(_("Hide unstable and RC releases"));
		//chk_hide_unstable.set_tooltip_text(_("..."));
		chk_hide_unstable.active = App.hide_unstable;
		chk_hide_unstable.toggled.connect(()=>{ App.hide_unstable = chk_hide_unstable.active; });
		vbox_main.add(chk_hide_unstable);

		// hide invalid
		var chk_hide_invalid = new Gtk.CheckButton.with_label(_("Hide failed or incomplete builds"));
		chk_hide_invalid.set_tooltip_text(_("If a kernel version exists on the mainline-ppa site, but is an incomplete or failed build for your arch ("+LinuxKernel.NATIVE_ARCH+"), then don't show it in the list."));
		chk_hide_invalid.active = App.hide_invalid;
		chk_hide_invalid.toggled.connect(()=>{ App.hide_invalid = chk_hide_invalid.active; });
		vbox_main.add(chk_hide_invalid);

		// kernel version threshold
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		vbox_main.add(hbox);
		label = new Gtk.Label(_("Show"));
		hbox.add(label);
		//
		adj = new Gtk.Adjustment(App.previous_majors, -1, LinuxKernel.kernel_latest_available.version_major , 1, 1, 0);
		var spn_previous_majors = new Gtk.SpinButton (adj, 1, 0);
		spn_previous_majors.changed.connect(()=>{ App.previous_majors = (int)spn_previous_majors.get_value(); });
		hbox.add(spn_previous_majors);
		//
		label = new Gtk.Label(_("previous major versions  ( -1 = all )"));
		hbox.add(label);
		//
		//hbox.set_tooltip_text(_("...show previous majors tooltip text..."));

		// network
		label = new Gtk.Label("\n<b>" + _("Network") + "</b>");
		label.set_use_markup(true);
		vbox_main.add(label);

        // connect timeout
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		vbox_main.add (hbox);
		//
		label = new Gtk.Label(_("Internet connection timeout in"));
		hbox.add(label);
		//
		adj = new Gtk.Adjustment(App.connect_timeout_seconds, 1, 60, 1, 1, 0);
		var spn_connect_timout = new Gtk.SpinButton (adj, 1, 0);
		spn_connect_timout.changed.connect(()=>{ App.connect_timeout_seconds = (int)spn_connect_timout.get_value(); });
		hbox.add(spn_connect_timout);
		//
		label = new Gtk.Label(_("seconds"));
		hbox.add(label);
		//
		//hbox.set_tooltip_text(_("...http connect timeout tooltip text..."));

		// concurrent downloads
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		vbox_main.add (hbox);
		//
		label = new Gtk.Label(_("Max concurrent downloads"));
		hbox.add(label);
		//
		adj = new Gtk.Adjustment(App.concurrent_downloads, 1, 25, 1, 1, 0);
		var spn_concurrent_downloads = new Gtk.SpinButton (adj, 1, 0);
		spn_concurrent_downloads.changed.connect(()=>{ App.concurrent_downloads = (int)spn_concurrent_downloads.get_value(); });
		hbox.add(spn_concurrent_downloads);
		//
		//hbox.set_tooltip_text(_("...concurrent downloads tooltip text..."));

		// verify checksums
		var chk_verify_checksums = new Gtk.CheckButton.with_label(_("Verify Downloads with the CHECKSUMS files"));
		chk_verify_checksums.active = App.verify_checksums;
		chk_verify_checksums.set_tooltip_text(_("Use the sha-256 hashes from the CHECKSUMS file to verify the .deb file downloads."));
		chk_verify_checksums.toggled.connect(()=>{ App.verify_checksums = chk_verify_checksums.active; });
		vbox_main.add(chk_verify_checksums);

		// keep downloads
		var chk_keep_downloads = new Gtk.CheckButton.with_label(_("Keep Downloads"));
		chk_keep_downloads.set_tooltip_text(_("Retain downloaded .deb files after install and re-use them for uninstall/reinstall instead of downloading again.\n\nThey are still deleted once they become older than the \"Show previous major versions\" setting, or if they have been updated on the mainline-ppa site."));
		chk_keep_downloads.active = App.keep_downloads;
		chk_keep_downloads.toggled.connect(()=>{ App.keep_downloads = chk_keep_downloads.active; });
		vbox_main.add(chk_keep_downloads);

		// proxy
		label = new Gtk.Label(_("Proxy"));
		label.xalign = 0;
		vbox_main.add(label);

		var ent_proxy = new Gtk.Entry ();
		ent_proxy.set_placeholder_text("[http://][USER:PASSWORD@]HOST[:PORT]");
		//ent_proxy.set_tooltip_text(_("..."));
		ent_proxy.set_text(App.all_proxy);
		ent_proxy.activate.connect(()=>{ App.all_proxy = ent_proxy.get_text(); });
		vbox_main.add(ent_proxy);

		// ppa url
		label = new Gtk.Label("mainline-ppa url");
		label.xalign = 0;
		vbox_main.add(label);

		var ent_ppa_uri = new Gtk.Entry ();
		//ent_ppa_uri.set_tooltip_text(_("..."));
		ent_ppa_uri.set_text(App.ppa_uri);
		ent_ppa_uri.activate.connect(()=>{
			App.ppa_uri = ent_ppa_uri.get_text().strip();
			if (App.ppa_uri=="") {
				App.ppa_uri = DEFAULT_PPA_URI;
				ent_ppa_uri.set_text(App.ppa_uri);
			}
		});
		vbox_main.add(ent_ppa_uri);

		// auth command
		label = new Gtk.Label("\n<b>"+_("Auth Command")+"</b>");
		label.set_use_markup(true);
		vbox_main.add(label);

		var cbt_auth_cmd = new Gtk.ComboBoxText.with_entry();
		cbt_auth_cmd.active = -1;
		for (int i=0;i<DEFAULT_AUTH_CMDS.length;i++) {
			cbt_auth_cmd.append_text(DEFAULT_AUTH_CMDS[i]);
			if (App.auth_cmd == DEFAULT_AUTH_CMDS[i]) cbt_auth_cmd.active = i;
		}
		if (cbt_auth_cmd.active<0) {
			cbt_auth_cmd.append_text(App.auth_cmd);
			cbt_auth_cmd.active = DEFAULT_AUTH_CMDS.length;
		} else {
			cbt_auth_cmd.append_text("");
		}
		cbt_auth_cmd.changed.connect(() => {
			string s = cbt_auth_cmd.get_active_text().strip();
			if (s != App.auth_cmd) App.auth_cmd = s;
		});
		cbt_auth_cmd.set_tooltip_text(_("Command used to run dpkg with root permissions"));
		vbox_main.add(cbt_auth_cmd);

		// close button
		var btn_done = (Gtk.Button)add_button(_("Done"), Gtk.ResponseType.ACCEPT);
		btn_done.clicked.connect(()=>{ close(); });

		// run
		show_all();
	}

}
