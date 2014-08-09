#!/usr/bin/perl -w


use strict;
use IO::Socket;
use strict;
use Data::Dumper;
use IO::Select;

my $port = 56700;

my $GET_PAN_GATEWAY = 0X02;
my $PAN_GATEWAY = 0X03;
my $GET_POWER_STATE = 0X14;
my $SET_POWER_STATE = 0X15;
my $POWER_STATE = 0X16;
my $GET_WIFI_INFO = 0X10;
my $WIFI_INFO = 0X11;
my $GET_WIFI_FIRMWARE_STATE = 0X12;
my $WIFI_FIRMWARE_STATE = 0X13;
my $GET_WIFI_STATE = 0X12D;
my $SET_WIFI_STATE = 0X12E;
my $WIFI_STATE = 0X12F;
my $GET_ACCESS_POINTS = 0X130;
my $SET_ACCESS_POINT = 0X131;
my $ACCESS_POINT = 0X132;
my $GET_BULB_LABEL = 0X17;
my $SET_BULB_LABEL = 0X18;
my $BULB_LABEL = 0X19;
my $GET_TAGS = 0X1A;
my $SET_TAGS = 0X1B;
my $TAGS = 0X1C;
my $GET_TAG_LABELS = 0X1D;
my $SET_TAG_LABELS = 0X1E;
my $TAG_LABELS = 0X1F;
my $GET_LIGHT_STATE = 0X65;
my $SET_LIGHT_COLOR = 0X66;
my $SET_WAVEFORM = 0X67;
my $SET_DIM_ABSOLUTE = 0X68;
my $SET_DIM_RELATIVE = 0X69;
my $LIGHT_STATUS = 0X6B;
my $GET_TIME = 0X04;
my $SET_TIME = 0X05;
my $TIME_STATE = 0X06;
my $GET_RESET_SWITCH = 0X07;
my $RESET_SWITCH_STATE = 0X08;
my $GET_DUMMY_LOAD = 0X09;
my $SET_DUMMY_LOAD = 0X0A;
my $DUMMY_LOAD = 0X0B;
my $GET_MESH_INFO = 0X0C;
my $MESH_INFO = 0X0D;
my $GET_MESH_FIRMWARE = 0X0E;
my $MESH_FIRMWARE_STATE = 0X0F;
my $GET_VERSION = 0X20;
my $VERSION_STATE = 0X21;
my $GET_INFO = 0X22;
my $INFO = 0X23;
my $GET_MCU_RAIL_VOLTAGE = 0X24;
my $MCU_RAIL_VOLTAGE = 0X25;
my $REBOOT = 0X26;
my $SET_FACTORY_TEST_MODE = 0X27;
my $DISABLE_FACTORY_TEST_MODE = 0X28;

# $Data::Dumper::Indent = 0;

=begin
header
{
0 0,1  uint16 size;              // LE
1 2,3  uint16 protocol;
2 4,7  uint32 reserved1;         // Always 0x0000
3 8,13  byte   target_mac_address[6];
4 14,15  uint16 reserved2;         // Always 0x00
5 16,21  byte   site[6];           // MAC address of gateway PAN controller bulb
6 22,23  uint16 reserved3;         // Always 0x00
7 24,31  uint64 timestamp;
8 32,33  uint16 packet_type;       // LE
9 34,35  uint16 reserved4;         // Always 0x0000
}

=cut

my $socket = IO::Socket::INET->new(Proto=>'udp', LocalPort=>$port) ||
                 die "Could not create listen socket: $!\n";

my $msg = {
    size => 0x00,
    protocol => 0x1400,
    reserved1 => 0x00,
    target_mac_address => 0x000000,
    reserved2 => 0x00,
    site => 'LIFXV2',
    reserved3 => 0x01,
    timestamp => 0x00,
    packet_type => 0x00,
    reserved4 => 0x00,
};


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
    my $packed = pack('SSLa6Sa6SQvS', @header);
}

# 26 00
# 00 54
# 00 00 00 00
# d0 73 d5 01 0f e0
# 00 00
# 4c 49 46 58 56 32
# 00 00
# 00 00 00 00 00 00 00 00
# 15 00
# 00 00
# 00 00

sub tellBulb($$$$)
{
    my ($mac, $gateway, $type, $payload) = @_;

    $msg->{size} = 36+length($payload),
    $msg->{target_mac_address}  = $mac,
    $msg->{packet_type} = $type;

    my $header = packHeader($msg);
    my $packet = $header.$payload;

my @packet = unpack('C*', $packet);
print "\nTELL: ";
printPacket(@packet);
$socket->send($packet, 0, $gateway);
}


