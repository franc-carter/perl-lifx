#!/usr/bin/perl -w

use strict;
use LIFX;
use Data::Dumper;

my $lifx = LIFX->new();

while(1) {
    my $msg   = $lifx->next_message(1);
    print Dumper($msg);
    my @bulbs = $lifx->get_all_bulbs("Study");
}

