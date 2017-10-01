#!C:\Strawberry\perl\bin 

use strict;
use Net::Ping;

my $config_file = "ip_list";

my $time_out = 3; 
my $show_connected = 1;
my $show_disconnected = 1;

#read params
my $view = @ARGV;

#parsing the list of parameters
for (my $i=0; $i <= $#ARGV; $i++) {
    my ($command, $value) = split(/=/, $ARGV[$i]); 
    #change viev-mod for addresses
    if ($command eq "-v") {
        if ($value eq "only_up") {
	        $show_connected = 1;
	        $show_disconnected = 0;
	    } elsif ($value eq "only_down") {
	        $show_connected = 0;
	        $show_disconnected = 1;
	    } else {
	        print "Unknown argument for -v option\n";
	    }
    }
    #change path to config
    if ($command eq "-c") {
        $config_file = $value;
    }
    #set timeout
    if ($command eq "-t") {
	    $time_out = $value;
    }
}

#hash for the address list
open(CONFIG, $config_file) or die "Can't open file - $config_file!\n";
my $net = Net::Ping->new("icmp");
#read line by line
while (my $line = <CONFIG>) {
    #ignore lines with comments
    if ($line !~ /^#/) {
        my ($address, $description) = split(" ", $line);
		#find subnet
        if ($address =~ /.\//) {
            my ($subnet, $bitmask) = split(/\//, $address);
			calcSubnet($subnet, $bitmask, $description);
        } else {
			ping($address, $description);
		}
    }
}

sub ping {
	if ($net->ping($_[0], $time_out)) {
		if ($show_connected == 1) {
			print "$_[0]($_[1])\t now is UP\n";
		}
    } else {
		if ($show_disconnected == 1) {
			print "$_[0]($_[1])\t now is DOWN\n";
		}
	}
}

sub calcSubnet {
	my ($first_octet, $second_octet, $third_octet, $fourth_octet) = split(/\./, $_[0]);
	my $description = $_[2];
 	
	#patterns for find values in octets 
	my $pattern = 0b11111111111111111111111111111111;
	my $pattern_second_octet = 0b11111111000000000000000000000000;
	my $pattern_third_octet = 0b11111111111111110000000000000000;
	my $pattern_fourth_octet = 0b11111111111111111111111100000000;
	my $pattern_simple = 0b11111111;
	
	#forming mask  
	my $bitmask = $_[1];
	my $shift_mask_left = $pattern >> (32 - $bitmask);
	my $netmask = $shift_mask_left << $bitmask;
	$netmask = $netmask << (32 - ($bitmask * 2));
	
	#...and write by octets
	my @octets = (0b0, 0b0, 0b0, 0b0); 
	$octets[0] = $netmask >> 24;
	if ($bitmask > 8) {		
		$octets[1] = $netmask ^ $pattern_second_octet;
		$octets[1] = $octets[1] << 8;
		$octets[1] = $octets[1] >> 24;
		if ($bitmask > 16) {
			$octets[2] = $netmask ^ $pattern_third_octet;
			$octets[2] = $octets[2] << 16;
			$octets[2] = $octets[2] >> 24;
		}
		if ($bitmask > 24) {	
			$octets[3] = $netmask ^ $pattern_fourth_octet;
			$octets[3] = $octets[3] << 24;
			$octets[3] = $octets[3] >> 24;
		}
	} 

	#create arrays for initial and max addresses by subnet
	my @initial_address = ($first_octet, $second_octet, $third_octet, $fourth_octet);
	my @max_address = ($first_octet, $second_octet, $third_octet, $fourth_octet);
	
	#calculation initial and max address using bitmask previously obtained
	if ($bitmask < 8) {
		$initial_address[0] = $initial_address[0] >> (8 - $bitmask);
		$initial_address[0] = $initial_address[0] << (8 - $bitmask);
		$max_address[0] = $initial_address[0] + ($pattern_simple ^ $octets[0]);
		$initial_address[1] = $initial_address[2] = $initial_address[3] = 0b00000000;
		$max_address[1] = $max_address[2] = $max_address[3] = 0b11111111;
	} elsif ($bitmask >= 8 && $bitmask < 16) {
		$initial_address[1] = $initial_address[1] >> (16 - $bitmask);
		$initial_address[1] = $initial_address[1] << (16 - $bitmask);
		$max_address[1] = $initial_address[1] + ($pattern_simple ^ $octets[1]);
		$initial_address[2] = $initial_address[3] = 0b00000000;
		$max_address[2] = $max_address[3] = 0b11111111;
	} elsif ($bitmask >= 16 && $bitmask < 24) {
		$initial_address[2] = $initial_address[2] >> (24 - $bitmask);
		$initial_address[2] = $initial_address[2] << (24 - $bitmask);
		$max_address[2] = $initial_address[2] + ($pattern_simple ^ $octets[2]);
		$initial_address[3] = 0b00000000;
		$max_address[3] = 0b11111111;
	} elsif ($bitmask >= 24) {
		$initial_address[3] = $initial_address[3] >> (32 - $bitmask);
		$initial_address[3] = $initial_address[3] << (32 - $bitmask);
		$max_address[3] = $initial_address[3] + ($pattern_simple ^ $octets[3]);
	}
	
	for (my $first = $initial_address[0]; $first <= $max_address[0]; $first = $first + 0b00000001) {
		for (my $second = $initial_address[1]; $second <= $max_address[1]; $second = $second + 0b00000001) {
			for (my $third = $initial_address[2]; $third <= $max_address[2]; $third = $third + 0b00000001) {
				for (my $fourth = $initial_address[3]; $fourth <= $max_address[3]; $fourth = $fourth + 0b00000001) {
					#ignore subnet in the array of addresses
					if (($fourth != $initial_address[3]) || ($third != $initial_address[2] && $third != $initial_address[3]) || ($second != $initial_address[1] && $second != $initial_address[2] && $second != $initial_address[3]) || ($first != $initial_address[0] && $first != $initial_address[1] && $first != $initial_address[2] && $first != $initial_address[3])) {
						ping("$first.$second.$third.$fourth", $description);
					}
				}
			}
		}
	}
}

print "Press any key";
my $goodbye = <STDIN>;
print "Bye";
