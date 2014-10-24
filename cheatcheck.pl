#!/usr/bin/perl

# cheatcheck.pl
#
# Usage: cheatcheck.pl /directory/to/solutions/
#
# First parses all information into lookuptable and creates
# a problemlist and idlist.
#
# Then, it uses an algorithm to compute the levenschtein
# distance to compare each pair of student answers. The
# differences are stored as a 2D hash per problem, with the
# indexes being the student IDs.
#
# The data is then parsed to make some comglomerate statistics
# for each problem, and then attempts to find outliers which
# are reported for manual checking of plagurism.
#
#
# This currently is an early version that has some redundant
# and awkward terminology for some of the variables. Of course,
# these things sometimes don't get fixed.
#
# This could be parallelized "easily" since the only real
# computation difficulty is the lev() function on each pair
# of answers, which can be run in parallel.


use warnings;
use strict;
use File::Glob;
use List::Util qw(min);
use List::Util qw(max);
use List::Util qw(sum);

if( @ARGV != 1 ){
    die("Needs directory containing answer files as input.");
}

my $directory = $ARGV[0];

my @files = <$directory*>;

my %lookuptable;
my %problemhash;
my @problemlist;
my @idlist;
my @idpairs;

my %distancetable;


print "\n";
print "|--------------------------------------------------------------------|\n";
print "|                                                                    |\n";
print "|  Starting Cheatcheck.pl... Big brother is gonna getcha!            |\n";
print "|                                                                    |\n";
print "|--------------------------------------------------------------------|\n";
print "\n";
print "\n";
print "...This could take a while since the algorithm scales as O(n^2)...\n";
print "...  On a single core on the qc control cluster runtime ~2hrs  ...\n\n";

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
#    print "Scanning $file, label: $label\n";

    open(my $FH, "<", "$file") or die "cannot open $file: $!";

    # Parse each file and store in the lookup table. Also
    # find solution fields and add to problemlist.
    while(<$FH>){
	$_ =~ /^(.+):=(.*)$/;
	my $field = $1;
	$lookuptable{$label}{$field} = "$2";
#	print "lookuptable[$label][$1]=$2\n";

	# If the field is one of the solutions, add it to the
	# hash of problems that we'll check.
	# This SKIPS FINALSOLUTIONS, but keeps regular solutions.
	if($field =~ /^SOLUTION.*/){
	    $problemhash{$field} = 1;
	}

    } 

}

@problemlist = keys(%problemhash);

print "Problems to check: @problemlist\n";
#print "IDs loaded: @idlist\n";


my %distancelist;
my %datalist;
my $datalistpairs=0;
my %pairlist;
my %distancelistnormalized;

# For every problem, loop through every pair of students and compare their answers.
# I do this the lazy naive way, takes n^2 iterations rather than n^2/2.
foreach my $problem (@problemlist)
{
    my %visitedhash;


    foreach my $student1 (@idlist)
    {
	foreach my $student2 (@idlist)
	{
	    # Ugly hack to skip symmetric doubles and identities.
	    if(!($visitedhash{$student1}{$student2}) and !($student1 == $student2))
	    {
		# Ugly hack to skip doubles.
		$visitedhash{$student1}{$student2} = 1;
		$visitedhash{$student2}{$student1} = 1;

		my $solution1 = $lookuptable{$student1}{$problem}; 
		my $solution2 = $lookuptable{$student2}{$problem};
		my $distance = lev( $solution1, $solution2 );   

		# The max difference between two answers is the length of the larger solution.
		my $maxlength = max(length($solution1),length($solution2),1);
		my $normalized = $distance/$maxlength;
		
		# Store both values
		$distancetable{$problem}{$student1}{$student2}{"distance"} = $distance;
		$distancetable{$problem}{$student1}{$student2}{"normalized"} = $normalized;
		$distancetable{$problem}{$student1}{$student2}{"normalized"} = $normalized;

	
		#push(@{$distancelist{$problem}}, $distance);
		#push(@{$distancelistnormalized{$problem}}, $normalized);

		my $pair = $student1."-".$student2;
		push(@idpairs, $pair);

		$pairlist{$problem}{$pair}{"1"} = $student1;
		$pairlist{$problem}{$pair}{"2"} = $student2;
		$pairlist{$problem}{$pair}{"maxlength"} = $maxlength;
		$pairlist{$problem}{$pair}{"solution1"} = $solution1;
		$pairlist{$problem}{$pair}{"solution2"} = $solution2;


		$distancelist{$problem}{$pair} = $distance;
		$distancelistnormalized{$problem}{$pair} = $normalized;

		#For debug
		#print "distancetable[$problem][$student1][$student2] = ($distance, $normalized)\n";
	    }
	}
    }
}

