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

using Gtk;

using TeeJee.FileSystem;
using l.gtk;
using l.misc;

public class SettingsDialog : Gtk.Dialog {

	private Gtk.CheckButton chk_notify_major;
	private Gtk.CheckButton chk_notify_minor;
	private Gtk.CheckButton chk_hide_unstable;
	private Gtk.CheckButton chk_verify_checksums;

	public SettingsDialog.with_parent(Window parent) {
		set_transient_for(parent);
		set_modal(true);
		window_position = WindowPosition.CENTER_ON_PARENT;
		deletable = false;
		resizable = false;
		
		icon = get_app_icon(16);

		title = _("Settings");

		// get content area
		var vbox_main = get_content_area();
		vbox_main.spacing = 6;
		vbox_main.margin = 12;
		//vbox_main.margin_bottom = 12;
		vbox_main.set_size_request(400,500);

		// notification
		var label = new Label("<b>" + _("Notification") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_bottom = 6;
		vbox_main.add (label);

		// chk_notify_major
		var chk = new Gtk.CheckButton.with_label(_("Notify if a major release is available"));
		chk.active = App.notify_major;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_notify_major = chk;

		chk.toggled.connect(()=>{ App.notify_major = chk_notify_major.active; });

		// chk_notify_minor
		chk = new Gtk.CheckButton.with_label(_("Notify if a point release is available"));
		chk.active = App.notify_minor;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_notify_minor = chk;

		chk.toggled.connect(()=>{
			App.notify_minor = chk_notify_minor.active;
		});

		if (App.VERBOSE>1) {
			label = new Label("( VERBOSE > 1 : "+_("Seconds interval enabled for debugging")+" )");
			label.xalign = (float) 0.0;
			label.margin_bottom = 6;
			vbox_main.add (label);
		}

		// notification interval value

		// replace invalid debug-only values with valid values
		int max_intervals = 52;
		if (App.VERBOSE>1) {
			// debug allows seconds, allow up to 1 hour of seconds
			max_intervals = 3600;
		} else {
			if (App.notify_interval_unit == 3) {
				App.notify_interval_value = 1;
				App.notify_interval_unit = 0;
			}
		}

		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox);

		label = new Label(_("Check every"));
		label.xalign = (float) 0.0;
		label.margin_start = 6;
		hbox.add (label);

		var adjustment = new Gtk.Adjustment(App.notify_interval_value, 1, max_intervals, 1, 1, 0);
		var spin = new Gtk.SpinButton (adjustment, 1, 0);
		spin.xalign = (float) 0.5;
		hbox.add(spin);
		var spin_notify = spin;

		spin.changed.connect(()=>{ App.notify_interval_value = (int) spin_notify.get_value(); });

		// notify interval unit
		var combo = new Gtk.ComboBox();
		var cell_text = new Gtk.CellRendererText();
		combo.pack_start(cell_text, false);
		combo.set_attributes(cell_text, "text", 0);
		hbox.add(combo);

		combo.changed.connect(()=>{ App.notify_interval_unit = combo.active; });

		TreeIter iter;
		var model = new Gtk.ListStore (1, typeof (string));
		model.append (out iter);
		model.set (iter,0,_("Hours"));
		model.append (out iter);
		model.set (iter,0,_("Days"));
		model.append (out iter);
		model.set (iter,0,_("Weeks"));
		if (App.VERBOSE>1) {
			model.append (out iter);
			model.set (iter,0,_("Seconds"));
		}
		combo.set_model(model);
		combo.set_active(App.notify_interval_unit);

		// filters
		label = new Label("<b>" + _("Filters") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_top = 12;
		label.margin_bottom = 6;
		vbox_main.add (label);

		// chk_hide_unstable
		chk = new CheckButton.with_label(_("Hide unstable and RC releases"));
		chk.active = App.hide_unstable;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_hide_unstable = chk;
		chk.toggled.connect(()=>{ App.hide_unstable = chk_hide_unstable.active; });

		// kernel version threshold
		hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox);

		label = new Label(_("Show"));
		label.xalign = (float) 0.0;
		label.margin_start = 6;
		hbox.add (label);

		var spm_adj = new Gtk.Adjustment(App.previous_majors, -1, LinuxKernel.kernel_latest_available.version_major , 1, 1, 0);
		var spm_spin = new Gtk.SpinButton (spm_adj, 1, 0);
		spm_spin.xalign = (float) 0.5;
		hbox.add(spm_spin);
		spm_spin.changed.connect(()=>{ App.previous_majors = (int) spm_spin.get_value(); });

		label = new Label(_("previous major versions  ( -1 = all )"));
		hbox.add(label);

		// network
		label = new Label("<b>" + _("Network") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_top = 12;
		label.margin_bottom = 6;
		vbox_main.add (label);

        // connect timeout
		hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox);

		label = new Label(_("Internet connection timeout in"));
		label.xalign = (float) 0.0;
		label.margin_start = 6;
		hbox.add (label);

		adjustment = new Gtk.Adjustment(App.connect_timeout_seconds, 1, 60, 1, 1, 0);
		spin = new Gtk.SpinButton (adjustment, 1, 0);
		spin.xalign = (float) 0.5;
		hbox.add(spin);
		var spin_timeout = spin;
		spin.changed.connect(()=>{ App.connect_timeout_seconds = (int) spin_timeout.get_value(); });

		label = new Label(_("seconds"));
		hbox.add(label);

		// concurrent downloads
		hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox);

