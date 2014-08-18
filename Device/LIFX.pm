package Device::LIFX;

use strict;
use warnings;
use IO::Socket;
use IO::Select;
use Data::Dumper;
use List::Util;
use Device::LIFX::Constants qw(/.*/);
use Device::LIFX::Bulb;
use Device::LIFX::Message;

my $port = 56700;

sub new($)
{
    my ($class) = @_;

    my $self           = {};
    $self->{bulbs}     = {};
    $self->{gateways}  = {};
    $self->{port}      = $port;
    $self->{socket}    = IO::Socket::INET->new(
                             Proto => 'udp',
                             LocalPort => $port,
                             Broadcast => 1,
                         );

    defined($self->{socket}) || die "Could not create listen socket: $!\n";
    autoflush {$self->{socket}} 1;

    my $obj = bless $self, $class;

    $obj->find_gateways();

    return $obj;
}

sub tellBulb($$$$$)
{
    my ($self, $gw, $mac, $type, $payload) = @_;

    my $msg = Device::LIFX::Message->new(
                  $type,
                  BULB_COMMAND,
                  $mac,
                  $payload,
              );
    $self->{socket}->send($msg->{packet}, 0, $gw) || die "Uggh: $!";
}

sub tellAll($$$)
{
    my ($self, $type, $payload) = @_;

    my $msg = Device::LIFX::Message->new(
                  $type,
                  ALL_BULBS_REQUEST,
                  "\0\0\0\0\0\0",
                  $payload,
              );
    my $to = sockaddr_in($self->{port}, INADDR_BROADCAST);

    $self->{socket}->send($msg->{packet}, 0, $to) || die "Uggh: $!";
}

sub has_message($$)
{
    my ($self,$timeout) = @_;

    my $select = IO::Select->new($self->{socket});
    my @ready  = $select->can_read($timeout);

    return ($#ready >= 0);
}

sub get_message($$)
{
    my ($self) = @_;

    my $message;
    my $packet;

    my $from = recv($self->{socket}, $packet, 1024, 0);
    my $msg  = Device::LIFX::Message->new($from,$packet);
    my $mac  = $msg->bulb_mac();
    my $bulb = $self->get_bulb_by_mac($mac) || {};

    if ($msg->type() == LIGHT_STATUS) {
        my $label                           = $msg->label();
        $bulb->{color}                      = $msg->color();
        $bulb->{power}                      = $msg->power();
        $bulb->{mac}                        = $msg->bulb_mac();
        $bulb->{label}                      = $label;
        $self->{bulbs}->{byMAC}->{$mac}     = $bulb;
        $self->{bulbs}->{byLabel}->{$label} = $bulb;
    }
    elsif ($msg->type() == PAN_GATEWAY) {
        $self->{gateways}->{$mac} = $bulb;
        # This is probably not correct, it spams the whole
        # network instead of the gateway globe
        $self->tellAll(GET_LIGHT_STATE, "");
    }
    elsif ($msg->type() == TIME_STATE) {
    }
    elsif ($msg->type() == POWER_STATE) {
        $bulb->{status}->{power} = $msg->{power}
    }
    return $msg;
}

sub next_message($$)
{
    my ($self, $timeout) = @_;

    if ($self->has_message($timeout)) {
        return $self->get_message();
    }
    return undef;
}

sub get_bulb_by_mac($$)
{
    my ($self,$mac) = @_;

    if (!defined($mac)) {
        return undef;
    }

    my $bulb = undef;
    if (length($mac) == 6) {
        $bulb = $self->{bulbs}->{byMAC}->{$mac};
    } elsif (length($mac) == 17) {
        my @mac = split(':', $mac);
        $mac    = pack('C6', @mac);
        $bulb   = $self->{bulbs}->{byMAC}->{$mac};
    }
    defined($bulb) || return undef;

    return Device::LIFX::Bulb->new($self,$bulb);
}

sub get_bulb_by_label($$)
{
    my ($self,$label) = @_;

    my $bulb = $self->{bulbs}->{byLabel}->{$label};

    defined($bulb) || return undef;

    return Device::LIFX::Bulb->new($self,$bulb);
}

sub get_all_bulbs($)
{
    my ($self) = @_;

    my @bulbs;
    my $byMAC = $self->{bulbs}->{byMAC};
    foreach my $mac (keys %{$byMAC}) {
        push(@bulbs, Device::LIFX::Bulb->new($self,$byMAC->{$mac}));
    }
    return @bulbs;
}

sub find_gateways($)
{
    my ($self) = @_;
    
    $self->tellAll(GET_PAN_GATEWAY, "");
}

sub request_wifi_info($$)
{
    my ($self,$bulb) = @_;

    my $mac = $bulb->{bulb}->{mac};

    for my $gw (keys %{$self->{gateways}}) {
        my $gw_addr = $self->{gateways}->{$gw}->{addr};
        $self->tellBulb($gw_addr, $mac, GET_WIFI_INFO, "");
    }
}

sub set_color($$$$)
{
    my ($self, $bulb, $hsbk, $t) = @_;

    $t         *= 1000;
    $hsbk->[1]  = int($hsbk->[1] / 100.0 * 65535.0);
    $hsbk->[2]  = int($hsbk->[2] / 100.0 * 65535.0);
    my @payload = (0x0,$hsbk->[0],$hsbk->[1],$hsbk->[2],$hsbk->[3],$t);
    my $mac     = $bulb->{bulb}->{mac};

    for my $gw (keys %{$self->{gateways}}) {
        my $gw_addr = $self->{gateways}->{$gw}->{addr};
        my @payload = (0,@{$hsbk}, $t);
        $self->tellBulb($gw_addr, $mac, SET_LIGHT_COLOR, \@payload);
    }
}

sub set_rgb($$$$)
{
    my ($self,$bulb,$rgb,$t) = @_;

    my ($red,$green,$blue) = @{$rgb};
    my ($hue,$sat,$bri)    = (0,0,0);

    my $min   = List::Util::min($red,$green,$blue);
    my $max   = List::Util::max($red,$green,$blue);
    my $range = $max-$min;

    if ($max != 0) {
        $sat = ($max-$min)/$max;
    }
    my ($rc,$gc,$bc);
    if ($sat != 0) {
        $rc = ($max-$red)/$range;
        $gc = ($max-$green)/$range;
        $bc = ($max-$blue)/$range;
    }
    if ($red == $max) {
        $hue = 0.166667*($bc-$gc);
    } elsif ($green == $max) {
        $hue = 0.166667*(2.0+$rc-$bc);
    } else {
        $hue = 0.166667*(4.0+$gc-$rc);
    }

    if ($hue < 0.0) {
       $hue += 1.0;
    }
    $hue = int($hue * 65535);
    $sat = int($sat * 100);
    $bri = int($max/255.0*100);

    $self->set_color($bulb,[$hue,$sat,$bri,0],$t);
}

sub set_power($$$)
{
    my ($self, $bulb, $power) = @_;

    my $mac = $bulb->{bulb}->{mac};
    for my $gw (keys %{$self->{gateways}}) {
        my $gw_addr = $self->{gateways}->{$gw}->{addr};
        $self->tellBulb($gw_addr, $mac, SET_POWER_STATE, $power);
    }
}

sub socket($)
{
    my ($self) = @_;

    return $self->{socket};
}

1;

