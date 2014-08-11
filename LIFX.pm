package LIFX;

use strict;
use warnings;
use IO::Socket;
use IO::Select;
use Data::Dumper;

use LIFX::Constants qw(/.*/);

require 'LIFX/Bulb.pm';

my $port = 56700;

my %msg_template = (
    size        => 0x00, protocol           => 0x00,
    reserved1   => 0x00, target_mac_address => "\0\0\0\0\0\0",
    reserved2   => 0x00, site               => "LIFXV2",
    reserved3   => 0x00, timestamp          => 0x00,
    packet_type => 0x00, reserved4          => 0x00,
);

sub printPacket(@)
{
    my @packet = @_;

    if ($#packet == 0) {
        @packet = unpack('C*', $packet[0]);
    }

    foreach my $h (@packet) {
        printf("%02x ", $h);
    }
    print "\n";
}

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

sub packet_type_str($$)
{
    my ($self,$type) = @_;

    return LIFX::Constants::type2str($type);
}

sub find_gateways($)
{
    my ($self) = @_;
    
    $self->tellAll(GET_PAN_GATEWAY, "");
}

sub packMessage($$$)
{
    my ($self, $header, $payload) = @_;

    $header->{size} = 36+length($payload),
    my @header = (
        $header->{size},
        $header->{protocol},
        $header->{reserved1},
        $header->{target_mac_address},
        $header->{reserved2},
        $header->{site},
        $header->{reserved3},
        $header->{timestamp},
        $header->{packet_type},
        $header->{reserved4},
    );
    my $packed = pack('(SS)<La6Sa6SQvS', @header);

    return $packed.$payload;
}

sub tellBulb($$$$$)
{
    my ($self, $gw, $mac, $type, $payload) = @_;

    my %msg                  = %msg_template;
    $msg{protocol}           = BULB_COMMAND;
    $msg{target_mac_address} = $mac;
    $msg{packet_type}        = $type;
    my $packet               = $self->packMessage(\%msg,$payload);

    $self->{socket}->send($packet, 0, $gw) || die "Uggh: $!";
}

sub tellAll($$$)
{
    my ($self, $type, $payload) = @_;

    my %msg                  = %msg_template;
    $msg{protocol}           = ALL_BULBS_REQUEST;
    $msg{packet_type}        = $type;
    my $packet               = $self->packMessage(\%msg,$payload);
    my $to                   = sockaddr_in($self->{port}, INADDR_BROADCAST);

    $self->{socket}->send($packet, 0, $to) || die "Uggh: $!";
}

sub decode_header($$)
{
    my ($self,$header) = @_;

    my @header = unpack('(SS)<La6Sa6SQSS', $header);
    $header = {
        size               => $header[0],
        protocol           => $header[1],
        reserved1          => $header[2],
        target_mac_address => $header[3],
        reserved2          => $header[4],
        site               => $header[5],
        reserved3          => $header[6],
        timestamp          => $header[7],
        packet_type        => $header[8],
        reserved4          => $header[9],
    };
    return $header;
}

sub decode_light_status($$)
{
    my ($self,$payload) = @_;

    my @decoded = unpack('(SSSSS)<SA32Q',$payload);
    my $status = {
        "hue"        => $decoded[0],
        "saturation" => $decoded[1]/65535.0*100.0,
        "brightness" => $decoded[2]/65535.0*100.0,
        "kelvin"     => $decoded[3],
        "dim"        => $decoded[4],
        "power"      => ($decoded[5] == 0xFFFF),
        "label"      => $decoded[6],
        "tags"       => $decoded[7],
    };
    $status->{label} =~ s/\s+$//;

    return $status;
}

