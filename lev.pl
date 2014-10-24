#!/usr/bin/perl

# lev.pl
#
# Usage: lev.pl file1 file2
# Simple demo of lebenshtein algorithm on two input files, prints the
# effective "difference" between the contents of each file in terms
# of the number of substitutions/deletions/insertions required to
# transmute one string into the other.

use strict;
use warnings;
use List::Util qw(min);

# This algorithm is from wikibooks.org levenshtein.
sub leven {
    my ($str1, $str2) = @_;
    my @ar1 = split //, $str1;
    my @ar2 = split //, $str2;
 
    my @dist;
    $dist[$_][0] = $_ foreach (0 .. @ar1);
    $dist[0][$_] = $_ foreach (0 .. @ar2);
 
    foreach my $i (1 .. @ar1){
        foreach my $j (1 .. @ar2){
            my $cost = $ar1[$i - 1] eq $ar2[$j - 1] ? 0 : 1;
            $dist[$i][$j] = min(
                        $dist[$i - 1][$j] + 1, 
                        $dist[$i][$j - 1] + 1, 
		$dist[$i - 1][$j - 1] + $cost );
        }
    }
 
    return $dist[@ar1][@ar2];
}



if( @ARGV != 2 ){
    die("Needs 2 input files to compare.");
}

my $file1 = $ARGV[0];
my $file2 = $ARGV[1];


open my $fh1, '<', $file1 or die "error opening $file1: $!";
my $data1 = do { local $/; <$fh1> };

open my $fh2, '<', $file2 or die "error opening $file2: $!";
my $data2 = do { local $/; <$fh2> };


#print "$data1\n";
#print "$data2\n";
my $length1 = `cat $file1 | wc -m`;
my $length2 = `cat $file2 | wc -m`;
my $lev_distance = leven($data1,$data2);
my $normalized_dist1 = $lev_distance/(1.0*$length1);
my $normalized_dist2 = $lev_distance/(1.0*$length2);

#print "$length1\n";

#output the levenshtein distance
print "$lev_distance\t$normalized_dist1\t$normalized_dist2\n";
