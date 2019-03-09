### Ubuntu Kernel Update Utility (Ukuu)

This is a tool for installing the latest mainline Linux kernel on Ubuntu-based distributions.

![](https://2.bp.blogspot.com/-76C_l3BcJyg/WNdzTpSoiKI/AAAAAAAAGKs/xOvB-LCH2cYiDpdbqWkeOLhY9I7TVACJwCLcB/s1600/ukuu_main_window.png)

### About This Fork

Since the original author stopped maintaining the free version of Ukuu and turned to a [paid version](https://teejeetech.in/tag/ukuu/), Several people have forked this project, and this is but one more. This fork started with https://github.com/stevenpwered/ukuu, and merged in https://github.com/cloyce/ukuu, and then I intend to add my own tweaks:
* First TODO Item (not done yet): STOP SAVING 6 GIGS OF KERNEL PACKAGES IN ~/.cache/ukuu HOLY GOBSMACK WTF ?????
<pre>
bkw@negre:~$ du -sh .cache/ukuu
5.5G    .cache/ukuu
</pre>

### Enhancements

*   Option in settings to skip internet connection check

Please feel free to submit a feature request in the Issues section.

### Features

*   Fetches list of kernels from [kernel.ubuntu.com](http://kernel.ubuntu.com/~kernel-ppa/mainline/)
*   Displays notifications when a new kernel update is available.
*   Downloads and installs packages automatically

### Screenshots

![](https://2.bp.blogspot.com/-76C_l3BcJyg/WNdzTpSoiKI/AAAAAAAAGKs/xOvB-LCH2cYiDpdbqWkeOLhY9I7TVACJwCLcB/s1600/ukuu_main_window.png)
_Main Window_

![](https://2.bp.blogspot.com/-ATv4vsOVOnc/WNdztEZHJNI/AAAAAAAAGKw/1pOIuyu8ITo4z8mnMK6MfCZ3T_Nd4gQNQCLcB/s1600/ukuu_settings.png)
_Settings Window_

![](https://4.bp.blogspot.com/-Y-1zhHcpk1M/WNd42_ybTyI/AAAAAAAAGLE/gLaBdWpoh54OGrvF81Ka1bCVJjZ0WqKrQCLcB/s1600/ukuu_console_options.png)
_Console Options_

### Downloads & Source Code
Ukuu is written using Vala and GTK3 toolkit. Source code and binaries are available from the [GitHub project page](https://github.com/aljex/ukuu).

### Build instruction

#### Ubuntu-based Distributions (Ubuntu, Linux Mint, Elementary, etc)  

 in a terminal window:  

    sudo apt install libgee-0.8-dev libjson-glib-dev libvte-2.91-dev valac
    git clone https://github.com/aljex/ukuu.git
    cd ukuu
    make all
    sudo make install
