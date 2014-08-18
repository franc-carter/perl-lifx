#!/usr/bin/perl -w

use strict;
use Device::LIFX;
use Device::LIFX::Constants qw(WIFI_INFO);
use Data::Dumper;

my $lifx = Device::LIFX->new();

($#ARGV == 0) || die "Usage: $0 <label>|XX:XX:XX:XX:XX:XX";

my $mac = undef;
my @mac = split(':', $ARGV[0]);

if ($#mac == 5) {
    my @mac = map {hex($_)} @mac;
    $mac = pack('C*', @mac);
}

my $bulb = undef;
while(!defined($bulb)) {
    my $msg = $lifx->next_message(1);
    if (defined($mac)) {
        $bulb = $lifx->get_bulb_by_mac($mac);
    } else {
        $bulb = $lifx->get_bulb_by_label($ARGV[0]);
    }
}

$bulb->request_wifi_info();
while(1) {
    my $msg = $lifx->next_message(1);
    if (defined($msg) && ($msg->type() == WIFI_INFO)) {
        print "Signal         : ",$msg->signal(),"\n";
        print "Tx             : ",$msg->tx(),"\n";
        print "Rx             : ",$msg->rx(),"\n";
        print "mcu_temperature: ",$msg->mcu_temperature(),"\n";
        exit(0);
    }
}
