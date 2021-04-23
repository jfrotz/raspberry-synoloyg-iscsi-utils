#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

iscsi-mount.pl

=head1	USAGE

curl https://jfrotz.synology.me/~ffaatuai/iscsi-mount.pl | perl

=head1	DESCRIPTION

Login to our iSCSI LUN.
Unmount the LVM paritions (and mount the SD card back into place).
Logout of our iSCSI LUN.

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
    &umount_iscsi_lvm( $cfg ); 
    &iscsiadm_logout( $cfg );
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
sub	umount_iscsi_lvm
{
    my( $cfg )	= shift;
    &lsblk( $cfg );

    if ($cfg->{lun}->{path} ne "")
    {
	&execute( $cfg, "sudo mount /dev/mmcblk0p2 /" );
	&execute( $cfg, "sudo umount /home" );
	&execute( $cfg, "sudo umount /var" );
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
