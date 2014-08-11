package LIFX;

use strict;
use warnings;
use IO::Socket;
use IO::Select;
use Data::Dumper;

require 'LIFX/Bulb.pm';

my $port = 56700;

# Mesh network 
my $GET_PAN_GATEWAY = 0x02;
my $PAN_GATEWAY = 0x03;

# On/Off
my $GET_POWER_STATE = 0x14;
my $SET_POWER_STATE = 0x15;
my $POWER_STATE = 0x16;

# WiFi handling
my $GET_WIFI_INFO = 0x10;
my $WIFI_INFO = 0x11;
my $GET_WIFI_FIRMWARE_STATE = 0x12;
my $WIFI_FIRMWARE_STATE = 0x13;
my $GET_WIFI_STATE = 0x12D;
my $SET_WIFI_STATE = 0x12E;
my $WIFI_STATE = 0x12F;
my $GET_ACCESS_POINTS = 0x130;
my $SET_ACCESS_POINT = 0x131;
my $ACCESS_POINT = 0x132;

# Labels and Tags
my $GET_BULB_LABEL = 0x17;
my $SET_BULB_LABEL = 0x18;
my $BULB_LABEL = 0x19;
my $GET_TAGS = 0x1A;
my $SET_TAGS = 0x1B;
my $TAGS = 0x1C;
my $GET_TAG_LABELS = 0x1D;
my $SET_TAG_LABELS = 0x1E;
my $TAG_LABELS = 0x1F;

# Colour, Brightness etc
my $GET_LIGHT_STATE = 0x65;
my $SET_LIGHT_COLOR = 0x66;
my $SET_WAVEFORM = 0x67;
my $SET_DIM_ABSOLUTE = 0x68;
my $SET_DIM_RELATIVE = 0x69;
my $LIGHT_STATUS = 0x6B;

# Time
my $GET_TIME = 0x04;
my $SET_TIME = 0x05;
my $TIME_STATE = 0x06;

# Debugging and Management
my $GET_RESET_SWITCH = 0x07;
my $RESET_SWITCH_STATE = 0x08;
my $GET_DUMMY_LOAD = 0x09;
my $SET_DUMMY_LOAD = 0x0A;
my $DUMMY_LOAD = 0x0B;
my $GET_MESH_INFO = 0x0C;
my $MESH_INFO = 0x0D;
my $GET_MESH_FIRMWARE = 0x0E;
my $MESH_FIRMWARE_STATE = 0x0F;
my $GET_VERSION = 0x20;
my $VERSION_STATE = 0x21;
my $GET_INFO = 0x22;
my $INFO = 0x23;
my $GET_MCU_RAIL_VOLTAGE = 0x24;
my $MCU_RAIL_VOLTAGE = 0x25;
my $REBOOT = 0x26;
my $SET_FACTORY_TEST_MODE = 0x27;
my $DISABLE_FACTORY_TEST_MODE = 0x28;

my $AllBulbsResponse = 0x5400;
my $AllBulbsRequest  = 0x3400;
my $BulbCommand      = 0x1400;

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

    $obj->tellAll($GET_PAN_GATEWAY, "");

    return $obj;
}

sub packHeader($$)
{
    my ($self, $header) = @_;

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
}

sub tellBulb($$$$$)
{
    my ($self, $gw, $mac, $type, $payload) = @_;

    my $msg = {
        size        => 0x00, protocol           => $BulbCommand,
        reserved1   => 0x00, target_mac_address => $mac,
        reserved2   => 0x00, site               => "LIFXV2",
        reserved3   => 0x00, timestamp          => 0x00,
        packet_type => 0x00, reserved4          => 0x00,
    };

    $msg->{size}        = 36+length($payload),
    $msg->{packet_type} = $type;
    my $header          = $self->packHeader($msg);
    my $packet          = $header.$payload;

    $self->{socket}->send($packet, 0, $gw) || die "Uggh: $!";
}

