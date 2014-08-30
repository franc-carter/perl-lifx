
package Device::LIFX::Bulb;

use strict;
use warnings;
use POSIX;
use IO::Socket;
use Data::Dumper;

sub new($$)
{
    my ($class,$hub,$mac) = @_;

    my $self      = {};
    $self->{hub}  = $hub;
    $self->{mac}  = $mac;
    $self->{tags} = 0;

    return bless $self, $class;
}

sub mac($)
{
    my ($self) = @_;

    return $self->{mac};
}

sub _set_color($$)
{
    my ($self, $hsbk) = @_;

    $self->{color} = $hsbk;
}

sub color($$$)
{
    my ($self, $hsbk, $t) = @_;

    if (defined($hsbk)) {
        $self->{hub}->set_color($self, $hsbk, $t);
    } else {
        return $self->{color};
    }
}

sub rgb($$$)
{
    my ($self, $rgb, $t) = @_;

    if (defined($rgb)) {
        $self->{hub}->set_rgb($self, $rgb, $t);
    } else {
        return $self->{color};
    }
}

sub _set_power($$)
{
    my ($self,$power) = @_;

    $self->{power} = $power;
}

sub power($$)
{
    my ($self, $power) = @_;

    if (defined($power)) {
        $self->{hub}->set_power($self, $power);
    } else {
        return $self->{power};
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

sub _set_label($$)
{
    my ($self,$label) = @_;

    $self->{label} = $label;
}

sub label($$)
{
    my ($self,$label) = @_;

    if (defined($label)) {
       # set label
    } else {
        return $self->{label};
    }
}

sub _set_last_seen($$)
{
    my ($self,$t) = @_;

    $self->{last_seen} = $t;
}

sub last_seen($)
{
    return $_[0]->{last_seen};
}

sub _set_tags($$)
{
    my ($self,$tags) = @_;

    $self->{tags} = $tags;
}

sub tag_mask($)
{
    return $_[0]->{tags};
}

sub _tag_ids()
{
    return $_[0]->{tags};
}

sub tags($)
{
    my ($self) = @_;

    my @bulb_tags;
    my @known_tags = $self->{hub}->_tag_ids();
    for my $t (@known_tags) {
        ($t & $self->{tags}) &&
            push(@bulb_tags, $self->{hub}->_tag_label($t));
    }
    return @bulb_tags;
}

sub add_tag($$)
{
    my ($self,$tag) = @_;

    $self->{hub}->add_tag_to_bulb($self,$tag);
}

sub remove_tag($$)
{
    my ($self,$tag) = @_;

    $self->{hub}->remove_tag_from_bulb($self,$tag);
}

sub request_tags($)
{
    my ($self) = @_;

    $self->{hub}->request_tags($self);
}

1;

