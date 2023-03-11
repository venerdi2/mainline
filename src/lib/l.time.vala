namespace l.time {

	public GLib.Timer timer_start() {
		var timer = new GLib.Timer();
		timer.start();
		return timer;
	}

	public ulong timer_elapsed(GLib.Timer timer, bool stop = true) {
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop) timer.stop();

		return (ulong)((seconds * 1000 ) + (microseconds / 1000));
	}

	public void sleep(int milliseconds) {
		Thread.usleep ((ulong) milliseconds * 1000);
	}
}
