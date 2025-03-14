#!/usr/bin/perl

# usage: getOrig.pl <caption ID> <graph directory>

# map nodes produced by a caption to the actual original
# strings (including token IDs) of the caption

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
use simple;

my $file;

# first, get all of the indicies generated by the caption
# hopefully it'll save us time during the later processing
my %index = ();
open($file, "$ARGV[1]/cap-node.map");
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	if (shift(@ax) eq $ARGV[0]) {
		foreach (@ax) {
			$index{$_} = 1;
		}
		last;
	}
}
close($file);

# now get the actual strings for the indicies
my %string = ();
open($file, "$ARGV[1]/node.idx");
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	if (exists $index{$ax[0]}) {
		$index{$ax[0]} = $ax[1];
		$string{$ax[1]} = $ax[0];
	}
}
close($file);

# read the initial string + the rules
# @X - left side of rule
# @Y - right side of rule
# @dep - rule dependencies (we're going to null this out since we won't be tracking rules used)
# @type - label/type of the rules
# $init - initial original string
my @X = ();
my @Y = ();
my @dep = ();
my @type = ();
my $init;
open($file, "$ARGV[1]/initial.rewrite");
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	if ($#ax == 1) {
		$ax[2] = "";
	}

	if ($#ax == 2) {
		# if we've found the caption, we've already recorded the rules
		# so copy the initial string, and finish
		if ($ax[0] eq $ARGV[0]) {
			$init = $ax[2];
			last;
		}

		# not the right caption - reset the rules
		@X = ();
		@Y = ();
		@type = ();
	} elsif ($#ax == 4) {
		$dep[$ax[0]] = "";
		$X[$ax[0]] = $ax[2];
		$Y[$ax[0]] = $ax[3];
		$type[$ax[0]] = $ax[4];
	}
}
close($file);

if (not defined $init) {
	print STDERR "$ARGV[0] not found\n";
	exit;
}

# get the edges (+ the rules used to generate them)
my %links = ();
open($file, "$ARGV[1]/node-tree.txt");
while (<$file>) {
	chomp($_);
	my @ax = split(/\t/, $_);
	my $x = shift(@ax);
	shift(@ax);
	my $y = shift(@ax);

	foreach (@ax) {
		my @ay = split(/\#/, $_);
		my $id = $ay[0] . "#" . $ay[1];

		if ($#ay >= 2 && $id eq $ARGV[0] && exists $type[$ay[2]]) {
			if ($type[$ay[2]] =~ /^\+/) {
				if (not exists $links{$y}) {
					$links{$y} = {};
				}
				$links{$y}->{$ay[2]} = $x;
			} elsif ($type[$ay[2]] =~ /^-/) {
				if (not exists $links{$x}) {
					$links{$x} = {};
				}
				$links{$x}->{$ay[2]} = $y;
			}
		}
	}
}
close($file);

# generate the original strings of the caption's nodes
# %visit - original strings we've already processed
# @queue - our work queue (contains original strings to visit)
# %orig - index -> original strings
my %visit = ();
my @queue = ();
my %orig = ();

push(@queue, $init);
$visit{$init} = 1;
while ($#queue >= 0) {
	my $q = shift(@queue);
	my $i = $string{plain($q)};

	# match the original string and its index
	if (not exists $orig{$i}) {
		$orig{$i} = {};
	}
	$orig{$i}->{$q} = 1;

	# make the more navigable version of the string (used by applyRule)
	my @aq = split(/ /, $q);
	my ($qnext, $qprev) = breakSlash(\@aq, 1);

	# try applying each rule that we've seen for this node
	foreach my $rule (keys %{$links{$i}}) {
		if (exists $X[$rule]) {
			my $r = applyRule(\@aq, $qnext, $qprev, \@dep, \@X, \@Y, $rule, {});

			# if we generated a new original string that hasn't been visited before, add it to the queue
			if ($r ne "" && !exists $visit{$r}) {
				push(@queue, $r);
				$visit{$r} = 1;
			}
		}
	}
}

foreach my $i (sort {$a <=> $b} keys %orig) {
	foreach (keys %{$orig{$i}}) {
		print $i, "\t", $_, "\n";
	}
}
