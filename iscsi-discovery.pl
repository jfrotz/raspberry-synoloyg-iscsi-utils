#!perl
#----------------------------------------------------------------------
=pod

=head1	NAME

iscsi-discovery.pl

=head1	USAGE

perl iscsi-discovery.pl

=head1	DESCRIPTION

Identify our iSCSI Target / LUN which is explicitly named for our hostname.

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
    my( $subnet_prefix ) = shift || "192";	## Default is a 192.x.x.x class C address block
    my( $cfg )	= &init( { subnet_prefix => $subnet_prefix } );

    if  (&configure_iscsid_conf( $cfg ))
    {
	&iscsiadm_connect( $cfg );
	&iscsiadm_login( $cfg );
	&iscsiadm_session( $cfg );
    }
}




#----------------------------------------------------------------------
sub	init
{
    my( $cfg )	= shift;

    $cfg->{iscsi}->{portal}	= &iscsi_portal( $cfg );

    $cfg->{config}->{hostname}	=`hostname`;
    chomp( $cfg->{config}->{hostname} );

    return( $cfg );
}





#----------------------------------------------------------------------
sub	iscsiadm_connect
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo iscsiadm -m discovery -t st --portal $cfg->{iscsi}->{portal}";
    print "EXEC: $cmd\n";
    my( @output )	= `$cmd`;
    &remove_unrelated_iscsi_nodes( $cfg );
    &reduce_iscsi_interface_to_ipv4( $cfg );
    &reduce_unrelated_iscsi_send_targets( $cfg );
}




#----------------------------------------------------------------------
sub	remove_unrelated_iscsi_nodes
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo ls -1 /etc/iscsi/nodes";
    my( @hosts )= `$cmd`;
    foreach my $host (@hosts)
    {
	print $host;
	chomp( $host );
	if ($host eq $cfg->{config}->{hostname})
	{
	    print "Identified correct iSCSI target configuration: /etc/iscsi/nodes/$host\n";
	    $cfg->{iscsi}->{node}	= $host;
	}
	else
	{
	    `sudo rm -rf /etc/iscsi/nodes/$host`;
	}
    }
}



#----------------------------------------------------------------------
sub	reduce_iscsi_interface_to_ipv4
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo ls -1 /etc/iscsi/nodes/$cfg->{config}->{hostname}";
    my( @ports )= `$cmd`;
    foreach my $address (@ports)
    {
	print $address;
	chomp( $address );
	if  ($address =~ /^169|\:/)
	{
	    `sudo rm -rf /etc/iscsi/nodes/$cfg->{config}->{hostname}/$address`;
	}
	else
	{
	    print "Identified correct iSCSI target address: /etc/iscsi/nodes/$cfg->{iscsi}->{node}/$address\n";
	    $cfg->{iscsi}->{address} = $address;
	}
    }
}




#----------------------------------------------------------------------
sub	reduce_unrelated_iscsi_send_targets
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo ls -1 /etc/iscsi/send_targets/$cfg->{iscsi}->{portal},3260";
    print "$cmd\n";
    my( @list )	= `$cmd`;
    foreach my $target (@list)
    {
	print $target;
	chomp( $target );
	if  ($target eq "$cfg->{iscsi}->{node},$cfg->{iscsi}->{address},default")
	{
	    print "Identified correct iSCSI send target: $target\n";
	}
	else
	{
	    `sudo rm /etc/iscsi/send_targets/$cfg->{iscsi}->{portal},3260/$target`;
	}
    }
}




#----------------------------------------------------------------------
sub	iscsiadm_login
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo iscsiadm -m node  --targetname $cfg->{config}->{hostname} --portal $cfg->{iscsi}->{portal} --login";
    print "EXEC: $cmd\n";
    my( @output )	= `$cmd`;
    &remove_unrelated_iscsi_nodes( $cfg );
}



#----------------------------------------------------------------------
sub	iscsiadm_session
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo iscsiadm -m session";
    my( @rows )	= &execute( $cfg, $cmd );
    return( $#rows+1 );
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





#----------------------------------------------------------------------
sub	ifconfig
{
    my( $cfg )	= shift;
    my( $cmd )	= "ifconfig | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep $cfg->{subnet_prefix}";
    my( $line ) = &execute( $cfg, $cmd );
    my( @parts )	= split( /\s+/, $line );
    my( $addr )		= $parts[2];
    my( $netmask )	= $parts[5];
    my( $cidr )	= "/24";
    my( @octets )	= split( /\./, $addr );
    my( @subnet )	= split( /\./, $netmask );
    if  ($subnet[$#subnet] == 0)
    {
	pop( @octets );
	push( @octets, "0/24" );
	$cfg->{nmap_subnet}	= join( ".", @octets );
	print "Nmap Subnet: $cfg->{nmap_subnet}\n";
	return;
    }
    print "Default Nmap Subnet: 192.168.7.0/24\n";	## Complete failure.  Use my home subnet.
    $cfg->{nmap_subnet}	= "192.168.7.0/24";
}




#----------------------------------------------------------------------
sub	nmap
{
    my( $cfg )	= shift;
    my( $cmd )	= "sudo nmap -p 3260 $cfg->{nmap_subnet}";
    print "EXEC: $cmd\n";
    my( @lines ) = `$cmd`;
    my( $state )	= "";
    my( $machine )	= "";
    my( $ip )	= "";
    foreach my $line (@lines)
    {
	if  ($line =~ /Nmap scan report for (.+) \((\d+\.\d+\.\d+\.\d+)\)/)
	{
	    $machine	= $1;
	    $ip		= $2;
	}
	if  ($line =~ /open/)
	{
	    $state = "address";
	    my( $portal )	= $machine;
	    print "Found iscsi/tcp on $portal ($ip)\n";
	    return( $portal );
	}
    }
    return( "127.0.0.1" );		## Should be sufficient to break iscsiadm on the loopback.
}





#----------------------------------------------------------------------
sub	iscsi_portal
{
    my( $cfg )	= shift;
    
    &ifconfig( $cfg );
    return( &nmap( $cfg ) );
}





#----------------------------------------------------------------------
sub	configure_iscsid_conf
{
    my( $cfg )	= shift;
    my( $file )	= "/etc/iscsi/iscsid.conf";

    if  (open( CONF, $file ))
    {
	my( @lines )	= <CONF>;
	close( CONF );
	if  (open( CONF, ">$file" ))
	{
	    foreach my $line (@lines)
	    {
		if  ($line =~ /\# node.startup = automatic/)
		{
		    print CONF "node.startup = automatic\n";
		    print "iSCSI node.startup = automatic\n";
		}
		elsif ($line =~ /^\s*node.startup = manual/)
		{
		    print CONF "# node.startup = manual\n";
		    print "iSCSCI manual node startup disabled.\n";
		}
		else
		{
		    print CONF $line;
		}
	    }
	    close( CONF );
	    return( 1 );
	}
	else
	{
	    print "WARNING: Unable to update $file: $!\n";
	    return( 0 );
	}
    }
}





