#!/usr/bin/perl -w


use strict;
use IO::Socket;
use strict;
use Data::Dumper;
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

my $AllBulbsResponse = 0x5400;
my $AllBulbsRequest  = 0x3400;
my $BulbCommand      = 0x1400;

my $gateways;
my $byMAC;

my $socket = IO::Socket::INET->new(Proto=>'udp', LocalPort=>$port) ||
                 die "Could not create listen socket: $!\n";

my $msg = {
    size => 0x00,
    protocol => $BulbCommand,
    reserved1 => 0x00,
    target_mac_address => 0x000000,
    reserved2 => 0x00,
    site => 'LIFXV2',
    reserved3 => 0x00,
    timestamp => 0x00,
    packet_type => 0x00,
    reserved4 => 0x00,
};

sub printPacket(@)
{
    my ($packet) = @_;

    my @packet = unpack('C*', $packet);
    foreach my $h (@packet) {
        printf("%02x ", $h);
    }
    print "\n";
}

sub packHeader($)
{
    my ($header) = @_;

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
    my $packed = pack('S<S<La6Sa6SQS<S', @header);
}

sub setPower($$)
{
    my ($mac, $onoff) = @_;

    my $payload                 = pack('S', $onoff);
    $msg->{size}                = 36+length($payload),
    $msg->{protocol}            = $BulbCommand,
    $msg->{target_mac_address}  = $mac,
    $msg->{packet_type}         = $SET_POWER_STATE;
    $msg->{reserved3}           = 0x01;
    my $header                  = packHeader($msg);
    my $packet                  = $header.$payload;

    for my $gw (keys %$gateways) {
        print inet_ntoa($gw),"\n";
        printPacket($packet);
        my $to = sockaddr_in($port, $gw);
        $socket->send($packet, 0, $to);
    }
exit(1);
}

sub setColor($$$$$$)
{
    my ($mac, $hue, $sat, $bri, $kel, $t) = @_;

    my @payload                 = (0, $hue, $sat, $bri, $kel, $t);
    my $payload                 = pack('C(SSSSL)<', @payload);
    $msg->{size}                = 36+length($payload),
    $msg->{protocol}            = $AllBulbsRequest,
    $msg->{target_mac_address}  = $mac,
$msg->{target_mac_address}  = pack('C*', (0x00,0x00,0x00,0x00,0x00,0x00));
    $msg->{packet_type}         = $SET_LIGHT_COLOR;
    $msg->{reserved3}           = 0x00;
    my $header                  = packHeader($msg);
    my $packet                  = $header.$payload;

$t = time()*1000;
$t = pack('Q<', $t);
printPacket($t);

    for my $gw (keys %$gateways) {
$gw = inet_aton("192.168.2.255");
        print inet_ntoa($gw),"\n";
        printPacket($packet);
        my $to = sockaddr_in($port, $gw);
        $socket->send($packet, 0, $to);
    }
exit(1);
}


sub MAC2Str($)
{
    my @mac = unpack('C6',$_[0]);
    @mac = map {sprintf("%02x",$_)} @mac;
    return join(':', @mac);
}

sub getHeader($)
{
    my ($header) = @_;

    my @header = unpack('SSLa6Sa6SQSS', $header);
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

sub getLightStatus($)
{
    my ($payload) = @_;

    my @payload = unpack('SSSSSSA32Q',$payload);
    my $bulb = {
        "hue"        => $payload[0],
        "saturation" => $payload[1],
        "brightness" => $payload[2],
        "kelvin"     => $payload[3],
        "dim"        => $payload[4],
        "power"      => $payload[5],
        "label"      => $payload[6],
        "tags"       => $payload[7],
    };
    $bulb->{label} =~ s/\s+$//;

    return $bulb;
}

sub decodePacket($$)
{
    my ($from,$packet) = @_;

    my ($port, $iaddr) = sockaddr_in($from);
    my $from_str = inet_ntoa($iaddr);

    my $header = getHeader($packet);
    my $type   = $header->{packet_type};
    my $mac    = $header->{target_mac_address};

    my $decoded->{header} = $header;

    if ($type == $GET_PAN_GATEWAY) {
        $decoded->{type_str} = 'GET_PAN_GATEWAY';
    }
    elsif ($type == $PAN_GATEWAY) {
        my ($service,$port) = unpack('CL<', substr($packet,36));
        $gateways->{$iaddr} = $port;
        $decoded->{type_str} = 'PAN_GATEWAY';
    }
    elsif ($type == $TIME_STATE) {
        $byMAC->{$mac}->{time} = unpack('Q', substr($packet,36,8));
        $decoded->{type_str} = 'TIME_STATE';
    }
    elsif ($type == $POWER_STATE) {
        my $onoff = unpack('S', substr($packet,36,2));
        $byMAC->{$mac}->{power} = $onoff;
        $decoded->{type_str} = 'POWER_STATE';
    }
    elsif ($type == $SET_POWER_STATE) {
        $decoded->{type_str} = 'POWER_STATE';
    }
    elsif ($type == $TAG_LABELS) {
        my ($tags, $label) = unpack('Qa*', substr($packet,36));
        $decoded->{type_str} = 'TAG_LABELS';
    }
    elsif ($type == $LIGHT_STATUS) {
        my $status = getLightStatus(substr($packet,36));
        my $header = getHeader($packet);

        $byMAC->{$mac}->{saturation} = $status->{saturation};
        $byMAC->{$mac}->{hue}        = $status->{hue};
        $byMAC->{$mac}->{brightness} = $status->{brightness};
        $byMAC->{$mac}->{kelvin}     = $status->{kelvin};
        $byMAC->{$mac}->{power}      = $status->{power};
        $byMAC->{$mac}->{dim}        = $status->{dim};
        $byMAC->{$mac}->{tags}       = $status->{tags};
        $byMAC->{$mac}->{label}      = $status->{label};

        $decoded->{type_str} = 'LIGHT_STATUS';
        $decoded->{status}   = $status;
    }
    else {
        printf("Unknown(%x)\n", $type);
        exit(1);
    }
    return $decoded;
}


my $select = IO::Select->new($socket);

print "Listening\n";
while(1) {
    my @ready = $select->can_read(0);
    foreach my $fh (@ready) {
        my $packet;
        my $from = recv($fh, $packet,1024,0);
        my $decoded = decodePacket($from,$packet);
        if ($decoded->{type_str} eq "LIGHT_STATUS") {
            my $mac = $decoded->{header}->{target_mac_address};
            my $label  = $byMAC->{$mac}->{label};
            # setColor($mac, 0, 0, 10, 2700, 1000);
            setPower($mac, 0);
        }
    }
}

exit(0);

=begin

set light color

31 00
00 34
00 00 00 00
00 00 00 00 00 00
00 00
4c 49 46 58 56 32
00 00
00 03 1d 97 71 e8 86 13
66 00
00
00 00
e3 18
b7 5e
65 a6
ac 0d
e8 03 00 00




31 00 00 34 00 00 00 00 00 00 00 00 00 00 00 00 4c 49 46 58 56 32 00 00 00 03 1d 97 71 e8 86 13 66 00 00 00 00 e3 18 b7 5e 65 a6 ac 0d e8 03 00 00


=cut
