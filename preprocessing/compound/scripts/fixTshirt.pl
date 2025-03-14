#!/usr/bin/perl

use strict;
use warnings;

my $file;

open($file, $ARGV[0]);
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	if ($#ax >= 1) {
		my @ay = split(/ /, $ax[1]);
		my @az = ();
		for (my $i = 0; $i <= $#ay; $i++) {
			# look for "t/tee" and "shirt/shirts" and replace with "t-shirt(s)"
			if (lc($ay[$i]) eq "tee-shirt") {
				push(@az, "t-shirt");
				$i++;
			} elsif (lc($ay[$i]) eq "tee-shirts") {
				push(@az, "t-shirts");
				$i++;
			} elsif (($i + 1 <= $#ay) && (lc($ay[$i + 1]) eq "shirt" || lc($ay[$i + 1]) eq "shirts") && (lc($ay[$i]) eq "t" || lc($ay[$i]) eq "tee")) {
				push(@az, "t-" . $ay[$i + 1]);
				$i++;
			} else {
				push(@az, $ay[$i]);
			}
		}
		$ax[1] = join(" ", @az);
	}

	print join("\t", @ax), "\n";
}
close($file);
