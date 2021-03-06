package Bio::Das::ProServer::SourceAdaptor::MyCNEDensityAdaptor;

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::MyCNEAdaptorBase);

use constant DEFAULT_TYPE => 'HCNE density';
use constant DEFAULT_COLOR => '#a0a0a0';
use constant DEFAULT_MAX_SCORE => 10;
use constant DEFAULT_PIXEL_WIDTH => 500;
use constant MAX_PIXEL_WIDTH => 2000;

my $ABS_SCORE = 0;

sub init {
  my $self = shift;
  $self->{'capabilities'} = {'features'      => '1.0',
			     'stylesheet'    => '1.0'};

  my $dsn = $self->dsn;
  my $config = $self->config;
  my $transport = $self->transport;
  my $db = $transport->adaptor;

  # Parse dsn to get assembly ids and cutoffs
  my ($asm1_id, $asm2_id, $len, $identity, $win_size) = $dsn =~ /^([A-z0-9]+)_cneDens_([A-z0-9]+)_len(\d+)_id(\d+)_win(\d+)$/;
  defined($asm1_id) or die "Unable to parse dsn $dsn";
  $identity = $identity / 10; # Change to percent

  # Get more info about the two assemblies
  my $asm1_info = $db->get_assembly_info($asm1_id) or die "Unknown assembly $asm1_id";
  my $asm2_info = $db->get_assembly_info($asm2_id) or die "Unknown assembly $asm2_id";

  # Set information about DAS source unless specified in config file
  unless($config->{'title'}) {
      $self->{'title'} = $self->_make_short_organism_name($asm2_info).' HCNE dens.';
  }
  unless($config->{'description'}) {
      $self->{'description'} =
	  "Density of non-exonic sequences conserved in the ".$self->_make_long_organism_name($asm2_info).
	  " genome. Minimum $identity% identity over $len alignment columns. Sliding window size = $win_size kb.";
  }
  $self->_set_coordinates($asm1_info);
  $self->_set_mapmaster($asm1_id);

  # Set private parameters to be used when fetching features
  $self->{'cne_method_label'} = "Calculation of percent of sequence covered by HCNEs in $win_size kb sliding window";
  $self->{'cne_db_table'} = $config->{'dbtable'} || $db->get_cne_table_name(assembly1 => $asm1_id, assembly2 => $asm2_id,
									    min_identity => $identity/100, min_length => $len);
  $self->{'cne_assembly'} = $asm1_id;
  $self->{'cne_win_size'} = $win_size * 1000;   # convert window size value from kb to bp

  $transport->disconnect(); # must do this because ProServer does not clean up after dsn and sources requests
}


sub das_stylesheet {
    my $self = shift;
    my $config = $self->config;

    if($config->{'stylesheet'} or $config->{'stylesheetfile'}) {
	return $self->SUPER::das_stylesheet();
    }

    my $color = $config->{'color'} || DEFAULT_COLOR;
    my $max_score = $config->{'max_score'} || DEFAULT_MAX_SCORE;
    return qq(<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
<STYLESHEET version="1.0">
  <CATEGORY id="default">
    <TYPE id="default">
        <GLYPH>
           <HISTOGRAM>
	     <COLOR1>$color</COLOR1>
	     <MIN>0</MIN>
	     <MAX>$max_score</MAX>
	     <HEIGHT>50</HEIGHT>
	   </HISTOGRAM>
        </GLYPH>
     </TYPE>
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>
);
}


=head2 build_features : Return an array of features based on a query given in the config file

  my @aFeatures = $oSourceAdaptor->build_features({
                                                   'segment' => $sSegmentId,
                                                   'start'   => $iSegmentStart, # Optional
                                                   'end'     => $iSegmentEnd,   # Optional
                                                   'dsn'     => $sDSN,          # if used as part of a hydra
                                                  });

=cut

