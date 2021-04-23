#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

iscsi-report.pl

=head1	USAGE

perl iscsi-report.pl

=head1	DESCRIPTION

Report on Raspberry Pi mounts in /proc/self/mounts (source behind /etc/mtab).
Report on Raspberry Pi devices in /dev (SD card and iSCSI LUN / LVM partitions).

=head1	RELATED

iscsi-discovery.pl - Discover the iSCSI portal on the local subnet.
iscsi-create.pl - Create LVM file systems for /, /var and /home on the machine-specific LUN.
iscsi-copy.pl - Copy /, /var and /home to the LVM partitions.
iscsi-mount.pl - Mount the LVM partitions into place and stop using the SD card.
iscsi-umount.pl - Unmount the LVM partitions and step back to the SD card.
iscsi-destroy.pl - Clean up the LUN so that we can re-run iscsi-create.pl again.
iscsi-report.pl - Report on /proc/self/mounts and /dev.

=cut

use Data::Dumper;

$| = 1;

&main( @ARGV );
exit( 0 );




#----------------------------------------------------------------------
sub	main
{
    my( $cfg )	= &init( {} );

    &report_proc_self_mounts( $cfg, "mmcblk" );
    &report_proc_self_mounts( $cfg, "mapper" );
    &report_devices( $cfg );
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
sub	report_devices
{
    my( $cfg )	= shift;
    
    print "Linux SD Card:\n";
    print "----------------------------------------------------------------------\n";
    print `find /dev -ls | grep mmcblk0`;
    print "\n";

    print "Linux iSCSI Devices:\n";
    print "----------------------------------------------------------------------\n";
    print `find /dev -ls | grep sd`;
    print "\n";

    print "LVM Block Devices:\n";
    print "----------------------------------------------------------------------\n";
    print `find /dev/dm-* -ls`;
    print "\n";

    print "LVM Logical Volume Groups / Volumes:\n";
    print "----------------------------------------------------------------------\n";
    print `find /dev -ls | grep dm- | grep -v disk | grep -v block | grep -v mapper`;
    print "\n";

    print "LVM References:\n";
    print "----------------------------------------------------------------------\n";
    print `find /dev/disk -ls | grep dm-`;
    print `find /dev/block -ls | grep dm-`;
    print "\n";

    print "Current Filesystem Mounts:\n";
    print "----------------------------------------------------------------------\n";
    print `df -h`;
}




#----------------------------------------------------------------------
sub	report_proc_self_mounts
{
    my( $cfg )		= shift;
    my( $subset )	= shift;
    my( $cmd )		= "sudo cat /proc/self/mounts | grep $subset";
    my( @lines )	= &execute( $cfg, $cmd );
    foreach my $line (@lines)
    {
	print $line;
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
