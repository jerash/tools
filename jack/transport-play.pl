############################################
#!/usr/bin/perl
use warnings;
use strict;
use IPC::Open3;

#interface to "bc" calculator 
#my $pid = open3(\*WRITE, \*READ, \*ERROR,"bc"); 
my $pid = open3(\*WRITE, \*READ,0,"jack_transport");
            #if \*ERROR is false, STDERR is sent to STDOUT  
#send query
print WRITE "play\n";
#get the answer 
chomp(my $answer = <READ>);
print "$answer\n";

print WRITE "exit\n";
#get the answer 
chomp($answer = <READ>);
print "$answer\n";

########################################