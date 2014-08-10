package LIFX;

use strict;
use warnings;
use IO::Socket;
use IO::Select;
my $port = 56700;

my $GET_PAN_GATEWAY = 0x02;
my $PAN_GATEWAY = 0x03;
my $GET_POWER_STATE = 0x14;
my $SET_POWER_STATE = 0x15;
my $POWER_STATE = 0x16;
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
my $GET_BULB_LABEL = 0x17;
my $SET_BULB_LABEL = 0x18;
my $BULB_LABEL = 0x19;
my $GET_TAGS = 0x1A;
my $SET_TAGS = 0x1B;
my $TAGS = 0x1C;
my $GET_TAG_LABELS = 0x1D;
my $SET_TAG_LABELS = 0x1E;
my $TAG_LABELS = 0x1F;
my $GET_LIGHT_STATE = 0x65;
my $SET_LIGHT_COLOR = 0x66;
my $SET_WAVEFORM = 0x67;
my $SET_DIM_ABSOLUTE = 0x68;
my $SET_DIM_RELATIVE = 0x69;
my $LIGHT_STATUS = 0x6B;
my $GET_TIME = 0x04;
my $SET_TIME = 0x05;
my $TIME_STATE = 0x06;
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

sub new($)
{
    my ($class)     = @_;

    my $self        = {};
    $self->{bulbs}  = {};
    $self->{port}   = $port;
    $self->{socket} = IO::Socket::INET->new(
                          Proto=>'udp',
                          LocalPort=>$port
                      );

    defined($self->{socket}) || die "Could not create listen socket: $!\n";
    autoflush {$self->{socket}} 1;

    return bless $self, $class;
}

sub decode_header($)
{
    my ($header) = @_;

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

sub decode_light_status($)
{
    my ($payload) = @_;

    my @decoded = unpack('(SSSSS)<SA32Q',$payload);
    my $status = {
        "hue"        => $decoded[0],
        "saturation" => $decoded[1],
        "brightness" => $decoded[2],
        "kelvin"     => $decoded[3],
        "dim"        => $decoded[4],
        "power"      => $decoded[5],
        "label"      => $decoded[6],
        "tags"       => $decoded[7],
    };
    $status->{label} =~ s/\s+$//;

    return $status;
}

sub decode_packet($)
{
    my ($packet) = @_;

    my $decoded        = {};
    $decoded->{header} = decode_header($packet);
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
        $decoded->{status} = decode_light_status($payload);
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
    my $msg    =  decode_packet($packet);

    return $msg;
}


1;

