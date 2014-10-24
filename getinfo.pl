#!/usr/bin/perl

# getinfo.pl
#
# Usage: getinfo.pl /directory/to/solutions/
# Parses all information into lookuptable and creates
# a problemlist and idlist.

use warnings;
use strict;
use File::Glob;

if( @ARGV != 1 ){
    die("Needs directory containing answers as input.");
}

my $directory = $ARGV[0];


my @files = <$directory*>;

my %lookuptable;
my %problemhash;
my @problemlist;
my @idlist;

# Scan all files of type /$directory/999...999 and
# store the ID numbers as keys. Skip other files.
foreach my $file (@files)
{
    my $label = $file;
    if( $label =~ /.*\/([0-9]+$)/ ){
	$label = $1;
	push(@idlist,$label);
    } else {
	print "Skipping non-number file $file\n";
	next;
    }
    print "Scanning $file, label: $label\n";

    open(my $FH, "<", "$file") or die "cannot open $file: $!";

    # Parse each file and store in the lookup table. Also
    # find solution fields and add to problemlist.
    while(<$FH>){
	$_ =~ /^(.+):=(.*)$/;
	my $field = $1;
	$lookuptable{$label}{$field} = "$2";
	print "lookuptable[$label][$1]=$2\n";

	# If the field is one of the solutions, add it to the
	# hash of problems that we'll check.
	if($field =~ /.*SOLUTION.*/){
	    $problemhash{$field} = 1;
	}

    } 

}

@problemlist = keys(%problemhash);

print "Problems to check: @problemlist\n";
print "IDs loaded: @idlist\n";
