
using l.misc;

namespace l.gtk {

	public Gtk.Image? ld_icon(string icon_name, int icon_size) {
		Gdk.Pixbuf pix_icon = null;
		try {
			Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
			pix_icon = icon_theme.load_icon_for_scale(icon_name, Gtk.IconSize.MENU, icon_size, Gtk.IconLookupFlags.FORCE_SIZE);
		} catch (Error e) { vprint(e.message,1,stderr); }
		return new Gtk.Image.from_pixbuf(pix_icon);
	}

}
