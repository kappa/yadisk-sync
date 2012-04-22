#! /usr/bin/perl
use uni::perl;

# This was a debugging helper. Now obsolete!
# Exists for the sake of AnyEvent::XMPP reference.

use Config::Tiny;
use AnyEvent::XMPP::IM::Connection;
use EV;

my $cfg = Config::Tiny->read("$ENV{HOME}/.yadiskrc")
    or die "Need ~/.yadiskrc config\n";

my $xmpp = AnyEvent::XMPP::IM::Connection->new(
    jid         => $cfg->{auth}->{login},
    resource    => 'YandexDisk-kappaclient',
    host        => 'push.xmpp.yandex.ru',
    port        => 5222,
    password    => $cfg->{auth}->{password},
    dont_retrieve_roster => 1,
    initial_presence => undef,
);

$xmpp->reg_cb(debug_recv => sub { say "S: $_[1]" });
$xmpp->reg_cb(debug_send => sub { say "C: $_[1]" });
$xmpp->reg_cb(error => sub { warn "xmpp error: " . $_[1]->string . "\n" });

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
                        { name => 'version', childs => ['0.1'] },
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
    	say "Yay, we got pushed";
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
        sub { say $_[0]->as_string },
        to => $cfg->{auth}->{login},
    );
});

$xmpp->connect;

EV::loop;
