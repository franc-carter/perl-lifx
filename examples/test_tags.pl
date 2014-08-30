#!/usr/bin/perl -w

use strict;
use Device::LIFX;
# use Device::LIFX::Constants qw(TAGS TAG_LABELS);
use POSIX qw(strftime);
use Data::Dumper;

my $action = shift(@ARGV);
if ($ARGV[0] eq '-d') {
    shift @ARGV;
}

my $lifx = Device::LIFX->new();
$lifx->wait_for_quiet(1);
my $bulb = $lifx->get_bulb_by_label($ARGV[0]);

if ($action eq '-d') {
    $bulb->remove_tag($ARGV[1]);
} else {
    $bulb->add_tag($ARGV[1]);
}
$lifx->wait_for_quiet(1);

my @tags = $lifx->all_tags();
foreach my $t (@tags) {
    print "TAG: $t\n";
    my @bulbs = $lifx->get_bulbs_by_tag($t);
    for my $b (@bulbs) {
        print "    ",$b->label(),"\n";
    }
}

@tags = $bulb->tags();
print "Bulb: $ARGV[0]\n";
foreach my $t (@tags) {
    print "    $t\n";
}
