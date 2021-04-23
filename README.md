# raspberry-synoloyg-iscsi-utils
Perl scripts to perform iSCSI discovery, LVM creation for /, /var, and /home given standardized (default) LUNs, mirroring, mounting unmounting and destruction scripts.

# Applicability
* This git repo will be useful to you if:
  * You have at least 2 Raspberry Pis AND an iSCSI server (in my case a Synology iSCSI Manager).
  * You want each Raspberryuy Pi to be have machine-specific storage mounts for /, /home and /var.
  * You want to have /, /home and /var on LVM partitions so that you can grow the partitions as necessary (within the limits of your pre-allocated LUN).
  * You want to change the personality of a given Raspberry Pi by inserting an SD card that self-identifies as a completely different host which then has a dedicated personality in /, /home and /var.

# Synology iSCSI Manager
1. Create a target named for the fully qualified hostname for each Rasperry Pi (e.g. rpi4-8-3.home.example.com).
2. Create and map a LUN as part of the target creation with the same fully qualified hostname (e.g. rpi4-8-3.home.example.com).
3. Use Thick Provisioning to ensure contiguous space allocation on your NAS.
4. Provide sufficient storage (40G min; 50G suggested).

# Planned LVM partition sizes:
* / - 10G LVM
* /home - 20G LVM
* /var - 10G LVM
* 10G spare to re-allocate as needed when a 50G LUN is allocated.

# Raspberry Pi Commands
1. `perl iscsi-discovery.pl` - Discover the Synology iSCSI Manager, connect and eliminate all interfaces except the fully qualified hostname on a single network.
2. `perl iscsi-create.pl` - Create the LVM partitions rootfs, homefs and varfs.
3. `perl iscsi-copy.pl` - Mirror your current /, /home, and /var to the LVM partitions rootfs, homefs and varfs, then mount those LVM partitions into place.
4. `perl iscsi-report.pl` - Report how the SD card, the iSCSI LUN and LVM partitions are mapped into /dev.

# Rebooting
1. `perl iscsi-umount.pl` - Disconnect the LUN before rebooting.
2. `perl iscsi-report.pl`
3. `sudo reboot`
4. `perl iscsi-report.pl`

# After Booting
1. `perl iscsi-report.pl`
2. `perl iscsi-mount.pl` - Reconnect the LUN.
3. `perl iscsi-report.pl`

# Destruction and Recreation
1. `perl iscsi-report.pl`
2. `perl iscsi-destroy.pl` - Unravel the LVM patitions for subsequent reconstruction.
3. `perl iscsi-report.pl`
4. `sudo reboot`
5. `perl iscsi-create.pl`

# CONTRASTS
* Shared storage, such as NFS, makes it difficult to have distinct debian packages installed per Raspberry Pi.
* Shared storage provides for easily shared and mounted file systems.
* Dedicated storage, such as iSCSI LUNs, makes it very easy to uniquely install distinct debian packages on each Raspberry Pi instance.
* Dedicated storage provides ability for mounting read-only LUNs which are mapped to multiple Raspberry Pis, but that is not part of this project's default support.
* Dedicated storage provides ability to mount non-default read-write LUNs but these become tricky and are not part of this project's default support.

# DISCLAIMER
* These perl scripts are provided and coded to give you an understanding into the commands needed to do these operations by hand, but to do them in the proper sequence so that you don't have to do them by hand.
* It is expected that you perform your own backups, since a Synology NAS is expected as part of the network environment.
* These scripts provide support for a higher level of resiliency in the Raspberry Pi environment, but it still requires you to pay attention and be aware of what you are tossing away when you perform iscsi-destroy.pl (no prompt is given before destruction commences).
* Use at your own risk.

# TODO
1. Verify X is happy once the LVM partitions are mounted into place.
2. Hook into the boot process and verify that the iSCSI connect occurs correctly during the boot cycle.
   * `/lib/open-iscsi/activate-storage.sh` is part of this, but I'm still chasing where the correct iSCSI connect command / location is.  It is likely magic based on /etc/fstab.

# LIMITATIONS
1. The LVM is not mapped into /etc/fstab yet.
2. The LUN is not yet successfully connecting during boot.  A specific `perl iscsi-mount.pl` is required after booting from the SD card.