my %byLabel;
my %byMAC;

sub setBulbPower($$)
{
    my ($bulb,$on);
    my $header;

    $header->{packet_type} = 0x15;
    my $onoff  = pack('S',$on);

    send($socket,0,1);
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

    my @header = unpack('SSLa6Sa6SQSS', $packet);

    my $header = getHeader($packet);
    my $type   = $header->{packet_type};
    my $mac    = $header->{target_mac_address};

    my $decoded->{header} = $header;

    print "$from_str ".MAC2Str($mac)." ";

    if ($type == 0x02) {
        print "Get PAN gateway\n";
    }
    elsif ($type == 0x03) {
        print "PAN gateway\n";
        my ($service,$port) = unpack('aL', substr($packet,36));
        print "$service $port\n";
    }
    elsif ($type == 0x06) {
        print "Bulb Time\n";
        my $time = unpack('Q', substr($packet,36,8));
        print "$time\n";
    }
    elsif ($type == 0x16) {
        print "Power State\n";
        my $onoff = unpack('S', substr($packet,36,2));
        if ($onoff == 0x0000) {
            print "OFF\n";
        } elsif ($onoff == 0xffff) {
            print "ON\n";
        }
        else {
            print "?\n";
        }
    }
    elsif ($type == 0x1f) {
        print "Tag Labels\n";
        my ($tags, $label) = unpack('Qa*', substr($packet,36));
    }
    elsif ($type == 0x6b) {
        my $status = getLightStatus(substr($packet,36));
        my $header = getHeader($packet);
        my $label  = $status->{label};
        $byMAC{$mac} = $header;
        $byLabel{$label} = $header;

        if ($label eq 'Study') {
            my $payload = pack('S', 0);
            tellBulb($mac, $from, $SET_POWER_STATE, $payload);
            $payload = pack('S', 0xFFFF);
            sleep(3);
            tellBulb($mac, $from, $SET_POWER_STATE, $payload);
exit(0);
        }

        print "Light Status ".$label."\n";;
    }
    else {
        printf("Unknown(%x)\n", $header[8]);
    }
    return $decoded;
}

sub printPacket(@)
{
    my @packet = @_;

    foreach my $h (@packet) {
        printf("%02x ", $h);
    }
    print "\n";
}



my $select = IO::Select->new($socket);

print "Listening\n";
my $subscribed = 0;
my $packet;
while(1) {
    my @ready = $select->can_read(0);
    foreach my $fh (@ready) {
        my $from = recv($fh, $packet,1024,0);

        my @data = unpack("C*", $packet);
        printPacket(@data);
        my $decoded = decodePacket($from,$packet);
    }
}

exit(0);

=begin


[root@homectl ~]# tcpdump -vv -X -i eth0 port 56700

tcpdump: listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
20:38:56.394501 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto UDP (17), length 66)


    192.168.2.26.49820 > 192.168.2.11.56700: [udp sum ok] UDP, length 38

        0x0000:  45 00 00 42 00 00 40 00 40 11 b5 35 c0 a8 02 1a
        0x0010:  c0 a8 02 0b c2 9c dd 7c 00 2e ff c4|26 00 00 14
        0x0020:  00 00 00 00 d0 73 d5 01 0f e0 00 00 4c 49 46 58  .....s......LIFX
        0x0030:  56 32 01 00 00 00 00 00 00 00 00 00 15 00 00 00  V2..............
        0x0040:  00 00                                     ..


26 00
00 14
00 00 00 00
d0 73 d5 01 0f e0
00 00
4c 49 46 58 56 32
01 00
00 00 00 00 00 00 00 00
15 00
00 00
00 00







20:38:56.437201 IP (tos 0x0, ttl 255, id 35543, offset 0, flags [DF], proto UDP (17), length 66)
    192.168.2.11.56700 > 192.168.2.255.56700: [udp sum ok] UDP, length 38
        0x0000:  4500 0042 8ad7 4000 ff11 6a78 c0a8 020b  E..B..@...jx....
        0x0010:  c0a8 02ff dd7c dd7c 002e e3bf | 2600 0054  .....|.|....&..T
        0x0020:  0000 0000 d073 d501 0fe0 0000 4c49 4658  .....s......LIFX
        0x0030:  5632 0000 0000 0000 0000 0000 1600 0000  V2..............
        0x0040:  ffff                                     ..