sub build_features {
    my ($self, $opts) = @_;
    
    # Get dsn
    my $dsn = $self->{'dsn'};
    
    # Get private parameters set by init()
    my $table = $self->{'cne_db_table'};
    my $asm = $self->{'cne_assembly'};
    my $method_label = $self->{'cne_method_label'};
    my $window_size = $self->{'cne_win_size'};
    
    # Get parameters optionally set in config file
    my $config = $self->config;
    my $type = $config->{'type'} || DEFAULT_TYPE;
    my $type_text = $config->{'type_text'} || 'Density of highly conserved noncoding elements';
    my $method = $config->{'method'} || $table;
    my $max_score = $config->{max_score} || DEFAULT_MAX_SCORE;

    # Get location to query
    my $chr = $opts->{'segment'} || die "no segment";
    my $start = $opts->{'start'} || 1;
    my $end = $opts->{'end'} || 1e9; # enough for opossum
    my $my_chr = $chr =~ /^chr/ ? $chr : "chr$chr";
    
    # Get length of the displayed segment 
    my $length = $end - $start + 1;

    # Get panel size in pixels
    my $pixel_width = $opts->{'maxbins'};
    if(!defined($pixel_width)) { $pixel_width = DEFAULT_PIXEL_WIDTH; }
    elsif($pixel_width < 1) { $pixel_width = 1; }
    elsif($pixel_width > MAX_PIXEL_WIDTH) { $pixel_width = MAX_PIXEL_WIDTH; } 
   
    # Compute the step size
    my $step_size;
    if($length <= $pixel_width) {
	# The lower limit for the step size is 1 base
	$step_size = 1;
    } 
    else {
	# If we are not not zoomed in to base resolution, 
	# we want at least 1 step / pixel and at least 10 steps / window.
	$step_size = int($length / $pixel_width);
	$step_size = int($window_size/10) if($step_size > $window_size/10);
	# Adjust the step size so that window_size is evenly divisible by it.
	while($window_size % $step_size) {  # there must be a smarter algorithm for this...
	    $step_size--;
	}
    }
    my $win_nr_steps = $window_size / $step_size;
    
    # Compute how large region we need to look at around the displayed region
    my $context_start = $start - int((($win_nr_steps-1)*$step_size)/2+0.5);
    $context_start  = 1 if($context_start < 1);
    my $context_end = $end + int((($win_nr_steps-1)*$step_size)/2+$step_size+0.5);

    # Get CNE locations
    my $transport = $self->transport;
    my $ranges = $transport->adaptor->get_cne_ranges_in_region(chr => $my_chr,
								     start => $context_start,
								     end => $context_end,
								     table_name => $table,
								     assembly => $asm);
    $ranges = collapse_intervals($ranges);  # Collapse overlapping ranges

    # Calculate the window scores (this method should be put in a module - CNE::Tools::DensityCalculator (or AT::Tools)
    my ($score_start, $win_scores) = calc_window_scores($start, $end, $ranges, $win_nr_steps, $step_size);

    #print STDERR "win_size=$window_size, step_size=$step_size, range=$start-$end, context=$context_start-$context_end, steps=$win_nr_steps\n"; 
    #print STDERR "nr_ranges=".scalar(@$ranges).", score_start=$score_start, nr_scores=".scalar(@$win_scores)."\n";

    # Make features of the expected format from the CNEs
    my @features;
    foreach my $score (@$win_scores) {
	my $score_end = $score_start + $step_size - 1;
	if($score_end >= $start and $score_start <= $end) {
	    push @features, {
		id     => $score_start,
		type   => $type,
		typetxt => $type_text,
		method => $method,
		method_label => $method_label,
		start  => $score_start,
		end    => $score_end,
		score  => $score || '0e0',
		group => 'density',
		grouptype => 'density',
	    };
	}
	$score_start += $step_size;
    }
    
    #print STDERR "** made ", scalar(@features), " features for $my_chr:$start-$end\n";
    $transport->disconnect(); # this may not be necessary but just in case...

    # Return the features
    return @features;
}


sub collapse_intervals
{
    my ($exons_ref) = @_;

    return [] unless($exons_ref and @$exons_ref);

    my @hsps = sort {$a->[0] <=> $b->[0]} @$exons_ref;

    my @iv;
    my ($start, $end) = @{$hsps[0]};
    for my $i (1..@hsps-1) {
	my ($my_start, $my_end) = @{$hsps[$i]};
	if($my_start > $end) {
	    push @iv, [$start,$end];
	    ($start, $end) = ($my_start, $my_end); 
	}
	else {
	    $end = $my_end if ($end < $my_end);
	}
    }
    push @iv, [$start,$end];
    return \@iv;
}


# The window score calculation is identical to that in CNEPlot.pm - so this should be modularized

