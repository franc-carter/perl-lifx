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
use bigint;
use Carp qw(confess);

my $port = 56700;

sub new($)
{
    my ($class) = @_;

    my $self            = {};
    $self->{bulbs}      = {};
    $self->{gateways}   = {};
    $self->{tag_labels} = {};
    $self->{port}       = $port;
    $self->{socket}     = IO::Socket::INET->new(
                              Proto => 'udp',
                              LocalPort => $port,
                              Broadcast => 1,
                          );

    defined($self->{socket}) || confess "Could not create listen socket: $!\n";
    autoflush {$self->{socket}} 1;

    my $obj = bless $self, $class;

    $obj->find_gateways();

    return $obj;
}

sub socket($)
{
    my ($self) = @_;

    return $self->{socket};
}

sub wait_for_quiet($$)
{
    my ($self,$seconds) = @_;

    while(defined($self->next_message($seconds))) {
        # Do Nothing, but status will be updated
    }
}


sub tellBulb($$$$)
{
    my ($self, $bulb, $type, $payload) = @_;

    my $msg = Device::LIFX::Message->new(
                  $type,
                  BULB_COMMAND,
                  $bulb->mac(),
                  $payload,
              );
    for my $gw (keys %{$self->{gateways}}) {
        my $gw_addr  = $self->{gateways}->{$gw}->{addr};
        $self->{socket}->send($msg->{packet}, 0, $gw_addr) || confess "Uggh: $!";
    }

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

    $self->{socket}->send($msg->{packet}, 0, $to) || confess "Uggh: $!";
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
    my $bulb = $self->get_bulb_by_mac($mac) || Device::LIFX::Bulb->new($self,$mac);

    $bulb->_set_last_seen(time());
    if ($msg->type() == LIGHT_STATUS) {
        my $label = $msg->label();
        $bulb->_set_color($msg->color());
        $bulb->_set_power($msg->power());
        $bulb->_set_label($label);
        $self->{bulbs}->{byMAC}->{$mac}     = $bulb;
        $self->{bulbs}->{byLabel}->{$label} = $bulb;
    }
    elsif ($msg->type() == PAN_GATEWAY) {
        $self->{gateways}->{$mac} = $bulb;
        # This is probably not correct, it spams the whole
        # network instead of the gateway globe
        $self->tellAll(GET_LIGHT_STATE, "");
        $self->tellAll(GET_TAGS, "");
    }
    elsif ($msg->type() == TIME_STATE) {
    }
    elsif ($msg->type() == TAG_LABELS) {
        $self->{tag_labels}->{$msg->tags()} = $msg->tag_label();
    }
    elsif ($msg->type() == TAGS) {
        $bulb->_set_tags($msg->tags());
        $self->tellAll(GET_TAG_LABELS, $msg->tags());
    }
    elsif ($msg->type() == POWER_STATE) {
        $bulb->_set_power($msg->power());
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
    return $bulb;
}

sub get_bulb_by_label($$)
{
    my ($self,$label) = @_;

    return $self->{bulbs}->{byLabel}->{$label};
}

sub get_all_bulbs($)
{
    my ($self) = @_;

    my @bulbs;
    my $byMAC = $self->{bulbs}->{byMAC};
    foreach my $mac (keys %{$byMAC}) {
        push(@bulbs, $byMAC->{$mac});
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

    $self->tellBulb($bulb, GET_WIFI_INFO, "");
}

sub request_tags($$)
{
    my ($self,$bulb) = @_;

    $self->tellBulb($bulb, GET_TAGS, "");
    $self->tellBulb($bulb, GET_TAG_LABELS, "");
}

sub set_color($$$$)
{
    my ($self, $bulb, $hsbk, $t) = @_;

    $t         *= 1000;
    $hsbk->[1]  = int($hsbk->[1] / 100.0 * 65535.0);
    $hsbk->[2]  = int($hsbk->[2] / 100.0 * 65535.0);
    my @payload = (0x0,$hsbk->[0],$hsbk->[1],$hsbk->[2],$hsbk->[3],$t);

    $self->tellBulb($bulb, SET_LIGHT_COLOR, \@payload);
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

    $self->tellBulb($bulb, SET_POWER_STATE, $power);
}

sub _tag_label($$)
{
    my ($self,$tag) = @_;

    my $tag_label = $self->{tag_labels}->{$tag} || "UKNOWN_TAG";

    return $tag_label;
}

sub _tag_ids($)
{
    return keys(%{$_[0]->{tag_labels}});
}

sub _find_tag_id($$)
{
    my ($self,$tag_label) = @_;

    my $tag_id        = undef;
    my @existing_tags = keys(%{$self->{tag_labels}});
    for my $t (@existing_tags) {
        if ($self->{tag_labels}->{$t} eq $tag_label) {
            $tag_id = $t;
            last;
        }
    }
    return $tag_id;
}

sub _next_tag_id($)
{
    my ($self) = @_;

    my $new_tag = undef;
    my @existing_tags = keys(%{$self->{tag_labels}});
    my $existing_tags = List::Util::sum(0,@existing_tags);
    my $bits          = 1;
    for(my $n=1; $n<64; $n++) {
        if (!($existing_tags & $bits)) {
            $new_tag = 1 << $n-1;
            last;
        }
        $bits = $bits << 1;
    }
    return $new_tag;
}

sub get_bulbs_by_tag()
{
    my ($self,$tag_label) = @_;

    my @bulbs;
    my $tag = $self->_find_tag_id($tag_label);
    foreach my $b ($self->get_all_bulbs()) {
        my @tags = $b->tags();
        if (grep(/^$tag_label$/, @tags)) {
            push(@bulbs, $b);
        }
    }
    return @bulbs;
}

sub remove_tag_from_bulb($$$)
{
    my ($self,$bulb,$tag_label) = @_;

    my $id = $self->_find_tag_id($tag_label);
    if (!defined($id)) {
        print "Unknown tag: $tag_label\n";
        return undef;
    }
    my $tag_ids = $bulb->_tag_ids();
    my $all_ones = chr(0xFF) x 8;
    $tag_ids &= ($id ^ $all_ones);
    my $tag_data = pack('a8', $tag_ids);
    $self->tellBulb($bulb, SET_TAGS, $tag_data);
    $self->tellAll(GET_TAGS, "");
}

sub add_tag_to_bulb($$$)
{
    my ($self,$bulb,$tag_label) = @_;

    my $new_tag = $self->_find_tag_id($tag_label) || $self->_next_tag_id();
    if (!defined($new_tag)) {
        print STDERR "Could not find a value to use for a new tag\n";
        return undef;
    }
    my $tag_data = pack('a8A32', ($new_tag, $tag_label));
    $self->tellAll(SET_TAG_LABELS, $tag_data);

    $new_tag |= $bulb->tag_mask();
    $tag_data = pack('a8', $new_tag);
    $self->tellBulb($bulb, SET_TAGS, $tag_data);
    $self->tellAll(GET_TAGS, "");
}

sub all_tags($)
{
    return values(%{$_[0]->{tag_labels}});
}

1;

