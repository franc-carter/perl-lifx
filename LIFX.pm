package LIFX;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;

    my $self = {};
    $self->{args} = \%args;
    $self->{status} = "Status";

    return bless $self, $class;
}

sub status {
    my ($self) = @_;

    print $self->{status},"\n";;
}

1;