# indexed by problemnumber

my %meandistance;
my %mediandistance;

#foreach my $problem (@problemlist)
#{
#    print "@{$distancelistnormalized{$problem}}\n";
#}


foreach my $problem (@problemlist)
{
    my $sum = 0;
    my $num = @idpairs;

    foreach my $pair (@idpairs){
	$sum += $distancelistnormalized{$problem}{$pair};
    }

    my $mean = $sum/$num;
    my $variance = 0;
    my $sigma = 0;

    foreach my $pair (@idpairs){
	$variance += ($distancelistnormalized{$problem}{$pair} - $mean)**(2.0)/$num;
    }

    $sigma = sqrt($variance);

    print "\n\n=== STARTING OUTPUT FOR $problem ===\n\n";
    print "Problem Statistics: \n"; 
    print "\tnum = $num\n";
    print "\tmean = $mean\n";
    print "\tvariance = $variance\n";
    print "\tsigma = $sigma\n\n";

    foreach my $pair (@idpairs){
	my $distance = $distancelistnormalized{$problem}{$pair};
	my $deviation = $mean - $distance;

	# Dont alert us unless they gave us an answer.
	if( $pairlist{$problem}{$pair}{"maxlength"} > 1 ){
	    # Dont alert us for completely different answers. Probably no longer needed.
	    if( $distance < 1.0 ) {

		# Most answers tend to be around .7 or .8 different.
		if( $distance < 0.3 ){
		    my $solution1 = $pairlist{$problem}{$pair}{"solution1"};
		    my $solution2 = $pairlist{$problem}{$pair}{"solution2"};
		    print "Anomale Detected: distance < 0.3\n";
		    print "\t Pair: $pair\n";
		    print "\t Problem: $problem\n";
		    print "\t distance = $distance\n";
		    print "\t deviation = $deviation\n";
		    print "\t solution1 = $solution1\n";
		    print "\t solution2 = $solution2\n";
		    # print "\t variance = $variance\n";
		    # print "\t sigma = $sigma\n";
		    # print "\t mean = $mean\n\n";
		}elsif( $deviation > 5.0*$sigma ){
		    my $solution1 = $pairlist{$problem}{$pair}{"solution1"};
		    my $solution2 = $pairlist{$problem}{$pair}{"solution2"};
		    print "Anomale Detected: deviation > 5sigma \n";
		    print "\t Pair: $pair\n";
		    print "\t Problem: $problem\n";
		    print "\t distance = $distance\n";
		    print "\t deviation = $deviation\n";
		    print "\t solution1 = $solution1\n";
		    print "\t solution2 = $solution2\n";
		    # print "\t variance = $variance\n";
		    # print "\t sigma = $sigma\n";
		    # print "\t mean = $mean\n\n";
		}
	    }
	}
    }
}


my @partners;
# Do again with fewer restrictions to try to find study groups
foreach my $problem (@problemlist){
    foreach my $pair (@idpairs){
	my $distance = $distancelistnormalized{$problem}{$pair};

	# Dont alert us unless they gave us an answer.
	if( $pairlist{$problem}{$pair}{"maxlength"} > 1 ){
	    if( $distance < 0.5 ){
		push( @partners, $pair );
	    }
	}
    }
}


