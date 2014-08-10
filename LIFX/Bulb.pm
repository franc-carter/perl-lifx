
package LIFX::Bulb;

use strict;
use warnings;
use Data::Dumper;

sub new($$)
{
    my ($class,$hub,$bulb) = @_;

    my $self      = {};
    $self->{hub}  = $hub;
    $self->{bulb} = $bulb;

    return bless $self, $class;
}

sub set_colour($$$)
{
    my ($self, $hsbk, $t) = @_;

    $self->{hub}->set_colour($self, $hsbk, $t);
}

sub set_power($$)
{
    my ($self, $power) = @_;

    $self->{hub}->set_power($self, $power);
}

1;
