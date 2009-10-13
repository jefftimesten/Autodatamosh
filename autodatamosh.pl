#!/usr/bin/perl

# Autodatamosh script copyleft 2009 Joe Friedl
# http://joefriedl.net
#
# Released under the GPLv3 license: http://www.gnu.org/licenses/gpl.html

use strict;
use warnings;

# Use STDIN and STDOUT by default
open(our $infile,'<&STDIN');
open(our $outfile,'>&STDOUT');

my $infilename = '';
my $outfilename = '';

# Loop through command line arguments
for my $n (0..$#ARGV)
{
	for ($ARGV[$n])
	{
		# Strings that don't start with "-" will be treated as the input filename.
		# If more than one is given, the last one will be used.
		/^[^-]+/	&& do {
					$infilename = $_;
					last;
				};

		# - reads from STDIN
		/^-$/		&& do {
					$infilename = '';
					last;
				};

		# -o outfile
		/^-o$/		&& do {
					# Check for existence of next argument
					if ($#ARGV < ($n+1)) { die("No output file specified.\n"); }

					$outfilename = ($ARGV[$n+1] eq '-') ? '': $ARGV[$n+1];
					$n++;
					last;
				};

		# Default: Unknown option warning
				do {
					print STDERR "Unknown option: ".$_."\n";
					last;
				}
	}
}

# Attempt to open files if they were specified on the command line
if (length $infilename) { open($infile,'<',$infilename) or die("Could not open '".$infilename."': $!"); }
if (length $outfilename) { open($outfile,'>',$outfilename) or die("Could not open '".$outfilename."': $!"); }



# Output flag
my $out = 1;

# Sequence counter
my $seq = 0;

# Bit pattern that marks the beginning of an I-frame.
# If the first part, "00dc" (ASCII), is found, the script can assume a
# new frame has started
my @pattern = split('',"00dc*****".pack("H*","0001b0"));

my @buf;
my $outbuf;
my $tmp;

# First I-frame flag
my $first = 1;

while (<$infile>)
{
	# Split input into an array of 8-bit values
	@buf = split('',$_);

	# Initialize output
	$outbuf = '';

	for (my $i = 0; $i < @buf; $i++)
	{
		# If the pattern has started, stop output, start saving in $tmp,
		# and increment sequence counter
		if (($pattern[$seq] eq '*') || ($buf[$i] eq $pattern[$seq]))
		{
			$seq++;
			$tmp .= $buf[$i];

			if ($seq == @pattern)
			{
				# We've reached the end of the sequence

				# Continue output if this is the first frame
				if ($first)
				{
					$outbuf .= $tmp;
					$tmp = '';
					$seq = 0;

					$first = 0;
				}
				else
				{
					# Stop output and get rid of $tmp
					$tmp = '';
					$out = $seq = 0;
				}
			}
		}
		else
		{
			# If the sequence had started, dump $tmp if not within an I-frame
			if ($seq > 0)
			{
				# If a new frame started, start output back up
				# This will catch new frames after an I-frame
				if ($seq > 7) { $out = 1; }

				# If we're outputting, append $tmp to output
				if ($out) { $outbuf .= $tmp; }

				# Re-init $tmp
				$tmp = '';
			}

			# No frame container has been detected, output normally
			# if not within an I-frame
			if ($out) { $outbuf .= $buf[$i]; }

			# Reset sequence
			$seq = 0;
		}
	}

	# Dump output buffer
	print $outfile $outbuf;
}
