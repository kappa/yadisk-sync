#! /usr/bin/perl
use uni::perl;
use autodie;

use Config::Tiny;
use AnyEvent::Inotify::Simple;
use AnyEvent::XMPP::IM::Connection;
use Linux::Proc::Mounts;

our $VERSION = '0.21';

my $cfg = Config::Tiny->read("$ENV{HOME}/.yadiskrc")
    or die "Need ~/.yadiskrc config\n";

my $is_dirty = 1;   # ensure a sync on start
my $is_syncing = 0;

my $mounts = Linux::Proc::Mounts->read;
unless (@{$mounts->at($cfg->{paths}->{webdav})}) {
    say "Mounting WebDAV.";
    system(mount => $cfg->{paths}->{webdav});
}

# We have 3 event sources:
# 1. inotify is a recursive inotify(2) watcher for ~/YandexDisk
# 2. timer is a ticking timer with 10s interval
# 3. xmpp is an XMPP client receiving push events from the cloud

my $inotify = AnyEvent::Inotify::Simple->new(
    directory      => $cfg->{paths}->{folder},
    event_receiver => sub {
        my ($event, $file, $moved_to) = @_;
        given ($event) {
            when ([qw/access open close/]) { }
            default {
                say "local inotify: $event --> $file";
                $is_dirty = 1;
            }
        }
    },
);

my $timer = AnyEvent->timer (after => 5, interval => 10, cb => sub {
    if ($is_dirty && !$is_syncing) {
        $is_syncing = 1;

        system('unison', $cfg->{paths}->{webdav},
            $cfg->{paths}->{folder},
            '-silent',
            '-mountpoint', 'Documents',
            '-ignore', 'Name lost+found',
        );

    	$is_syncing = $is_dirty = 0;
    }
});

my $xmpp = AnyEvent::XMPP::IM::Connection->new(
    jid         => $cfg->{auth}->{login},
    resource    => "YandexDisk-kappaclient-$^T-" . rand(),
    host        => 'push.xmpp.yandex.ru',
    port        => 5222,
    password    => $cfg->{auth}->{password},
    dont_retrieve_roster => 1,
    initial_presence => undef,
);

# handle incoming iq get stanzas
$xmpp->reg_cb(iq_get_request_xml => sub {
    my ($con, $node, $rhandled) = @_;

    if    ($node->find_all(['urn:xmpp:ping', 'ping'])) {
    	$con->reply_iq_result($node);
    	$$rhandled = 1;
    }
    elsif ($node->find_all(['jabber:iq:version', 'query'])) {
    	$con->reply_iq_result($node,
            {
            	defns => 'jabber:iq:version',
            	node => {
            	    name => 'query',
            	    childs => [
                        { name => 'name', childs => ['yadisk-sync.pl'] },
                        { name => 'version', childs => [$VERSION] },
                        { name => 'os', childs => ['Linux'] },
                    ],
            	},
            }
        );
    	$$rhandled = 1;
    }
});

# handle incoming iq set stanzas
$xmpp->reg_cb(iq_set_request_xml => sub {
    my ($con, $node, $rhandled) = @_;

    if ($node->find_all(['yandex:push:disk', 'query'])) {
    	$is_dirty = 1;
    	say "remote XMPP push: " . $node->as_string;
    	$$rhandled = 1;
    }
});

# start
$xmpp->reg_cb(session_ready => sub {
    my $con = shift;

    $con->send_iq('set',
        {
            defns   => 'yandex:push:disk',
            node    => { name => 's', ns => 'yandex:push:disk' },
        },
        undef,
        to => $cfg->{auth}->{login},
    );
});

$xmpp->connect;

AnyEvent->condvar->recv;
