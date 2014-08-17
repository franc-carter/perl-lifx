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

my $now = $bulb->color();

my @blue = (45000,100,40,0);
print "Going to Blue over 5 seconds\n";
$bulb->color(\@blue,5);
sleep(10);

my @red = (0,100,50,0);
print "Going to Red over 5 seconds\n";
$bulb->color(\@red,5);
sleep(10);

my @green = (25000,100,50,0);
print "Going to Green over 5 seconds\n";
$bulb->color(\@green,5);
sleep(10);

print "restoring\n";
$bulb->color($now,1);

