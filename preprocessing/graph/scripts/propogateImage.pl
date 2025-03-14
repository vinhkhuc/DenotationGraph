#!/usr/bin/perl

# ./propogateImage.pl <tree> <sent-cap map>

use strict;
use warnings;

$| = 1;

my $file;

# grab the node-caption map, mark all nodes as being correct, initially
my %sent = ();
my %correct = ();
open($file, "$ARGV[1]");
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	my $i = shift(@ax);
	$sent{$i} = {};
	foreach(@ax) {
		$sent{$i}->{$_} = 1;
	}
	$correct{$i} = 1;
}
close($file);

# load the edges - any node that is a parent is potentially incorrect
my %link = ();
open($file, "$ARGV[0]");
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	if (not exists $link{$ax[2]}) {
		$link{$ax[2]} = {};
	}
	$link{$ax[2]}->{$ax[0]} = 1;
	$correct{$ax[2]} = 0;
}
close($file);

my $changed = 0;

# the leaf nodes are correct, and can be ignored
foreach (keys %correct) {
	if ($correct{$_} == 1) {
		delete $correct{$_};
	}
}

# go through the incorrect nodes - see if there's any with no incorrect children
# if so, we can update them, and then flag them as correct
my $old = -1;
while (scalar keys %correct > 0) {
	# check if we've got a cycle - if so, print out the nodes in the cycle and end
	if ((scalar keys %correct) == $old) {
        print "cycle!!!\n";
        print "$old\n";
		foreach (keys %correct) {
			print " $_";
		}
		print "\n";
		exit;
	} else {
		$old = scalar keys %correct;
	}

	# for each incorrect node...
	foreach my $i (keys %correct) {
		# check if we have any incorrect children
		my $good = 1;
		foreach my $c(keys %{$link{$i}}) {
			if (exists $correct{$c}) {
				$good = 0;
				last;
			}
		}

		# if we do not, update the node's captions, and flag it as being correct
		if ($good == 1) {
			delete $correct{$i};
			foreach my $c (keys %{$link{$i}}) {
				foreach (keys %{$sent{$c}}) {
					if (not exists $sent{$i}->{$_}) {
                        $sent{$i}->{$_} = 1;
						$changed++;
					}
				}
			}
		}
	}
}

# if we've changed anything, output the new map
if ($changed > 0) {
	system("mv $ARGV[1] $ARGV[1].bak");
	open($file, ">$ARGV[1]");
	foreach (sort { $a <=> $b } keys %sent) {
		print $file "$_\t", join("\t", sort keys %{$sent{$_}}), "\n";
	}
	close($file);
}
