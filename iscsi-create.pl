#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

iscsi-create.pl

=head1	USAGE

perl iscsi-create.pl

=head1	DESCRIPTION

Login to our iSCSI LUN.
Create an LVM physical volume on whatever /dev/sd* device we find.  (There will be only one.)
Create an LVM logical volume pool - vgpool
Create an LVM logicical volume rootfs
Make the ext4 file system /dev/vgpool/rootfs
Create an LVM logicical volume /dev/vgpool/homefs
Make the ext4 file system /dev/vgpool/homefs
Create an LVM logicical volume /dev/vgpool/varfs
Make the ext4 file system /dev/vgpool/varfs

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
    &build_iscsi_lvm( $cfg ); 
}




#----------------------------------------------------------------------
sub	init
{
    my( $cfg )	= shift;

    $cfg->{config}->{hostname}	=`hostname`;
    chomp( $cfg->{config}->{hostname} );

    my( $portal )	= `sudo ls -1 /etc/iscsi/send_targets`;
    my( @parts )	= split( ",", $portal );
    $cfg->{iscsi}->{portal}	= shift( @parts );

    return( $cfg );
}





#----------------------------------------------------------------------
sub	iscsiadm_login
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo iscsiadm -m node --targetname '$cfg->{config}->{hostname}' --portal $cfg->{iscsi}->{portal} --login";
    &execute( $cfg, $cmd );
}





#----------------------------------------------------------------------
sub	build_iscsi_lvm
{
    my( $cfg )	= shift;

    sleep( 3 );
    &lsblk( $cfg );

    if ($cfg->{lun}->{path} ne "")
    {
	&execute( $cfg, "sudo pvcreate -ff $cfg->{lun}->{path}" );
	&execute( $cfg, "sudo vgcreate vgpool $cfg->{lun}->{path}" );

	&execute( $cfg, "sudo lvcreate -y -n rootfs -L 10g vgpool" );
	&execute( $cfg, "sudo mkfs -t ext4 /dev/vgpool/rootfs" );
	
	&execute( $cfg, "sudo lvcreate -y -n varfs -L 10g vgpool" );
	&execute( $cfg, "sudo mkfs -t ext4 /dev/vgpool/varfs" );
	
	&execute( $cfg, "sudo lvcreate -y -n homefs -L 20g vgpool" );
	&execute( $cfg, "sudo mkfs -t ext4 /dev/vgpool/homefs" );
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
	print Dumper( $cfg->{lun}, \@parts );
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





