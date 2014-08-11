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