my %ingroup;
my @groups;
my %lookedat;
my $groupcounter=0;
foreach my $problem (@problemlist){
    foreach my $pair (@partners){
	
	# Check if student 1 is in a group
	my $student1 = $pairlist{$problem}{$pair}{"1"};
	my $student2 = $pairlist{$problem}{$pair}{"2"};
	
	# Mark these looked at since we might want to merge them later.
	$lookedat{$student1} ||= 1;
	$lookedat{$student2} ||= 1;
	
	# Is 1 in a group?
	if($ingroup{$student1})
	{
	    # Good, is 2 in a group?
	    if($ingroup{$student2})
	    {
		# Good, are they in the same group?
		if($ingroup{$student1} == $ingroup{$student2}){
		    # Sweet, done!
		    next;
		}else{
		    # No? Got to merge them then! Put 2's followers in 1's group.		
		    
		    # Backup student2's group id, cause it's gonna get lost.
		    my $oldstudent2group = $ingroup{$student2};
		    
		    # Now move all members of student2's group (including student2).
		    foreach my $student3 (keys %lookedat)
		    {
			if($ingroup{$student3} == $oldstudent2group){
			    $ingroup{$student3} = $oldstudent2group;
			}
		    }
		    # Now delete 2's group from the list.
		    for my $index (0 .. $#groups){
			if($groups[$index] == $oldstudent2group){
			    splice(@groups, $index, 1);
			}
		    }
		}
	    }else{
		# Okay, then lets add 2 to 1's group
		$ingroup{$student2} = $ingroup{$student1};
		next;
	    }
	}else{
	    # Well is 2 in a group?
	    if($ingroup{$student2})
	    {
		# Okay, lets add 2 to 1's group
		$ingroup{$student1} = $ingroup{$student2};
		next;
	    }else{
		# NEITHER is in a group? Loners. Add them to a group
		$ingroup{$student1} = $groupcounter;
		$ingroup{$student2} = $groupcounter;
		push(@groups, $groupcounter);
		$groupcounter += 1;
		
	    }
	}
    }
}

#Get list of unique groups.
my @shortgrouplist;    
{
    my %temphash;
    foreach my $val (values %ingroup){
	$temphash{$val} ||= 1;
	}
    @shortgrouplist = keys %temphash;
}

#Print out groups
foreach my $val (@shortgrouplist)
{
    print "Group $val:\n";
    foreach my $key (keys %ingroup)
    {
	if( $ingroup{$key} == $val )
	{
	    print "$key\n";
	}
    }
    print "\n";
}


#foreach my $problem (@problemlist)
#{
#
#    my $sum = sum(@{$datalist{$problem}{});
#    my $num = @{$distancelistnormalized{$problem}};
#    my $mean = $sum/$num;
#    my $variance = 0;
#    my $sigma = 0;
#
#    foreach my $distance (@{$distancelistnormalized{$problem}}){
#	$variance += ($distance-$mean)**(2.0)/$num;
#    }
#
#    $sigma = sqrt($variance);
#
#    print "$problem stats: \n";
#    print "\tnum = $num\n";
#    print "\tmean = $mean\n";
#    print "\tvariance = $variance\n";
#    print "\tsigma = $sigma\n\n";
#
#
#}


# Perhaps we should check if the thing is... two standard deviations from normal, or the difference is less than 0.1?



#my $length1 = `cat $file1 | wc -m`;
#my $length2 = `cat $file2 | wc -m`;
#my $lev_distance = leven($data1,$data2);
#my $normalized_dist1 = $lev_distance/(1.0*$length1);
#my $normalized_dist2 = $lev_distance/(1.0*$length2);

# This algorithm is from wikibooks.org levenshtein.
sub lev {
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


