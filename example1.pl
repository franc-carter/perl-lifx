#!/usr/bin/perl -w

use strict;
use Device::LIFX;
use Device::LIFX::Constants;
use Data::Dumper;

my $lifx = Device::LIFX->new();

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

=begin

Bad:
26 00
00 14
00 00 00 00
30 00 00 00 00 00
00 00
4c 49 46 58 56 32
00 00
00 00 00 00 00 00 00 00
15 00
00 00
01 00

Good:
26 00
00 14
00 00 00 00
d0 73 d5 01 0f e0
00 00
4c 49 46 58 56 32
01 00
00 00 00 00 00 00 00 00
15 00
00 00
01 00


=cut