		label = new Label(_("Max concurrent downloads"));
		label.xalign = (float) 0.0;
		label.margin_start = 6;
		hbox.add (label);

		adjustment = new Gtk.Adjustment(App.concurrent_downloads, 1, 25, 1, 1, 0);
		spin = new Gtk.SpinButton (adjustment, 1, 0);
		spin.xalign = (float) 0.5;
		hbox.add(spin);
		var spin_concurrent = spin;

		spin.changed.connect(()=>{ App.concurrent_downloads = (int) spin_concurrent.get_value(); });

		// verify_checksums
		chk = new CheckButton.with_label(_("Verify Checksums with the CHECKSUMS files"));
		chk.active = App.verify_checksums;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_verify_checksums = chk;
		chk.toggled.connect(()=>{ App.verify_checksums = chk_verify_checksums.active; });

		// proxy
		label = new Label(_("Proxy"));
		label.xalign = (float) 0.0;
		label.margin_start = 6;
		vbox_main.add (label);

		var proxy = new Entry ();
		proxy.set_placeholder_text("[http://][USER:PASSWORD@]HOST[:PORT]");
		proxy.set_text(App.all_proxy);
		proxy.activate.connect(()=>{ App.all_proxy = proxy.get_text(); });
		proxy.margin_start = 6;
		vbox_main.add(proxy);

// too easily screwed up and "blank to return to default" isn't working
/*
		// ppa url
		label = new Label("<b>" + "PPA" + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_bottom = 6;
		vbox_main.add (label);

		var ppa = new Entry ();
		ppa.set_placeholder_text(DEFAULT_PPA_URI);
		ppa.set_text(App.ppa_uri);
		ppa.activate.connect(()=>{ App.ppa_uri = ppa.get_text(); });
		vbox_main.add(ppa);
*/

		// ok
		var button = (Button) add_button ("gtk-ok", Gtk.ResponseType.ACCEPT);
		button.clicked.connect(()=>{ this.close(); });
		this.destroy.connect(btn_ok_click);
		show_all();

		// DEBUG rapid toggle stress test
		//if (VERBOSE==999) {
		//	App.hide_unstable = !App.hide_unstable;
		//	this.close();
		//}

	}

	private void btn_ok_click() {
		App.save_app_config();
	}
}
