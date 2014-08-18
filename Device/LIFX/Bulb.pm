
package Device::LIFX::Bulb;

use strict;
use warnings;
use POSIX;
use IO::Socket;
use Data::Dumper;

sub new($$)
{
    my ($class,$hub,$bulb) = @_;

    my $self      = {};
    $self->{hub}  = $hub;
    $self->{bulb} = $bulb;

    return bless $self, $class;
}

sub color($$$)
{
    my ($self, $hsbk, $t) = @_;

    if (defined($hsbk)) {
        $self->{hub}->set_color($self, $hsbk, $t);
    } else {
        return $self->{bulb}->{color};
    }
}

sub rgb($$$)
{
    my ($self, $rgb, $t) = @_;

    if (defined($rgb)) {
        $self->{hub}->set_rgb($self, $rgb, $t);
    } else {
        return $self->{bulb}->{color};
    }
}

sub power($$)
{
    my ($self, $power) = @_;

    if (defined($power)) {
        $self->{hub}->set_power($self, $power);
    } else {
        return $self->{bulb}->{power};
    }
}

sub request_wifi_info($)
{
    my ($self) = @_;

    $self->{hub}->request_wifi_info($self);
}

sub off($)
{
    my ($self) = @_;

    $self->power(0);
}

sub on($)
{
    my ($self) = @_;
    $self->power(1);
}

sub label($$)
{
    my ($self,$label) = @_;

    if (defined($label)) {
       # set label
    } else {
        return $self->{bulb}->{label};
    }
}

1;



