#!/usr/bin/perl

use strict;
use warnings;

use MIDI;
#http://search.cpan.org/~conklin/MIDI-Perl-0.83/lib/MIDI.pm
#http://search.cpan.org/~conklin/MIDI-Perl-0.83/lib/MIDI/Event.pm#EVENTS
#great calculation infos from http://www.lastrayofhope.com/2009/12/23/midi-delta-time-ticks-to-seconds/

# This script will translate a drum midifile from one layout to another
# the fixed hihat notes will add CC4 values for openess

# prefix for the output file
my $prefix = "ndk";

# Note numbers to be translated
my $values = {
  36 => 35,
  38 => 36,
  40 => 37,
  37 => 38,
  39 => 39,
  42 => 40,
  48 => 79,
  49 => 74,
  51 => 75,
  50 => 72,
  52 => 73,
  54 => 72,
  55 => 73,
  56 => 72,
  57 => 73,
  60 => 101,
  61 => 102,
  62 => 103,
  63 => 105,
  71 => 65,
  69 => 60,
  67 => 53,
  65 => 48,
  77 => 84,
  78 => 87,
  79 => 89,
  80 => 92,
  81 => 96,
  82 => 99
};
# Note numbers considered as hihat hits, and their relative openess CC value
my $hihats = {
  48 => 0, # hihat pedal
  49 => 16,
  51 => 25,
  50 => 20,
  52 => 35,
  54 => 55,
  55 => 75,
  56 => 90,
  57 => 120
};

sub ishihat {
  my $val = shift;
  return 1 if exists $hihats->{$val};
}

# ------- SCRIPT START ----------

my $file = shift;
die "missing file to read\n" unless $file;

#import midi file
my $song = MIDI::Opus->new( {
 "from_file" => $file,
} );

#get midi format version
my $format = $song->format;
print "Song is midi format $format\n";
return "Exiting because we only deal with format 0 midi files\n" unless $format == 0;

#get ticks
my $ticks = $song->ticks;
print "Song ticks is $ticks\n";
return "Exiting because we only deal with midi files with 96 ticks\n" unless $ticks == 96;

#get song tracks references
my @tracks = $song->tracks;
print sprintf "Found %d tracks\n",$#tracks+1;
return "Exiting because we should only have one track!\n" unless $#tracks == 0;

# An event is a list, like:  
# ( 'note_on', 141, 4, 50, 64 ) = ('note_on', dtime, channel, note, velocity)
# ('control_change', dtime, channel, controller(0-127), value(0-127))
# where the first element is the event name
# the second is the delta-time
# the remainder are further parameters, per the event-format specifications below.

# ------- TRANSPOSE EVENTS ----------

my @orig_events = @{$tracks[0]->{events}};

my @new_events;
for my $eventref (@orig_events) {
  my @event = @{$eventref};
  #if we receive a note_on in the defined range
  if (( $event[0] eq "note_on" ) and (exists $values->{$event[3]}) ) {
    # if it is a hihat stroke, add CC4 message with relative openess
    if ( &ishihat($event[3]) ) {
      my $hhval = int(rand(10)) - 5 + $hihats->{$event[3]};
      $hhval = 127 if ($hhval > 127 );
      $hhval = 0 if ($hhval < 0 );
      my @CC = ('control_change', $event[1], $event[2], 4, $hhval);
      push @new_events,\@CC;
      # change original event midi position to zero (same position as CC4 just inserted)
      $event[1] = 0;
    }
    # transpose event
    $event[3] = $values->{$event[3]};
    push @new_events,\@event;
  }
  #if we receive a note_off in the defined range
  elsif (( $event[0] eq "note_off" ) and (exists $values->{$event[3]}) ) {
    # transpose event
    $event[3] = $values->{$event[3]};
    push @new_events,\@event;
  }
  #else simply copy the message
  else {
    print "untreated event : type $event[0] > $event[1] > $event[2] > $event[3]\n";
    push @new_events,\@event;
  }
}

# --- UPDATE SONG ---

$tracks[0]->{events} = \@new_events;

# ------- SAVE NEW FILE ----------
$song->write_to_file("$prefix_$file");

print "File saved\n";
# use Data::Dumper;
# print Dumper \@new_events;


