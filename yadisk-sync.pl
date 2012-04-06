#! /usr/bin/perl
use uni::perl;
use autodie;

use Config::Tiny;
use AnyEvent::Inotify::Simple;
use EV;

my $cfg = Config::Tiny->read("$ENV{HOME}/.yadiskrc")
    or die "Need ~/.yadiskrc config\n";

my $is_dirty = 1;   # ensure a sync on start
my $is_syncing = 0;

my $inotify = AnyEvent::Inotify::Simple->new(
    directory      => $cfg->{paths}->{folder},
    event_receiver => sub {
        my ($event, $file, $moved_to) = @_;
        given ($event) {
            when ([qw/access open close/]) { }
            default {
                say "$event --> $file";
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

EV::loop;
