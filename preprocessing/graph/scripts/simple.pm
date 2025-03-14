#!/usr/bin/perl

package simple;

use FindBin;
use lib "$FindBin::Bin/../../misc";
use parse;

use Exporter;

@ISA = ("Exporter");
@EXPORT = ("applyRule", "generateSentences", "printSentence", "addTransformation", "breakSlash", "getNextPrev",
		   "entityString", "plain", "chunk", "ids", "loadVPs", "countVPs", "getVP");

# apply a single rule to the give string
# arguments: input string, next pointers, prev pointers, dependencies of rules,
#            left side of rules, right side of rules, index of rule, rules already used
sub applyRule($$$$$$$$) {
	my $asent = $_[0];
	my $next = $_[1];
	my $prev = $_[2];
	my $dep = $_[3];
	my $X = $_[4];
	my $Y = $_[5];
	my $i = $_[6];
	my $sentRules = $_[7];
    #print "APPLYRULE $i\n";

	# rules can only be applied once - do not reapply rule if already used
	if (exists $sentRules->{$i}) {
        #print "RES: FAIL1\n";
		return "";
	}

	# if the rule has any dependencies, make sure we've already used the rules its dependent on
	# as a side note: no rules currently use any dependencies - no idea if this actually works
	foreach (split(/ /, $dep->[$i])) {
		if (not exists $sentRules->{$_}) {
            #print "RES: FAIL2\n";
			return "";
		}
	}

	my @aX = split(/ /, $X->[$i]);
	my @aY = split(/ /, $Y->[$i]);
	my @pre = ();
	my @post = ();
	my %ids = ();
	my $j = 0;
	my $k = 0;

	# first and last token of the left and right sides must match
	if ($aX[0] ne $aY[0] || $aX[$#aX] ne $aY[$#aY]) {
        #print "RES: FAIL3\n";
		return "";
	}

	# if the first token is the beginning of string marker
	if ($aX[0] eq "B") {
		# the first token of the string must match the second token of the left side
		# or the left side has to be the empty string
		if ($aX[1] ne "E" && $asent->[0]->[0] != $aX[1]) {
            #print "RES: FAIL4\n";
			return "";
		}
		$k++;
	# otherwise find where the first token of the left side is, in the string
	# store everything before in @pre
	} else {
		for ($j = 0; $j <= $#$asent; $j++) {
			if ($asent->[$j]->[0] == $aX[0]) {
				last;
			}
			push(@pre, join("/", @{$asent->[$j]}));
		}
		if ($j > $#$asent) {
            #print "RES: FAIL5\n";
			return "";
		}
	}

	# ensure that we can match the left side of the rule with the current string
	# $k - index into the left side of the rule
	# $j - index into the string
	# also, make sure to grab the chunk of the string represented by each token
	# in the rule - we'll use these to generate the replacement (%ids)
	while ($k <= $#aX) {
		# check if we're at an end of string token
		if ($aX[$k] eq "E") {
			# if so, we ned to be at the end of the string, and at the last token of the left hand side
			if ($k != $#aX || $j <= $#$asent) {
                #print "RES: FAIL6\n";
				return "";
			}

		# otherwise, if there are at least two more tokens left ("A
		# B") we need to figure out if they match where we are in the
		# current string (i.e., is "A" the current token, and is "B"
		# the next token - either directly adjacent to "A", or the
		# next chunk after the "A" chunk - which will also determine
		# what part of the string "A" represents - whether it's a
		# single token or a chunk) since we're checking the next two
		# tokens, if there's only one token left, we already checked
		# it on the last pass, so it's okay to skip it
		} elsif ($k < $#aX) {
			# if the next token is the end of string marker
			if ($aX[$k + 1] eq "E") {
				# either this must be the last token of the string
				if (($j + 1) > $#$asent) {
					$ids{$aX[$k]} = join("/", @{$asent->[$j]});
					$j += 1;
				# or it must be the last chunk of the string (with no further tokens afterwards)
				} elsif (($j + $next->[$j]) > $#$asent) {
					my @ax = ();
					for (my $x = $j; $x < ($j + $next->[$j]); $x++) {
						push(@ax, join("/", @{$asent->[$x]}));
					}
					$ids{$aX[$k]} = join(" ", @ax);
					$j += $next->[$j];
				} else {
                    #print "RES: FAIL7\n";
					return "";
				}
			} else {
				# otherwise, this must not be the last token of the string, and either the next token must match
				if (($j + 1) <= $#$asent && $asent->[$j + 1]->[0] == $aX[$k + 1]) {
					$ids{$aX[$k]} = join("/", @{$asent->[$j]});
					$j += 1;
				# or the next chunk must match
				} elsif (($j + $next->[$j]) <= $#$asent && $asent->[$j + $next->[$j]]->[0] == $aX[$k + 1]) {
					my @ax = ();
					for (my $x = $j; $x < ($j + $next->[$j]); $x++) {
						push(@ax, join("/", @{$asent->[$x]}));
					}
					$ids{$aX[$k]} = join(" ", @ax);
					$j += $next->[$j];
				} else {
                    #print "RES: FAIL8\n";
					return "";
				}
			}
		}
		$k++;
	}

	# store the remainder of the string in @post
	while ($j <= $#$asent) {
		push(@post, join("/", @{$asent->[$j]}));
		$j++;
	}

	# generate the replacement - just process through the right hand side of the rule
	# using %ids when we encounter a token ID by itself (in which case it better have been
	# mentioned on the left hand side of the rule).  We don't need to use the last token
	# of the right hand side of the rule because that's in @post
	# (We did, however, put the first token of the rule into @mid, even though it won't change)
	my @mid = ();
	for ($j = 0; $j < $#aY; $j++) {
		if ($aY[$j] =~ /\//) {
			push(@mid, $aY[$j]);
		} elsif ($aY[$j] ne "B") {
			if (not exists $ids{$aY[$j]}) {
				die;
			}
			push(@mid, $ids{$aY[$j]});
		}
	}

	# resulting string is @pre, @mid, @post
    $str = join(" ", @pre, @mid, @post);
    #print "RES: $str\n";
	return join(" ", @pre, @mid, @post);
}

# generate strings via rule application - basically, give it the start
# string, the set of rules you want to apply, and limitations on how
# many rules should be applied, and it'll generate strings, and
# indicate which rules were used to generate which strings.  It will
# also take care of ensuring that the rule dependencies have been met
# (I think - again, the dependency system has never been used, so the
# code's there, but has never been tested.)

# arguments:
#   initial string
#   original string (not actually being used)
#   rule dependencies
#   left hand side of rules
#   right hand side of rules
#   rule labels
#   total number of rules
#   which rules to use (i.e., NPMOD, NPART, etc.) - use "ALL" if you want everything
#   total number of rule applications
#     positive number - total number of strings that we can generate
#     0 - full expansion - generate as many strings as possible
#     negative number - depth limited - only generate strings that can be generated by at most N rule applications to the initial string

sub generateSentences($$$$$$$$$) {
	my %rules = ();
	my %link = ();
	my %nset = ();
	my %cset = ();

	my $dep = $_[2];
	my $X = $_[3];
	my $Y = $_[4];
	my $type = $_[5];
	my $n = $_[6];
	my $count = $_[8];

	# seriously, this never gets used - not sure why its here
	my @osent = split(/ /, $_[1]);
	my ($onext, $oprev) = breakSlash(\@osent, 1);

	# labels to be used should be separated by spaces
	my %usables = ();
	foreach (split(/ /, $_[7])) {
		$usables{$_} = 1;
	}

	# %rules - set of rules we've already applied to this string
	# %links - set of edges out of this string
	# %cset - set of strings at this depth
	$rules{$_[0]} = {};
	$link{$_[0]} = {};
	$cset{$_[0]} = 1;

	do {
		# %nset - set of strings generated by the strings in %cset - will be operated on next round
		%nset = ();
		foreach (keys %cset) {
			my @asent = split(/ /, $_);
			my ($next, $prev) = breakSlash(\@asent, 1);

			# set of rules that have been already applied to this string
			my %done = ();

			# check for paired NPHEADs - we've got "person and
			# person", we want to apply the NPHEAD rule to both at the
			# same time, so we can avoid "man and person", "person and
			# woman", and instead go directly to "man and woman"
			for (my $i = 0; $i <= $#asent; $i += $next->[$i]) {
				# look for an EN CC EN
				if ($asent[$i]->[1] eq "[EN") {
					my $j = $i + $next->[$i];
					if ($j <= $#asent && $asent[$j]->[2] eq "CC") {
						$j = $j + $next->[$j];
						if ($j <= $#asent && $asent[$j]->[1] eq "[EN") {
							# check if the two ENs have the same head
							my $x = entityString(\@asent, $next, $i);
							my $y = entityString(\@asent, $next, $j);
							if ($x eq $y) {
								my $res = "";
								my $k = 0;
								my $l = 0;

								# go through the rules and find an NPHEAD rule that applies to the first EN
								# BUGBUG - we'll only use the first rule that we find that applies
								for ($k = 0; $k < $n; $k++) {
									my @aX = split(/ /, $X->[$k]);
									if ($aX[0] eq $asent[$i]->[0] && $aX[$#aX] eq $asent[$i + $next->[$i] - 1]->[0]) {
										my @az = split(/\//, $type->[$k]);
										my $deptype = $az[0];
										$deptype =~ s/^[-+]//;
										if (not exists $usables{"ALL"}) {
											if (not exists $usables{$deptype}) {
												next;
											}
										}

										if ($deptype eq "NPHEAD") {
                                            #print "$_\n";
											$res = applyRule(\@asent, $next, $prev, $dep, $X, $Y, $k, $rules{$_});
											if ($res ne "") {
												last;
											}
										}
									}
								}

								if ($res ne "") {
									my @asent = split(/ /, $res);
									my ($next, $prev) = breakSlash(\@asent, 1);

									# find an NPHEAD rule for the second EN - again, we'll only use the first rule that we find that applies
									$res = "";
									for ($l = 0; $l < $n; $l++) {
										my @aX = split(/ /, $X->[$l]);
										if ($aX[0] eq $asent[$j]->[0] && $aX[$#aX] eq $asent[$j + $next->[$j] - 1]->[0]) {
											my @az = split(/\//, $type->[$l]);
											my $deptype = $az[0];
											$deptype =~ s/^[-+]//;
											if (not exists $usables{"ALL"}) {
												if (not exists $usables{$deptype}) {
													next;
												}
											}

											if ($deptype eq "NPHEAD") {
                                                #print "$_\n";
												$res = applyRule(\@asent, $next, $prev, $dep, $X, $Y, $l, $rules{$_});
												if ($res ne "") {
													last;
												}
											}
										}
									}
								}

								# if we've found NPHEAD rules for both EN chunks, apply them at the same time
								# and then mark the rules as used in %done
								if ($res ne "") {
									if (not exists $rules{$res}) {
										$rules{$res} = {};
										$link{$res} = {};
										if ($count > 0) {
											$count--;
											if ($count == 0) {
												return \%link;
											}
										}
									}
									if (not exists $rules{$res}->{$k}) {
										$rules{$res}->{$k} = 1;
										$nset{$res} = 1;
									}
									if (not exists $rules{$res}->{$l}) {
										$rules{$res}->{$l} = 1;
										$nset{$res} = 1;
									}
									foreach my $x (keys %{$rules{$_}}) {
										if (not exists $rules{$res}->{$x}) {
											$hist{$res}->{$x} = 1;
											$nset{$res} = 1;
										}
									}

									my $lid = "$k,$l";
									if (not exists $link{$res}->{$lid}) {
										$link{$res}->{$lid} = {};
									}
									
									$link{$res}->{$lid}->{$_} = 1;

									$done{$k} = 1;
									$done{$l} = 1;
								}
							}
						}
					}
				}
			}

			# try applying all rules on the string
RuleLoop:
			for (my $i = 0; $i < $n; $i++) {
				# check if we've used this rules in the previous section
				if (exists $done{$i}) {
					next;
				}

				# check if this is a type of rule we want to use
				my @az = split(/\//, $type->[$i]);
				my $deptype = $az[0];
				$deptype =~ s/^[-+]//;
				if (not exists $usables{"ALL"}) {
					if (not exists $usables{$deptype}) {
						next;
					}
				}

				# see what happens when we apply the rule
                #print "$_\n";
                #print @az;
                #print "\n";
                my $res = applyRule(\@asent, $next, $prev, $dep, $X, $Y, $i, $rules{$_});

				if ($res ne "") {
					# initialize hash entries for the new string
					if (not exists $rules{$res}) {
						$rules{$res} = {};
						$link{$res} = {};
						# check if we've produced enough different strings
						if ($count > 0) {
							$count--;
							if ($count == 0) {
								return \%link;
							}
						}
					}
					# if we've never produced the resulting string by using the rule
					# note down that we can, and add the resulting string to the next set of strings
					if (not exists $rules{$res}->{$i}) {
						$rules{$res}->{$i} = 1;
						$nset{$res} = 1;
					}
					# also, propogate the rules used to generate the current string as being used
					# to generate the resulting string
					foreach (keys %{$rules{$_}}) {
						if (not exists $rules{$res}->{$_}) {
							$hist{$res}->{$_} = 1;
							$nset{$res} = 1;
						}
					}

					# add an edge
					my $lid = "$i";
					if (not exists $link{$res}->{$lid}) {
						$link{$res}->{$lid} = {};
					}
					
					$link{$res}->{$lid}->{$_} = 1;
				}
			}
		}

		# check if we've reached our depth limit
		if ($count < 0) {
			$count++;
			if ($count == 0) {
				return \%link;
			}
		}

		%cset = %nset;
	} while (scalar(keys %cset) > 0);

	# return the graph (strings + edges)
	return \%link;
}

# add a rewrite rule - this mostly checks that the rule doesn't already exist.
# arguments:
#   new rule's dependencies
#   new rule's left hand side
#   new rule's right hand side
#   new rule's label
#   dependencies of old rules
#   left hand side of old rules
#   right hand side of old rules
#   labels of old rules
#   number of old rules
sub addTransformation($$$$$$$$$) {
	my $cdep = $_[0];
	my $cX = $_[1];
	my $cY = $_[2];
	my $ctype = $_[3];

	my $dep = $_[4];
	my $X = $_[5];
	my $Y = $_[6];
	my $type = $_[7];

	my $n = $_[8];

	my @adep = split(/ /, $cdep);
	my %hdep;
	$cdep = join(" ", sort { $a <=> $b } @adep);
	foreach (@adep) {
		$hdep{$_} = 1;
	}

	# check if we've got different labels, or different dependencies, or different left/right sides
	my $i;
addTransformationLoop:
	for ($i = 0; $i < $$n; $i++) {
		if ($ctype ne $type->[$i]) {
			next;
		}

		foreach (split(/ /, $dep->[$i])) {
			if (not exists $hdep{$_}) {
				next addTransformationLoop;
			}
		}

		if ($cX eq $X->[$i] && $cY eq $Y->[$i]) {
			return $i;
		}
	}

	# add the rules to the old rules
	$dep->[$$n] = $cdep;
	$X->[$$n] = $cX;
	$Y->[$$n] = $cY;
	$type->[$$n] = $ctype;
	$$n++;

	return $i;
}

# print a sentence and its rewrite rules
# arguments:
#   caption ID
#   next token ID
#   string
#   rule dependencies
#   left hand side of rules
#   right hand side of rules
#   labels of rules
#   number of rules
sub printSentence($$$$$$$$) {
	my $image = $_[0];
	my $token = $_[1];
	my $sent = $_[2];
	my $dep = $_[3];
	my $X = $_[4];
	my $Y = $_[5];
	my $type = $_[6];
	my $n = $_[7];
	for (my $i = 0; $i < $n; $i++) {
		print "$i\t$dep->[$i]\t$X->[$i]\t$Y->[$i]\t$type->[$i]\n";
	}

	my @ax = ();
	foreach (@{$sent}) {
		push(@ax, join("/", @{$_}));
	}
	print "$image\t$token\t", join(" ", @ax), "\n";
}

# get the head noun of an EN chunk.  "of"s will be represented as slashes.  e.g., "body of water" -> "body/water"
# arguments:
#   string (after breakSlash)
#   next pointers
#   index of the EN chunk
sub entityString($$$) {
	my $ax = $_[0];
	my $next = $_[1];
	my $start = $_[2];

	my @s = ();
	for (my $i = $start + 1; $i < ($start + $next->[$start] - 1); $i += $next->[$i]) {
		if ($ax->[$i]->[1] eq "[NP") {
			my @t = ();
			for (my $j = $i + 1; $j < ($i + $next->[$i] - 1); $j += $next->[$j]) {
				if ($ax->[$j]->[1] eq "[NPH") {
					for ($k = $j + 1; $k < ($j + $next->[$j] - 1); $k++) {
						push(@t, $ax->[$k]->[1]);
					}
				}
			}
			push(@s, join(" ", @t));
		}
	}

	return join("/", @s);
}

# return the plain form of a string (no tags, IDs, chunk boundaries, etc.)
# currently will remove "one" if its in an NPD chunk
sub plain($) {
	my @ax = ();
	my @ay = split(/ /, $_[0]);
	my $npm = 0;

	for (my $i = 0; $i <= $#ay; $i++) {
		my @az = split(/\//, $ay[$i]);

		# check if the last word of the NPM chunk (assuming we're in one - $npm)
		# is the same as the first word of the NPH chunk.  If so, skip it
		if (not $az[1] =~ /^[\[\]]/) {
			if ($npm == 1 && $i <= ($#ay - 3)) {
				my @aw = split(/\//, $ay[$i + 1]);
				if ($aw[1] eq "]") {
					@aw = split(/\//, $ay[$i + 2]);
					if ($aw[1] eq "[NPH") {
						@aw = split(/\//, $ay[$i + 3]);
						if ($az[1] eq $aw[1]) {
							next;
						}
					}
				}
			}

			# otherwise add the word to the output
			push(@ax, lc($az[1]));
		# if we're at the beginning of an NPD chunk, and the NPD chunk is "one"
		# figure out what the next word is, so we know if we want "an" or "a"
		# - also, if there is no next word, replace with the token "-SUD-"
		# this code currently isn't used, due to the "one" NPD chunk actually being empty
		} elsif ($az[1] eq "[NPD" && $i < $#ay) {
			@az = split(/\//, $ay[$i + 1]);
			if (lc($az[1]) eq "one") {
				my $print = 0;
				my $depth = 2;
				for (my $j = $i + 2; $j <= $#ay; $j++) {
					my @az = split(/\//, $ay[$j]);
					if ($az[1] =~ /^\[/) {
						$depth++;
					} elsif ($az[1] =~ /^\]/) {
						$depth--;
						if ($depth == 0) {
							last;
						}
					} else {
						if (lc($az[1]) =~ /^[aeiou]/) {
							$print = 1;
							push(@ax, "an");
						} else {
							$print = 1;
							push(@ax, "a");
						}
						last;
					}
				}

				if ($print == 0) {
					push(@ax, "-SUD-");
				}
				$i++;
			}

		# note down that we're in an NPM chunk, so we can check if the
		# last word of the NPM chunk and the first word of the NPH
		# chunk are the same
		} elsif ($az[1] eq "[NPM") {
			$npm = 1;
		} elsif ($az[1] eq "]") {
			$npm = 0;
		}
	}
	return join(" ", @ax);
}

# return a chunked form of the string - ensure that there are no empty chunks
sub chunk($) {
	my @ax = ();
	my @ay = split(/ /, $_[0]);
	for (my $i = 0; $i <= $#ay; $i++) {
		my @az = split(/\//, $ay[$i]);
		# not a chunk boundary, so push it into the output
		if (not $az[1] =~ /^[\[\]]/) {
			push(@ax, lc($az[1]));
		} else {
			# beginning of chunk boundary - check if there are any actual words in this chunk
			if ($az[1] =~ /^\[/) {
				my $depth = 1;
				my $found = 0;
				my $j;

				for ($j = $i + 1; $j <= $#ay; $j++) {
					my @aw = split(/\//, $ay[$j]);
					if ($aw[1] =~ /^\[/) {
						$depth++;
					} elsif ($aw[1] =~ /^\]/) {
						$depth--;
						if ($depth == 0) {
							last;
						}
					} else {
						$found = 1;
					}
				}

				# word found inside chunk, add to output
				if ($found == 1) {
					push(@ax, $az[1]);
				# no words found, advance to end of chunk
				} else {
					$i = $j;
					next;
				}
			# end of chunk boundary, add to the output
			} elsif ($az[1] =~ /^\]/) {
				push(@ax, $az[1]);
			}

			# determine if an NPD chunk consisting of "one" should be "an" or "a"
			# note - currently disabled, also we have no NPD chunks consisting of "one"
			if ($az[1] eq "[NPD" && $i < $#ay) {
				@az = split(/\//, $ay[$i + 1]);
				if (lc($az[1]) eq "one") {
					my $print = 0;
					my $depth = 2;
					for (my $j = $i + 2; $j <= $#ay; $j++) {
						my @az = split(/\//, $ay[$j]);
						if ($az[1] =~ /^\[/) {
							$depth++;
						} elsif ($az[1] =~ /^\]/) {
							$depth--;
							if ($depth == 0) {
								last;
							}
						} else {
							if (lc($az[1]) =~ /^[aeiou]/) {
								$print = 1;
#								push(@ax, "an");
							} else {
								$print = 1;
#								push(@ax, "a");
							}
							last;
						}
					}

					if ($print == 0) {
						push(@ax, "-SUD-");
					}
					$i++;
				}
			}
		}
	}
	return join(" ", @ax);
}

# return the token IDs of a string - this can be used to uniquely
# identify a string in a compact manner
# that is, if two strings have the same sequence of token IDs, any rule applications to
# either string will have the same result - otherwise this is not guaranteed
sub ids($) {
	my @ax = ();
	my @ay = split(/ /, $_[0]);
	for (my $i = 0; $i <= $#ay; $i++) {
		my @az = split(/\//, $ay[$i]);
		push(@ax, $az[0]);
	}
	return join(" ", @ax);
}

# load the SVO triples, using the output of the event scripts
# %vp is indexed via caption ID, and stores a list of VP ids
# %subj is indexed via full VP ID (including caption ID), and stores the NP id of the subject
# %dobj is indexed via full VP ID, and stores the NP id of the direct object
my %subj = ();
my %dobj = ();
my %vp = ();

# populate %vp, %subj, and %dobj using the output files
sub loadVPs($) {
	my $file;
	my $pre = $_[0];

	# get subjects
	%subj = ();
	open($file, "$pre.subj");
	while (<$file>) {
		chomp($_);
		my @ax = split(/\t/, $_);
		my @ay = split(/\#/, $ax[1]);
		$subj{$ax[0]} = $ay[2];
	}
	close($file);

	# get VPs
	%vp = ();
	open($file, "$pre.vp");
	while (<$file>) {
		chomp($_);
		my @ax = split(/\t/, $_);
		my @ay = split(/\#/, $ax[0]);
		my $id = "$ay[0]#$ay[1]";
		if (not exists $vp{$id}) {
			$vp{$id} = ();
		}
		push(@{$vp{$id}}, $ay[2]);
	}
	close($file);

	# get direct objects
	%dobj = ();
	open($file, "$pre.dobj");
	while (<$file>) {
		chomp($_);
		my @ax = split(/\t/, $_);
		my @ay = split(/\#/, $ax[2]);
		$dobj{$ax[0]} = $ay[2];
	}
	close($file);
}

# return the total number of VP/SVOs in a caption
sub countVPs($) {
	if (exists $vp{$_[0]}) {
		return scalar @{$vp{$_[0]}};
	}
	return 0;
}

# return the subj (NP id), vp (VP id), and direct object (NP id) of a given SVO triple
# arguments:
#   string (post breakSlashes)
#   next pointers
#   prev pointers
#   caption ID
#   SVO index (between 0 and the results of countVPs)
sub getVP($$$$$) {
	my $s = $_[0];
	my $next = $_[1];
	my $prev = $_[2];
	my $cid = $_[3];
	my $i = $_[4];
	my $v = $vp{$cid}->[$i];
	my $vid = $cid . "#" . $v;
	my $rsubj = -1;
	my $rvp = -1;
	my $rdobj = -1;

	# find the subject and direct object if there is one
	for ($i = 0; $i <= $#$s; $i += $next->[$i]) {
		if ($s->[$i]->[1] eq "[EN") {
			if ($subj{$vid} eq $s->[$i]->[2]) {
				$rsubj = $i;
			}
			if ($dobj{$vid} eq $s->[$i]->[2]) {
				$rdobj = $i;
			}
		} elsif ($s->[$i]->[1] eq "[VP") {
			if ($v eq $s->[$i]->[2]) {
				$rvp = $i;
			}
		}
	}

	if ($rsubj == -1 && exists $subj{$vid}) {
		$rsubj = -2;
	}
	if ($rvp == -1) {
		$rvp = -2;
	}
	if ($rdobj == -1 && exists $dobj{$vid}) {
		$rdobj = -2;
	}

	# returns:
	#   indices of: subject, vp, and direct object
	#   IDs of: subject, vp, and direct object
	# -1 index means there isn't a subject/vp/direct object
	# -2 index means there should've been a subject/vp/direct object, but it wasn't found
	return ($rsubj, $rvp, $rdobj, $subj{$vid}, $v, $dobj{$vid});
}

return 1;
