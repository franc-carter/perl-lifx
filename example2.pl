#!/usr/bin/perl -w

use strict;
use LIFX;
use LIFX::Constants;
use Data::Dumper;

my $lifx = LIFX->new();

($#ARGV == 0) || die "Usage: $0 <label>";

my $bulb = undef;
while(!defined($bulb)) {
    my $msg = $lifx->next_message(1);
    $bulb   = $lifx->get_bulb_by_label($ARGV[0]);
}

my @now = $bulb->colour();

my @night = (0,0,5,2500);
print "Going to 2500K at 5% brightness over 5 seconds\n";
$bulb->colour(\@night,5);
sleep(6);

my @night = (0,0,100,6500);
print "Going to 6500K at 100% brightness over 10 seconds\n";
$bulb->colour(\@night,10);
sleep(11);

print "Restoring bulb to the original state\n";
$bulb->colour(\@now,0);
