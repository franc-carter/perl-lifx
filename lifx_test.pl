#!/usr/bin/perl -w

use strict;
use Device::LIFX;
use Device::LIFX::Constants;
use Data::Dumper;

my $lifx = Device::LIFX->new();

while(1) {
    my $msg   = $lifx->next_message(1);
    if (defined($msg)) {
        my $mac  = $msg->{header}->{target_mac_address};
        my $type = $msg->{header}->{packet_type};
        my $bulb = $lifx->get_bulb_by_mac($mac);
        if (defined($bulb)) {
            print $bulb->label(),": ";
        }
        print Device::LIFX::Constants::type2str($type),"\n";
    } else {
        print "Timeout\n";
    }
    my @bulbs = $lifx->get_all_bulbs("Study");
}

