#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(ceil floor);

die "missing params : (1)samplepath_without_number_and_extension[.wav] (2)nbsteps (3)group (4)openess\n" if $#ARGV <= 2;

#statics params for hihat openess with +/-2 step for fades
# my @a = (0,0,6,10);
# my @b = (7,11,14,18);
# my @c = (15,19,22,26);
# my @d = (23,27,30,34);
# my @e = (31,35,38,42);
# my @f = (39,43,46,50);
# my @g = (47,51,54,58);
# my @h = (55,59,62,66);
# my @i = (63,67,70,74);
# my @j = (71,75,78,82);
# my @k = (79,83,86,90);
# my @l = (87,91,94,98);
# my @m = (95,99,102,106);
# my @n = (103,107,110,114);
# my @o = (111,115,118,122);
# my @p = (119,123,127,127);
#statics params for hihat openess with +/-4 step for fades
my @a = (0,0,4,12);
my @b = (5,13,12,20);
my @c = (13,21,20,28);
my @d = (21,29,28,36);
my @e = (29,37,36,44);
my @f = (37,45,44,52);
my @g = (45,53,52,60);
my @h = (53,61,60,68);
my @i = (61,69,68,76);
my @j = (69,77,76,84);
my @k = (77,85,84,92);
my @l = (85,93,92,100);
my @m = (93,101,100,108);
my @n = (101,109,108,116);
my @o = (109,117,116,124);
my @p = (117,125,124,127);

my %hhfad = (
	"a" => \@a,
	"b" => \@b,
	"c" => \@c,
	"d" => \@d,
	"e" => \@e,
	"f" => \@f,
	"g" => \@g,
	"h" => \@h,
	"i" => \@i,
	"j" => \@j,
	"k" => \@k,
	"l" => \@l,
	"m" => \@m,
	"n" => \@n,
	"o" => \@o,
	"p" => \@p
);

#grab argument values
print "sample : $ARGV[0]\n";
print "steps : $ARGV[1]\n";
print "group : $ARGV[2]\n";
print "openess : $ARGV[3]\n";

my $sample = $ARGV[0];
my $nbvals = $ARGV[1];
my $group = $ARGV[2];
my $openess = $ARGV[3];

die "bad openess reference" unless exists $hhfad{$openess};
my $xfin_locc4 = $hhfad{$openess}[0];
my $xfin_hicc4 = $hhfad{$openess}[1];
my $xfout_locc4 = $hhfad{$openess}[2];
my $xfout_hicc4 = $hhfad{$openess}[3];

my $lovel = 1;
my $hivel;

#create lines
for my $i (1..$nbvals) {
	#calculate velocity steps
	$hivel = floor($lovel+((127-$lovel-1)/($nbvals-$i+1)));
	$hivel = 127 if ($i == $nbvals);
	#format number to three digits
	my $num3 = sprintf '%3d', $i;
	$num3 =~ s/\s/0/g;
	print "<region> sample=".$sample.$num3.".wav lovel=$lovel hivel=$hivel group=$group xfin_locc4=$xfin_locc4 xfin_hicc4=$xfin_hicc4 xfout_locc4=$xfout_locc4 xfout_hicc4=$xfout_hicc4\n";
	$lovel = $hivel+1;
}