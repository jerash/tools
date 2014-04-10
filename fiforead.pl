#!/usr/bin/perl

use strict;
use warnings;

$| = 1;

my $fifofile = "/tmp/testfifo";

our $fifo_fh;

use Fcntl;
use AnyEvent;

$| = 1;
# open in non-blocking mode if nothing is to be read in the fifo
sysopen($fifo_fh, $fifofile, O_RDWR) or warn "The FIFO file \"$fifofile\" is missing\n";

#create the anyevent watcher on this socket
my $blip = AE::io( $fifo_fh, 0, sub { while (<$fifo_fh>) { print "$_"; return;} } );

#main loop waiting
#--------------------------------------
my $cv = AE::cv;
$cv->recv;

close $fifo_fh;

