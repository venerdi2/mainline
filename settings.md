# Settings

## Notification
**\[ \] Notify if a major release is available**  
**\[ \] Notify if a point release is available**  
**Check every \[#\] \[units\]**  
Starts a background process that periodically checks for new kernels and sends a desktop notification if a kernel is available that you don't have installed yet.  
The monitor is installed in your desktop autostart folder such that it is started in the background any time you log in.  
It is removed by unselecting both checkboxes.  

## Filters
**\[ \] Hide unstable and RC releases**  
Excludes less stable more bleeding edge -rc kernels from the list.

**Show N previous major versions \[#\]**  
Defines a threshold value for the oldest major version to include in the display, as an offset from the whatever the current latest version is.  

The algorithm is essentially this pseudocode:  
threshold_major = min( latest_available - N , oldest_installed )  

In other words, whichever is lower: the latest major version available minus N, or the oldest major version you have installed.

The special value "-1" is also allowed, and means always show all kernel versions. With this value the initial cache update takes a long time, but it's actually usable after that.

Generally, you want this setting to just be 0.  

Distribution (non-mainline) kernels are not included when determining the lowest or highest installed versions.  

## Network
**Internet connection timeout in \[##\] seconds**  
**Max concurrent downloads \[#\]**  

**\[ \] Verify Checksums**  
When downloading .deb packages, first download the CHECKSUMS file and extract the sha-256 hashes from it, and use them to verify the .deb file downloads.

**Proxy
\[                               \]**  
proxy support via aria2c's [all-proxy](https://aria2.github.io/manual/en/html/aria2c.html#cmdoption-all-proxy) setting
