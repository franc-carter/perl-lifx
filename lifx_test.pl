#!/usr/bin/perl -w

use strict;
use LIFX;
use Data::Dumper;

my $lifx = LIFX->new();

while(1) {
    my $msg   = $lifx->next_message();
    my $study = $lifx->get_bulb_by_label("Study");
    if (defined($study)) {
        my $hsbk = [0,0,5,2500];
        #$study->set_colour($hsbk,1000);
        $study->set_power(0);
    }
}

