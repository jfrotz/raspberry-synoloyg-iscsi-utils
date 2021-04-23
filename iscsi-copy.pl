#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

iscsi-copy.pl

=head1	USAGE

perl iscsi-copy.pl

=head1	DESCRIPTION

Rsync /bin, /sbin, /usr, /lib, /root to /media/rootfs
Rsync /home to /media/homefs
Rsync /var to /media/varfs
Unmount /media/rootfs
Unmount /media/homefs
Unmount /media/varfs
Mount /, /home and /var partitions from the LVM / iSCSI LUN.

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

    &iscsiadm_connect( $cfg );
    &mount_iscsi_lvm( $cfg ); 
}




#----------------------------------------------------------------------
sub	init
{
    my( $cfg )	= shift;

    my( $portal )	= `sudo ls -1 /etc/iscsi/send_targets`;
    my( @parts )	= split( ",", $portal );
    $cfg->{iscsi}->{portal}	= shift( @parts );

    $cfg->{config}->{hostname}	=`hostname`;
    chomp( $cfg->{config}->{hostname} );

    return( $cfg );
}





#----------------------------------------------------------------------
sub	iscsiadm_connect
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo iscsiadm -m session";
    my( @output )	= &execute( $cfg, $cmd );
    &iscsiadm_login( $cfg );
}




#----------------------------------------------------------------------
sub	iscsiadm_login
{
    my( $cfg )	= shift;
    my( $cmd )	= join( " ", 
			"sudo iscsiadm",
			"-m node",
			"--targetname '$cfg->{config}->{hostname}'",
			"--portal $cfg->{iscsi}->{portal}",
			"--login",
	);
    &execute( $cfg, $cmd );
}





#----------------------------------------------------------------------
sub	mount_iscsi_lvm
{
    my( $cfg )	= shift;
    &lsblk( $cfg );

    if ($cfg->{lun}->{path} ne "")
    {
	if (-l "/dev/vgpool/varfs" && ! -d "/media/varfs")
	{
	    &execute( $cfg, "sudo mkdir /media/varfs" );
	    &execute( $cfg, "sudo mount -t ext4 /dev/vgpool/varfs /media/varfs" );

	    &execute( $cfg, "sudo rsync -aXS /var/* /media/varfs" );

	    &execute( $cfg, "sudo umount /media/varfs" );
	    &execute( $cfg, "sudo rmdir /media/varfs" );
	}
	if (-l "/dev/vgpool/homefs" && ! -d "/media/homefs")
	{
	    &execute( $cfg, "sudo mkdir /media/homefs" );
	    &execute( $cfg, "sudo mount -t ext4 /dev/vgpool/homefs /media/homefs" );

	    &execute( $cfg, "sudo rsync -aXS /home/* /media/homefs" );

	    &execute( $cfg, "sudo umount /media/homefs" );
	    &execute( $cfg, "sudo rmdir /media/homefs" );
	}

	if (-l "/dev/vgpool/rootfs" && ! -d "/media/rootfs")
	{
	    &execute( $cfg, "sudo mkdir /media/rootfs" );
	    &execute( $cfg, "sudo mount -t ext4 /dev/vgpool/rootfs /media/rootfs" );

	    &execute( $cfg, "sudo rsync -aXS /bin /media/rootfs" );
	    &execute( $cfg, "sudo rsync -aXS /sbin /media/rootfs" );
	    &execute( $cfg, "sudo rsync -aXS /usr /media/rootfs" );
	    &execute( $cfg, "sudo rsync -aXS /lib /media/rootfs" );
	    &execute( $cfg, "sudo rsync -aXS /root /media/rootfs" );

	    &execute( $cfg, "sudo umount /media/rootfs" );
	    &execute( $cfg, "sudo rmdir /media/rootfs" );
	}

	&execute( $cfg, "sudo mount -t ext4 /dev/mapper/vgpool-varfs /var" );
	&execute( $cfg, "sudo mount -t ext4 /dev/mapper/vgpool-homefs /home" );
	&execute( $cfg, "sudo mount -t ext4 /dev/mapper/vgpool-rootfs /" );
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