sub tellAll($$$)
{
    my ($self, $type, $payload) = @_;

    my $msg = {
        size        => 0x00, protocol           => $AllBulbsRequest,
        reserved1   => 0x00, target_mac_address => 0x000000,
        reserved2   => 0x00, site               => "\0\0\0\0\0\0",
        reserved3   => 0x00, timestamp          => 0x00,
        packet_type => 0x00, reserved4          => 0x00,
    };

    my $bcast                  = inet_aton("255.255.255.255");
    my $to                     = sockaddr_in($self->{port}, $bcast);
    $msg->{size}               = 36+length($payload),
    $msg->{target_mac_address} = pack('C6', (0,0,0,0,0,0));
    $msg->{packet_type}        = $type;
    my $header                 = $self->packHeader($msg);
    my $packet                 = $header.$payload;

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

    if ($type == $GET_PAN_GATEWAY) {
        $decoded->{packet_type} = $GET_PAN_GATEWAY;
    }
    elsif ($type == $PAN_GATEWAY) {
        my ($service,$port) = unpack('aL', $payload);
        $decoded->{packet_type}    = $PAN_GATEWAY;
        $decoded->{service} = $service;
        $decoded->{port}    = $port;
    }
    elsif ($type == $TIME_STATE) {
        $decoded->{packet_type} = $TIME_STATE;
        $decoded->{time} = unpack('Q', $payload);
    }
    elsif ($type == $POWER_STATE) {
        $decoded->{packet_type}  = $POWER_STATE;
        $decoded->{power} = unpack('S', $payload);
    }
    elsif ($type == $TAG_LABELS) {
        $decoded->{packet_type}   = $TAG_LABELS;
        my ($tags, $label) = unpack('Qa*', $payload);
        $decoded->{tags}   = $tags;
        $decoded->{label}  = $label;
    }
    elsif ($type == $LIGHT_STATUS) {
        $decoded->{packet_type}   = $LIGHT_STATUS;
        $decoded->{status} = $self->decode_light_status($payload);
    }
    else {
        printf("Unknown(%x)\n", $type);
    }
    return $decoded;
}

sub next_message($)
{
    my ($self) = @_;

    my $message;
    my $packet;

    my $select = IO::Select->new($self->{socket});
    my @ready  = $select->can_read();
    my $from   = recv($ready[0], $packet, 1024, 0);
    my $msg    = $self->decode_packet($packet);

    my $mac  = $msg->{header}->{target_mac_address};
    my $bulb = $self->{bulbs}->{byMAC}->{$mac} || {};
    my $type = $msg->{packet_type};

    $bulb->{addr} = $from;
    if ($type == $LIGHT_STATUS) {
        my $label = $msg->{status}->{label};
        $bulb->{status}                     = $msg->{status};
        $bulb->{mac}                        = $mac;
        $self->{bulbs}->{byMAC}->{$mac}     = $bulb;
        $self->{bulbs}->{byLabel}->{$label} = $bulb;
    }
    elsif ($type == $PAN_GATEWAY) {
        $self->{gateways}->{$mac} = $bulb;
    }
    elsif ($type == $GET_PAN_GATEWAY) {
    }
    elsif ($type == $TIME_STATE) {
    }
    elsif ($type == $POWER_STATE) {
        $bulb->{status}->{power} = $msg->{power}
    }
    elsif ($type == $TAG_LABELS) {
    }
    else {
        die $type;
    }
    return $msg;
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

    $hsbk->[1]  = int($hsbk->[1] / 100.0 * 65535.0);
    $hsbk->[2]  = int($hsbk->[2] / 100.0 * 65535.0);
    my @payload = (0x0,$hsbk->[0],$hsbk->[1],$hsbk->[2],$hsbk->[3],$t);

    my $mac     = $bulb->{bulb}->{mac};
    my $payload = pack('C(SSSSL)<', @payload);
    for my $gw (keys %{$self->{gateways}}) {
        my $gw_addr = $self->{gateways}->{$gw}->{addr};
        $self->tellBulb($gw_addr, $mac, $SET_LIGHT_COLOR, $payload);
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
        $self->tellBulb($gw_addr, $mac, $SET_POWER_STATE, $payload);
    }
}

1;