sub decode_packet($$)
{
    my ($self,$packet) = @_;

    my $decoded        = {};
    $decoded->{header} = $self->decode_header($packet);
    my $type           = $decoded->{header}->{packet_type};
    my $payload        = substr($packet, 36);

    if ($type == GET_PAN_GATEWAY) {
        $decoded->{packet_type} = GET_PAN_GATEWAY;
    }
    elsif ($type == PAN_GATEWAY) {
        my ($service,$port) = unpack('aL', $payload);
        $decoded->{packet_type} = PAN_GATEWAY;
        $decoded->{service} = $service;
        $decoded->{port}    = $port;
    }
    elsif ($type == TIME_STATE) {
        $decoded->{packet_type} = TIME_STATE;
        $decoded->{time} = unpack('Q', $payload);
    }
    elsif ($type == POWER_STATE) {
        $decoded->{packet_type} = POWER_STATE;
        $decoded->{power} = unpack('S', $payload);
    }
    elsif ($type == TAG_LABELS) {
        $decoded->{packet_type}   = TAG_LABELS;
        my ($tags, $label) = unpack('Qa*', $payload);
        $decoded->{tags}   = $tags;
        $decoded->{label}  = $label;
print "$tags $label\n";
    }
    elsif ($type == LIGHT_STATUS) {
        $decoded->{packet_type}   = LIGHT_STATUS;
        $decoded->{status} = $self->decode_light_status($payload);
    }
    elsif ($type == GET_LIGHT_STATE) {
    }
    elsif ($type == MESH_FIRMWARE_STATE) {
    }
    else {
        printf("Unknown(%x)\n", $type);
    }
    return $decoded;
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
    my $msg  = $self->decode_packet($packet);
    my $mac  = $msg->{header}->{target_mac_address};
    my $bulb = $self->{bulbs}->{byMAC}->{$mac} || {};
    my $type = $msg->{header}->{packet_type};

    $bulb->{addr} = $from;
    if ($type == LIGHT_STATUS) {
        my $label = $msg->{status}->{label};
        $bulb->{status}                     = $msg->{status};
        $bulb->{mac}                        = $mac;
        $self->{bulbs}->{byMAC}->{$mac}     = $bulb;
        $self->{bulbs}->{byLabel}->{$label} = $bulb;
    }
    elsif ($type == PAN_GATEWAY) {
        $self->{gateways}->{$mac} = $bulb;
        # This is probably not correct, it spams the whole
        # network instead of the gateway globe
        $self->tellAll(GET_LIGHT_STATE, "");
    }
    elsif ($type == GET_PAN_GATEWAY) {
    }
    elsif ($type == TIME_STATE) {
    }
    elsif ($type == GET_LIGHT_STATE) {
    }
    elsif ($type == POWER_STATE) {
        $bulb->{status}->{power} = $msg->{power}
    }
    elsif ($type == TAG_LABELS) {
    }
    elsif ($type == MESH_FIRMWARE_STATE) {
    }
    else {
        die $type;
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

    my $bulb = undef;
    if (length($mac) == 6) {
        $bulb = $self->{bulbs}->{byMAC}->{$mac};
    } elsif (length($mac) == 17) {
        my @mac = split(':', $mac);
        $mac    = pack('C6', @mac);
        $bulb   = $self->{bulbs}->{byMAC}->{$mac};
    }
    defined($bulb) || return undef;

    return LIFX::Bulb->new($self,$bulb);
}

sub get_bulb_by_label($$)
{
    my ($self,$label) = @_;

    my $bulb = $self->{bulbs}->{byLabel}->{$label};

    defined($bulb) || return undef;

    return LIFX::Bulb->new($self,$bulb);
}

sub get_all_bulbs($)
{
    my ($self) = @_;

    my @bulbs;
    my $byMAC = $self->{bulbs}->{byMAC};
    foreach my $mac (keys %{$byMAC}) {
        push(@bulbs, LIFX::Bulb->new($self,$byMAC->{$mac}));
    }
    return @bulbs;
}

sub get_colour($$$$)
{
    my ($self, $bulb) = @_;

    my @hsbk;
    $hsbk[0] = $bulb->{bulb}->{status}->{hue};
    $hsbk[1] = $bulb->{bulb}->{status}->{saturation};
    $hsbk[2] = $bulb->{bulb}->{status}->{brighntess};
    $hsbk[3] = $bulb->{bulb}->{status}->{kelvin};

    return @hsbk;
}

sub set_colour($$$$)
{
    my ($self, $bulb, $hsbk, $t) = @_;

    $t         *= 1000;
    $hsbk->[1]  = int($hsbk->[1] / 100.0 * 65535.0);
    $hsbk->[2]  = int($hsbk->[2] / 100.0 * 65535.0);
    my @payload = (0x0,$hsbk->[0],$hsbk->[1],$hsbk->[2],$hsbk->[3],$t);

    my $mac     = $bulb->{bulb}->{mac};
    my $payload = pack('C(SSSSL)<', @payload);
    for my $gw (keys %{$self->{gateways}}) {
        my $gw_addr = $self->{gateways}->{$gw}->{addr};
        $self->tellBulb($gw_addr, $mac, SET_LIGHT_COLOR, $payload);
    }
}

sub get_power($$)
{
    my ($self, $bulb) = @_;

    return $bulb->{bulb}->{status}->{power};
}

sub set_power($$$)
{
    my ($self, $bulb, $power) = @_;

    my $mac     = $bulb->{bulb}->{mac};
    my $payload = pack('S<', $power);
    for my $gw (keys %{$self->{gateways}}) {
        my $gw_addr = $self->{gateways}->{$gw}->{addr};
        $self->tellBulb($gw_addr, $mac, SET_POWER_STATE, $payload);
    }
}

1;

