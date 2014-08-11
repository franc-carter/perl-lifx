
package LIFX::Bulb;

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

sub prettyPrint($)
{
    my ($self) = @_;

    my $status = $self->{bulb}->{status};
    my $hue    = $status->{hue};
    my $sat    = $status->{saturation};
    my $bri    = $status->{brightness};
    my $kel    = $status->{kelvin};
    my $pow    = $status->{power};
    my $label  = $status->{label};
    my $mac    = $self->{bulb}->{mac};
    my @mac    = unpack('C6', $mac);
    @mac       = map {sprintf("%02x",$_)} @mac;
    $mac       = join(":", @mac);

    print "$label($mac):\n";
    printf("  Hue:        %d\n", $hue);
    printf("  Saturation: %0.1f\n", $sat);
    printf("  Brightness: %0.1f\n", $bri);
    printf("  Kelvin:     %d\n", $kel);
    printf("  Power:      %d\n", $pow);
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