sub calc_window_scores
{
    my ($display_start, $display_end, $ivs, $win_nr_blocks, $blk_size) = @_;
    # start and end are start of region to be shown. need to calc context start
 
#    print STDERR "nr intervals: ".scalar(@$ivs)."\n";

    my $display_size = $display_end - $display_start + 1;
    my $win_size = $win_nr_blocks * $blk_size;
    my $max_score = $blk_size * $win_nr_blocks;

    my $offset = int((($win_nr_blocks-1)*$blk_size)/2+0.5);
    my $compute_start = $display_start - $offset;
    my $compute_end = $display_end + $offset;
    my $compute_size = $compute_end - $compute_start;

    my $first_score_start; 
    my @scores;

    if($win_size > 2*$display_size) {
	# If win_size is much larger than display_size we can do some optimization.
	# by separately computing scores for a core region common to all displayed windows
	# This algorithm should work also in cases where the display region does no contain an even nr of blocks

	# Compute number of blocks n in display region. This is the same as the number of displayed window scores.
	my $nr_blocks = int($display_size / $blk_size) + ($display_size % $blk_size ? 1 : 0); 
	 # ^ add an extra block in case the region does not contain an even number of blocks

	# Compute n-1 blocks from compute_start,
	# keep track of individual block scores in @pre_blk_scores and their sum in $win_score
	my ($blk_start, $blk_end) = ($compute_start, $compute_start + $blk_size-1);
	my @pre_blk_scores = (0) x ($nr_blocks-1);
	my $win_score = 0;
	my $j = 0;   # $j = interval index
	for my $i (0..($nr_blocks-2)) {
	    my $blk_score = calc_block_score($blk_start, $blk_end, \$j, $ivs);
	    $win_score += $blk_score;
	    $pre_blk_scores[$i] = $blk_score;
	    $blk_start += $blk_size;
	    $blk_end += $blk_size;
	}

	# Compute the score for the first displayed window. This is the score for the win_nr_blocks first blocks.
	# We compute it as the score for the first n-1 blocks (already computed, in $win_score)
	# plus the score for the next win_nr_blocks - (n-1) blocks (the "core" region shared by all displayed windows)
	$blk_end += $blk_size * ($win_nr_blocks - $nr_blocks);
	$win_score += calc_block_score($blk_start, $blk_end, \$j, $ivs);
	push @scores, $ABS_SCORE ? $win_score : 100 * $win_score / $max_score;
	$blk_start += $blk_size * ($win_nr_blocks - $nr_blocks);
	$first_score_start = $blk_start - $offset;
	#die "first_score_start $first_score_start < display_start $display_start" unless($first_score_start >= $display_start);

	# Compute the scores for the remaining (n-1) displayed windows
	# Window 2 has score of window 1 - score of block 1 + score of the first block after the core region
	# Window 3 has score of window 2 - score of block 2 + score of the second block after the core region
	# etc

	# Debug checks
	#die "error: blk_start $blk_start != display_start $display_start + offset $offset"
	    #if($blk_start != $display_start + $offset);
#	print STDERR "blk_start $blk_start, display_start $display_start, offset $offset, blk_size $blk_size\n";
	die "error: blk_start $blk_start + $blk_size - 1 != $blk_end"
	    if($blk_start + $blk_size -1 != $blk_end);

	$blk_start += $blk_size;
	$blk_end += $blk_size;
	my $prev_win_score = $win_score;
	for my $i (0..($nr_blocks-2)) {
	    my $blk_score = calc_block_score($blk_start, $blk_end, \$j, $ivs);
	    $win_score = $prev_win_score + $blk_score - $pre_blk_scores[$i];
	    push @scores, $ABS_SCORE ? $win_score : 100 * $win_score / $max_score;
	    $prev_win_score = $win_score;
	    $blk_start += $blk_size;
	    $blk_end += $blk_size;
	}
    }
    else {

	# Compute number of blocks in the computed region.
	# This is the same as the number of windows scores we will compute.
	my $nr_blocks = int($compute_size / $blk_size) + ($compute_size % $blk_size ? 1 : 0); 
	 # ^ add an extra block in case the region does not contain an even number of blocks

	# Allocate at space for at least win_nr_blocks+1 blocks. This is needed to make sure
	# we don't go a full circle around the @blk_scores array when we find dead blocks below
	my @blk_scores = (0) x ($nr_blocks > $win_nr_blocks ? $nr_blocks : $win_nr_blocks + 1);

	my ($blk_start, $blk_end) = ($compute_start, $compute_start + $blk_size-1);
	my $prev_win_score = 0;
	my $j = 0;   # $j = interval index

	# Compute scores for all windows in the computed region.
	# The first windows (those outside the display) region will have incomplete scores
	# and will not be kept.
	for my $i (1..$nr_blocks) {  # $i = block index
	    my $blk_score = calc_block_score($blk_start, $blk_end, \$j, $ivs);
	    my $dead_block = $i - $win_nr_blocks;
	     # ^ the size of @blk_scores must be larger than $win_nr_blocks for this to work; see above
	    my $win_score = $prev_win_score + $blk_score - $blk_scores[$dead_block];
	    if($blk_start >= $display_start + $offset) {   
		$first_score_start = $blk_start - $offset unless(defined $first_score_start);
		push @scores, $ABS_SCORE ? $win_score : 100 * $win_score / $max_score;
	    }
	    $blk_scores[$i] = $blk_score;
	    $prev_win_score = $win_score;
	    $blk_start += $blk_size;
	    $blk_end += $blk_size;
	}
    }

    return ($first_score_start, \@scores);
}


sub calc_block_score
{
    my ($blk_start, $blk_end, $j_ref, $ivs) = @_;
    my $blk_score = 0;
    my $j = $$j_ref;
    for(;$j < @$ivs; $j++)
    {
	my ($iv_start, $iv_end) = @{$ivs->[$j]};
	last if($iv_start > $blk_end);
	if($iv_end >= $blk_start) {
	    my $ol_start = ($iv_start > $blk_start) ? $iv_start : $blk_start;
	    my $ol_end = ($iv_end < $blk_end) ? $iv_end : $blk_end;
	    $blk_score += $ol_end - $ol_start + 1;
	    last if($iv_end > $blk_end);
	}
    }
    $$j_ref = $j;
    return $blk_score;
}


1;
