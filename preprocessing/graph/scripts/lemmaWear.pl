#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../misc";
use util;
use parse;

my $file;
my @line = ();
my %clothing = ();
open($file, $ARGV[0]);
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	if ($#ax >= 2) {
		my @ay = split(/ /, $ax[2]);
		my @ar = ();
		breakSlash(\@ay, 1);

		# look for "wear", "dressed in" and "dresed up in"
		# convert them all to "wear", and save clothing terms
		for (my $i = 0; $i <= $#ay; $i++) {
			push(@ar, join("/", @{$ay[$i]}));
			# [VP x ]
			if (($i + 3) <= $#ay && $ay[$i]->[1] eq "[VP" && $ay[$i + 2]->[1] eq "]") {
				my $j = -1;
				
				if ($ay[$i + 1]->[1] eq "wear") {
					if ($ay[$i + 3]->[1] eq "[EN") {
						$j = $i + 3;
					}
				# [VP dressed ] [PP/PRT x ]
				} elsif (($i + 6) <= $#ay && $ay[$i + 1]->[1] eq "dressed" && ($ay[$i + 3]->[1] eq "[PP" || $ay[$i + 3]->[1] eq "[PRT") && $ay[$i + 5]->[1] eq "]") {
					# [VP dressed ] [PP/PRT in ] [EN
					if ($ay[$i + 4]->[1] eq "in" && $ay[$i + 6]->[1] eq "[EN") {
							$j = $i + 6;
							$ay[$i + 1]->[1] = "wear";
							# BUGBUG: shouldn't need to change this
							$ay[$i + 1]->[2] = $ay[$i]->[2];
							push(@ar, join("/", @{$ay[$i + 1]}));
							$i = $i + 4;
					# [VP dressed ] [PP/PRT up ] [PP/PRT in ] [EN
					} elsif (($i + 9) <= $#ay && $ay[$i + 4]->[1] eq "up" && ($ay[$i + 6]->[1] eq "[PP" || $ay[$i + 6]->[1] eq "[PRT") && $ay[$i + 7]->[1] eq "in" &&
							 $ay[$i + 8]->[1] eq "]" && $ay[$i + 9]->[1] eq "[EN") {
						$j = $i + 9;
						$ay[$i + 1]->[1] = "wear";
						# BUGBUG: shouldn't need to change this
						$ay[$i + 1]->[2] = $ay[$i]->[2];
						push(@ar, join("/", @{$ay[$i + 1]}));
						$i = $i + 7;
					}
				}
				
				# $j is a pointer to the next thing after the VP chunk
				# find the next NPH chunk, and assume that that's a
				# piece of clothing.
				if ($j != -1) {
                    #print "*$_\n";
					my $depth = 0;
					for (; $j <= $#ay; $j++) {
						if ($ay[$j]->[1] =~ /^\[/) {
							$depth++;
							if ($ay[$j]->[1] eq "[NPH") {
								my @aw = ();
								$j++;
								while ($j <= $#ay && $ay[$j]->[1] ne "]") {
									push(@aw, $ay[$j]->[1]);
									$j++;
								}
								
								$clothing{join(" ", @aw)} = 1;
								#print "*";
                                #print join(" ", @aw);
                                #print "\n";
                                last;
							}
						} elsif ($ay[$j]->[1] =~ /^\]/) {
							$depth--;
							if ($depth == 0) {
								last;
							}
						}
					}
				}
			}
		}
		$ax[2] = join(" ", @ar);
	}

	push(@line, join("\t", @ax));
}
close($file);

# go through each line - we'll look for the PP chunk "in" followed by
# an EN chunk, and see if it's a recognized clothing head noun.  If it
# is, we'll change the "in" to a "wear".
foreach (@line) {
	my @al = split(/\t/, $_);
	if ($#al >= 2) {
		my @ax = split(/ /, $al[2]);
		my @aw = ();

		breakSlash(\@ax, 1);
		for (my $j = 0; $j <= $#ax; $j++) {
			push(@aw, join("/", @{$ax[$j]}));
			# [PP in ] [EN ...
			if (($j + 3) < $#ax && $ax[$j]->[1] eq "[PP" && $ax[$j + 1]->[1] eq "in" && $ax[$j + 2]->[1] eq "]" && $ax[$j + 3]->[1] eq "[EN") {
				my $depth = 0;
				my $c = "";
				for (my $k = $j + 3; $k <= $#ax; $k++) {
					if ($ax[$k]->[1] =~ /^\[/) {
						$depth++;
						if ($ax[$k]->[1] eq "[NPH") {
							my @az = ();
							$k++;
							while ($k <= $#ax && $ax[$k]->[1] ne "]") {
								push(@az, $ax[$k]->[1]);
								$k++;
							}
							
							$c = join(" ", @az);
							last;
						}
					} elsif ($ax[$k]->[1] =~ /^\]/) {
						$depth--;
						if ($depth == 0) {
							last;
						}
					}
				}

				if (exists $clothing{$c}) {
					pop(@aw);
					push(@aw, $ax[$j]->[0] . "/[VP/VPwear");
					push(@aw, $ax[$j + 1]->[0] . "/wear/VB");
					$j = $j + 1;
				}
			}
		}
		$al[2] = join(" ", @aw);
	}
	print join("\t", @al), "\n";
}

