#!/usr/bin/perl

use strict;
use warnings;
use AnyEvent qw();
use IO::Socket::INET;
use MIDI::ALSA;

$|++;

#global event/timer variables
my $val = 127;
my $rate = 0.03937007874; #default to max 5s for 127 values = 5/127
my $timer;
my @map = (0.25,0.287,0.325,0.362,0.400,0.437,0.474,0.512,0.549,0.587,0.624,0.661,0.699,0.736,0.774,0.811,0.848,0.886,0.923,0.961,0.998,1.035,1.073,1.110,1.148,1.185,1.222,1.260,1.297,1.335,1.372,1.409,1.447,1.484,1.522,1.559,1.596,1.634,1.671,1.709,1.746,1.783,1.821,1.858,1.896,1.933,1.970,2.008,2.045,2.083,2.120,2.157,2.195,2.232,2.270,2.307,2.344,2.382,2.419,2.457,2.494,2.531,2.569,2.606,2.644,2.681,2.719,2.756,2.793,2.831,2.868,2.906,2.943,2.980,3.018,3.055,3.093,3.130,3.167,3.205,3.242,3.280,3.317,3.354,3.392,3.429,3.467,3.504,3.541,3.579,3.616,3.654,3.691,3.728,3.766,3.803,3.841,3.878,3.915,3.953,3.990,4.028,4.065,4.102,4.140,4.177,4.215,4.252,4.289,4.327,4.364,4.402,4.439,4.476,4.514,4.551,4.589,4.626,4.663,4.701,4.738,4.776,4.813,4.850,4.888,4.925,4.963,5);

#global MIDI variables
my $openess = 127; #default hh open to max
my $channel = 10; # midi channel to receive messages
my $inCC = 4; # CC number for hh openess
my $outCC = 1; # CC number to generate for enveloppe
my $inNote = 41; # note number for hh hit

#create alsa midi port with only 1 output
my @alsa_output = ("hhgen",0);
&create_midi_ports;
#my @outCC = ($channel-1, '','','',$CC,$outval);

#create udp listening socket
my $ip = 'localhost';
my $port = '8000';
print ("Starting UDP listener on ip $ip and port $port\n");
my $socket = IO::Socket::INET->new(
	LocalAddr => $ip, #default is localhost
	LocalPort => $port,
	Proto	  => 'udp',
	Type	  =>  SOCK_DGRAM) || die $!;
warn "cannot create socket $!\n" unless $socket;

sub doramp {
	$val = $val-1;
	if ($val < 0) {
		# print "\nfinished\n";
		undef $timer;
		$val=127;
		return;					
	}
	# print "val=$val\r";
	my @outCC = ($channel-1,'','','',$outCC,$val);
	MIDI::ALSA::output(MIDI::ALSA::SND_SEQ_EVENT_CONTROLLER,'','',MIDI::ALSA::SND_SEQ_QUEUE_DIRECT,0.0,\@alsa_output,0,\@outCC);
}

sub process_udpreceive {
	my $received_data;
	$socket->recv($received_data,1024);
	chomp($received_data);
	print "\nreceived $received_data\n";
	($rate,$val) = split ',',$received_data;
	print "\nnew rate=$rate start=$val\n";
	undef $timer;
	$timer = AnyEvent->timer(
				after => 0,
				interval => $rate,
				cb => \&doramp
			);
}
sub process_midireceive {
	if(MIDI::ALSA::inputpending) {
		my @alsaevent = MIDI::ALSA::input();
		if ($alsaevent[0] == MIDI::ALSA::SND_SEQ_EVENT_PORT_UNSUBSCRIBED) { last; }
		if ($alsaevent[0] == MIDI::ALSA::SND_SEQ_EVENT_NOTEON) {
			my $data = $alsaevent[7];
			my ($channel, $note, $notevel) = @$data;
			return unless ($notevel > 0); #note off may be noteon message with 0 velocitys
			# print "received note on ($note) with velocity ($notevel) on channel ($channel)+1\n";
			return unless (($inNote == $note) or ($inNote+1 == $note));
			# trigger envelope, at rate defined in table, modified by velocity
			# minimum velocity should reduce envelope length by 30%
			$rate = ($map[$openess])/127 * ( (((($notevel-127)/127))+1)*(1/3)+(2/3) );
			# print "trigger the enveloppe generator at length $map[$openess] and weigthed rate of $rate\n";
			undef $timer;
			$val=127; #init envelope to maximum;
			my @outCC = ($channel-1,'','','',$outCC,$val);
			MIDI::ALSA::output(MIDI::ALSA::SND_SEQ_EVENT_CONTROLLER,'','',MIDI::ALSA::SND_SEQ_QUEUE_DIRECT,0.0,\@alsa_output,0,\@outCC);
			MIDI::ALSA::output( @alsaevent ); # pass original NoteOn message
			#launch ramp
			$timer = AnyEvent->timer(
						after => 0,
						interval => $rate,
						cb => \&doramp
					);
		}
		if ($alsaevent[0] == MIDI::ALSA::SND_SEQ_EVENT_CONTROLLER) {
			my $data = $alsaevent[7];
			my ($channel, $CCnum, $CCval) = (@$data)[0,4,5];
			print "received CC ($CCnum) with value ($CCval) on channel ($channel)+1\n";
			return unless ($CCnum eq $inCC);
			#update last openess value
			$openess = $CCval;
			print "update openess to ($map[$openess])\n";
			MIDI::ALSA::output( @alsaevent ); # pass original CC openess message
		}
		# MIDI::ALSA::output( @alsaevent );
	}	
}


#create event based on udp receive
my $udp = AE::io( $socket,0, \&process_udpreceive );
my $midi = AnyEvent->timer(after => 0, interval => 0.0005, cb => \&process_midireceive );

#enter event loop
my $quit  => AE::cv->recv;



sub create_midi_ports {
	#update bridge structure
	my $clientname = "hhgen";
	my $ninputports = 1;
	my $noutputports = 1;

	#client($name, $ninputports, $noutputports, $createqueue)
	my $status = MIDI::ALSA::client($clientname,$ninputports,$noutputports,0) || die "could not create alsa midi port.\n";
	print "successfully created \"$clientname\" alsa midi client\n";
}
sub SendMidiCC {
	my $outCC = shift;
	return MIDI::ALSA::output(MIDI::ALSA::SND_SEQ_EVENT_CONTROLLER,'','',MIDI::ALSA::SND_SEQ_QUEUE_DIRECT,0.0,\@alsa_output,0,$outCC);
}

