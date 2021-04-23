#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

iscsi-destroy.pl

=head1	USAGE

perl iscsi-destroy.pl

=head1	DESCRIPTION

Log into our LUN.
Cleanup /media/homefs
Cleanup /media/varfs
Cleanup /media/rootfs
Mount the SD card /dev/mmcblk0p2 onto /
Unmount /home
Unmount /var
Display the LVM logical volume pool
Destroy the LVM logical volume pool
Display the LVM physical volume
Destroy the LVM physical volume (forcibly)
Ensure /etc/fstab does not refer to any LVM partitions.
Logout of the iSCSI LUN.

=head1	RELATED

iscsi-discovery.pl - Discover the iSCSI portal on the local subnet.
iscsi-create.pl - Create LVM file systems for /, /var and /home on the machine-specific LUN.
iscsi-copy.pl - Copy /, /var and /home to the LVM partitions.
iscsi-mount.pl - Mount the LVM partitions into place and stop using the SD card.
iscsi-umount.pl - Unmount the LVM partitions and step back to the SD card.
iscsi-destroy.py - Clean up the LUN so that we can re-run iscsi-create.pl again.

=cut

use Data::Dumper;

$| = 1;

&main( @ARGV );
exit( 0 );




#----------------------------------------------------------------------
sub	main
{
    my( $cfg )	= &init( {} );

    &iscsiadm_login( $cfg );
    &destroy_iscsi_lvm( $cfg ); 
    &cleanup_etc_fstab( $cfg );
    &iscsiadm_logout( $cfg );
    my( @references )	= `find /dev -ls | grep dm-`;
    if  ($#references + 1 > 0)
    {
	print "WARNING: reboot required to release /:\n";
	print @references;
    }
}




#----------------------------------------------------------------------
sub	init
{
    my( $cfg )	= shift;

    $cfg->{iscsi}->{portal}	= "192.168.7.213";

    $cfg->{config}->{hostname}	=`hostname`;
    chomp( $cfg->{config}->{hostname} );

    $cfg->{config}->{ip}	= `ifconfig | grep inet | grep 192 | awk '{print $2}'`;
    chomp( $cfg->{config}->{ip} );

    return( $cfg );
}





#----------------------------------------------------------------------
sub	iscsiadm_login
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo iscsiadm -m node --targetname $cfg->{config}->{hostname} --portal $cfg->{iscsi}->{portal} --login";
    &execute( $cfg, $cmd );
}





#----------------------------------------------------------------------
sub	iscsiadm_session
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo iscsiadm -m session";
    my( @lines )= &execute( $cfg, $cmd );
    return( $#lines + 1 );
}





#----------------------------------------------------------------------
sub	iscsiadm_logout
{
    my( $cfg )	= shift;
    my( $cmd )	= join( " ", 
			"sudo iscsiadm",
			"-m node",
			"--targetname '$cfg->{config}->{hostname}'",
			"--portal $cfg->{iscsi}->{portal}",
			"--logout",
	);
    &execute( $cfg, $cmd );
}





#----------------------------------------------------------------------
sub	destroy_iscsi_lvm
{
    my( $cfg )	= shift;
    &lsblk( $cfg );

    if ($cfg->{lun}->{path} ne "")
    {
	&execute( $cfg, "sudo umount /media/homefs" )	if (-d "/media/homefs");
	&execute( $cfg, "sudo umount /media/varfs" )	if (-d "/media/varfs");
	&execute( $cfg, "sudo umount /media/rootfs" )	if (-d "/media/rootfs");

	&execute( $cfg, "sudo mount" );

	&execute( $cfg, "sudo rm -rf /media/homefs" )	if (-d "/media/homefs");
	&execute( $cfg, "sudo rm -rf /media/varfs" )	if (-d "/media/varfs");
	&execute( $cfg, "sudo rm -rf /media/fs" )	if (-d "/media/rootfs");

	&execute( $cfg, "sudo mount /dev/mmcblk0p2 /" );
	&execute( $cfg, "sudo umount /var" );
	&execute( $cfg, "sudo umount /home" );

	&execute( $cfg, "sudo vgdisplay" );
	&execute( $cfg, "sudo lvremove -f vgpool $cfg->{lun}->{path}" );

	&execute( $cfg, "sudo vgdisplay" );
	&execute( $cfg, "sudo pvremove -y --force --force $cfg->{lun}->{path}" );
    }
}



#----------------------------------------------------------------------
sub	lsblk
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo lsblk --raw -o NAME,HCTL,STATE,PATH,FSTYPE,MOUNTPOINT,UUID,PARTUUID | grep ':'";
    my( $line ) = &execute( $cfg, $cmd );
    chomp( $line );
    my( @parts )	= split( " ", $line );
    my( $name, $hctl, $state, $path, $fstype, $mountpoint, $uuid, $partuuid ) = @parts;
    if  ($cfg->{lun}->{name} eq "" && 
	 $name ne "")
    {
	$cfg->{lun}->{name}		= $name;
	$cfg->{lun}->{htcl}		= $hctl;
	$cfg->{lun}->{path}		= $path;
	$cfg->{lun}->{fstype} 		= $fstype;
	$cfg->{lun}->{mountpoint}	= $mountpoint;
	$cfg->{lun}->{uuid} 		= $uuid;
	$cfg->{lun}->{partuuid} 	= $partuuid;
	$cfg->{lun}->{state} 		= $state;
	print "Found $cfg->{lun}->{path}\n";
    }
    else
    {
	print Dumper( $cfg->{lun} );
    }
    &execute( $cfg, $cmd );
}




#----------------------------------------------------------------------
sub	cleanup_etc_fstab
{
    my( $cfg )	= shift;
    if (open( FSTAB, "/etc/fstab" ))
    {
	my( @lines )	= <FSTAB>;
	close( FSTAB );
	if (open( FSTAB, ">/etc/fstab" ))
	{
	    print "Removing from /etc/fstab:\n";
	    foreach my $line (@lines)
	    {
		if  ($line =~ /mapper/)
		{
		    print $line;		## Display the line being removed.
		}
		else
		{
		    print FSTAB $line;		## Put the line back into the file.
		}
	    }
	    close( FSTAB );
	}
    }
}

#----------------------------------------------------------------------
sub	execute
{
    my( $cfg )	= shift;
    my( $cmd )	= shift;
    print "EXEC: $cmd\n";
    my( @lines )	= `$cmd`;
    print @lines;
    if  ($? > 0)
    {
	print "FAILED [$?]: $cmd: $!\n";
    }
    return( @lines );
}