20:38:56.950795 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto UDP (17), length 66)
    192.168.2.26.49820 > 192.168.2.11.56700: [udp sum ok] UDP, length 38
        0x0000:  4500 0042 0000 4000 4011 b535 c0a8 021a  E..B..@.@..5....
        0x0010:  c0a8 020b c29c dd7c 002e ffc4  |2600 0014  .......|....&...
        0x0020:  0000 0000 d073 d501 0fe0 0000 4c49 4658  .....s......LIFX
        0x0030:  5632 0100 0000 0000 0000 0000 1500 0000  V2..............
        0x0040:  0000                                     ..

20:38:56.987200 IP (tos 0x0, ttl 255, id 35544, offset 0, flags [DF], proto UDP (17), length 66)
    192.168.2.11.56700 > 192.168.2.255.56700: [udp sum ok] UDP, length 38
        0x0000:  4500 0042 8ad8 4000 ff11 6a77 c0a8 020b  E..B..@...jw....
        0x0010:  c0a8 02ff dd7c dd7c 002e e3bf  |2600 0054  .....|.|....&..T
        0x0020:  0000 0000 d073 d501 0fe0 0000 4c49 4658  .....s......LIFX
        0x0030:  5632 0000 0000 0000 0000 0000 1600 0000  V2..............
        0x0040:  0000                                     ..

20:38:57.941879 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto UDP (17), length 66)
    192.168.2.26.49820 > 192.168.2.11.56700: [udp sum ok] UDP, length 38
        0x0000:  4500 0042 0000 4000 4011 b535 c0a8 021a  E..B..@.@..5....
        0x0010:  c0a8 020b c29c dd7c 002e fec4  |2600 0014  .......|....&...
        0x0020:  0000 0000 d073 d501 0fe0 0000 4c49 4658  .....s......LIFX
        0x0030:  5632 0100 0000 0000 0000 0000 1500 0000  V2..............
        0x0040:  0100                                     ..

20:38:57.987217 IP (tos 0x0, ttl 255, id 35545, offset 0, flags [DF], proto UDP (17), length 66)
    192.168.2.11.56700 > 192.168.2.255.56700: [udp sum ok] UDP, length 38
        0x0000:  4500 0042 8ad9 4000 ff11 6a76 c0a8 020b  E..B..@...jv....
        0x0010:  c0a8 02ff dd7c dd7c 002e e3bf  |2600 0054  .....|.|....&..T
        0x0020:  0000 0000 d073 d501 0fe0 0000 4c49 4658  .....s......LIFX
        0x0030:  5632 0000 0000 0000 0000 0000 1600 0000  V2..............
        0x0040:  0000                                     ..

20:38:58.497540 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto UDP (17), length 66)
    192.168.2.26.49820 > 192.168.2.11.56700: [udp sum ok] UDP, length 38
        0x0000:  4500 0042 0000 4000 4011 b535 c0a8 021a  E..B..@.@..5....
        0x0010:  c0a8 020b c29c dd7c 002e fec4  |


26 00
00 14
00 00 00 00
d0 73 d5 01 0f e0
00 00
4c 49 46 58 56 32
01 00
00 00 00 00 00 00 00 00
15 00
00 00
01 00

20:38:58.537179 IP (tos 0x0, ttl 255, id 35546, offset 0, flags [DF], proto UDP (17), length 66)
    192.168.2.11.56700 > 192.168.2.255.56700: [udp sum ok] UDP, length 38


26 00
00 54
00 00 00 00
d0 73 d5 01 0f e0
00 00
4c 49 46 58 56 32
00 00
00 00 00 00 00 00 00 00
16 00
00 00
ff ff

20:39:03.184943 IP (tos 0x0, ttl 64, id 0, offset 0, flags [DF], proto UDP (17), length 64)
    192.168.2.26.36608 > 255.255.255.255.56700: [udp sum ok] UDP, length 36

2400 0034
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0200 0000

20:39:03.239477 IP (tos 0x0, ttl 255, id 35547, offset 0, flags [DF], proto UDP (17), length 69)
    192.168.2.11.56700 > 192.168.2.255.56700: [udp sum ok] UDP, length 41

29 00
00 54
00 00 00 00
d0 73 d5 01 96 13
00 00
4c 49 46 58 56 32
00 00
00 00 00 00 00 00 00 00
03 00
00 00
02 00 00 00 00



20:39:03.242145 IP (tos 0x0, ttl 255, id 35548, offset 0, flags [DF], proto UDP (17), length 69)
    192.168.2.11.56700 > 192.168.2.255.56700: [udp sum ok] UDP, length 41

29 00
00 54
00 00 00 00
d0 73 d5 01 96 13
00 00
4c 49 46 58 56 32
00 00 00 00 00 00 00 00 00 00 03 00 00 00
01 7c dd 00 00 











=cut
