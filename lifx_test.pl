#!/usr/bin/perl -w

use strict;
use LIFX;
use Data::Dumper;

my $lifx = LIFX->new();

while(1) {
    my $msg   = $lifx->next_message();
    my @bulbs = $lifx->get_all_bulbs("Study");
    foreach my $b (@bulbs) {
        $b->prettyPrint();
        print "\n";
    }
}

