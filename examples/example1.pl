#!/usr/bin/perl -w

use strict;
use Device::LIFX;
use Device::LIFX::Constants;
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

my $on = $bulb->power();
if ($on) {
    print "Turning bulb off with power()\n";
    $bulb->power(0);
    sleep(2);
}

print "Turning bulb on with power()\n";
$bulb->power(1);
sleep(2);

print "Turning bulb off with off()\n";
$bulb->off();
sleep(2);

print "Turning bulb on with on()\n";
$bulb->on();

