#!/usr/bin/perl -w

use strict;
use LIFX;
use Data::Dumper;

my $lifx = LIFX->new();

while(1) {
    my $msg = $lifx->next_message();
    print Dumper($msg);
}

