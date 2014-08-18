#!/usr/bin/perl -w

use strict;
use Device::LIFX;
use Device::LIFX::Constants;
use Data::Dumper;

my $lifx = Device::LIFX->new();

($#ARGV == 0) || die "Usage: $0 <label>";

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

my $now = $bulb->color();

my @blue = (0,0,255);
print "Going to Blue over 5 seconds\n";
$bulb->rgb(\@blue,5);
sleep(10);

my @red = (255,0,0);
print "Going to Red over 5 seconds\n";
$bulb->rgb(\@red,5);
sleep(10);

my @green = (0,255,0);
print "Going to Green over 5 seconds\n";
$bulb->rgb(\@green,5);
sleep(10);

print "restoring\n";
$bulb->color($now,1);

