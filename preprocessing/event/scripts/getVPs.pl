#!/usr/bin/perl

# ./getVPs.pl <POS file>

use FindBin;
use lib "$FindBin::Bin/../../misc";
use parse;
use util;

my @adir = split(/\//, $0);
pop(@adir);
my $sdir = join("/", @adir);

%aux = ();
open(file, "$sdir/../data/aux.txt");
while (<file>) {
	chomp($_);
	$aux{$_} = 1;
}
close(file);

%split = ();
open(file, "$sdir/../data/split.txt");
while (<file>) {
	chomp($_);
	$split{$_} = 1;
}
close(file);

open(file, $ARGV[0]);
while (<file>) {
	chomp($_);
	@ax = split(/\t/, $_);
	@ay = split(/ /, $ax[1]);

	$s = ();
	$i = 0;
	$n = 0;
	$p = 0;
	@b = ();
	@e = ();
	while ($i <= $#ay) {
		($x, $i, $p) = parse(\@ay, $i, $p);
		$s->[$n] = $x;
		$n++;
	}
	$x = 0;
	for ($i = 0; $i < $n; $i++) {
		if ($s->[$i]->[0] eq "VP") {
			@vp = ();
			foreach (split(/ /, $s->[$i]->[1])) {
                @az = split(/\//, $_);
				if ($az[1] =~ /^V/) {
					$w = lc(vlemma($az[0]));
                    if ($w ne "be") {
						push(@vp, $w);
					}
				} elsif ($az[1] eq "TO") {
					@vp = ();
				}
			}
			while ($#vp > 0) {
				if (exists $aux{$vp[0]}) {
					shift(@vp);
				} else {
					last;
				}
			}

			if ($#vp >= 0) {
				print "$ax[0]#VP$x\t", join(" ", @vp), "\n";
			} else {
				@az = split(/ /, $s->[$i]->[1]);
				if ($#az >= 0) {
					$vp = vlemma(tokenize($az[$#az]));
					print "$ax[0]#VP$x\t$vp\n";
				}
			}
			$x++;
		}
	}
}
close(file);
