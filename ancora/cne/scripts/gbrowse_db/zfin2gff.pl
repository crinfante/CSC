use warnings;
use strict;
use Class::Struct;
use AT::DB::GenomeAssemblyTwoBit;
use AT::Tools::RangeHandler;
use Getopt::Std;

my $SOURCE = "ZFIN";
my %args;
getopts('h',\%args);
my $ALLOW_HEADER_MISMATCH = $args{h};

my ($TWOBIT_FN, $ZFIN_FN) = @ARGV;

unless($ZFIN_FN) {

    my ($cmd) = $0 =~ /([^\\\/]+)$/;
    print STDERR <<EndOfUsage;
    
$cmd

Usage: 
    
$cmd [options] <2bit file> <ZFIN file>

Required arguments:

<2bit file>  Name of .2bit file for assembly
<ZFIN file>  Name of coordinate file from ZFIN (usually ZFIN_Coordinate.rpt)

The ZFIN file can be retreived from ftp://ftp.informatics.jax.org/pub/reports/index.html.
Make sure the coordinates in the file refer to the correct genome assembly.

Options:

-h   Proceed even if ZFIN file header does not match the expected

EndOfUsage

    exit;
}


struct Gene => [gene_id => '$',
		symbol => '$',
		chr => '$',
		start => '$',
		end => '$',
		strand => '$',
		];

my %genes;

# Check that the header is as expected
my $expected_header = join("\t",
    'ZFIN accession id', 'marker type', 'marker symbol', 'marker name', 'representative genome id', 
    'representative genome chromosome', 'representative genome start', 'representative genome end',
    'representative genome strand');
open IN, $ZFIN_FN or die "could not open $ZFIN_FN";
my $header = <IN>;
chomp $header;
if(substr($header,0,length($expected_header)) ne $expected_header) {
    print STDERR "Header does not match expected header.\n";
    print STDERR "Exp: $expected_header\n";
    print STDERR "Got: $header\n";
    exit unless($ALLOW_HEADER_MISMATCH);
}

# Get list of valid chromsomes from 2bit file
my $asm = AT::DB::GenomeAssemblyTwoBit->new(file => $TWOBIT_FN)
  or die "could not open assembly file $TWOBIT_FN";
my %valid_chr = map { $_ => 1 } $asm->get_chr_names;
my %skipped_chr;

# Read all genes & transcripts
print STDERR "Reading input file...\n";
my $nr_genes  = 0;  # just to have something to say at the end
my %total_gene_counts; # count nr of genes for each gene id
while(my $line  = <IN>) {

    # Parse line
    chomp $line;
    my ($gene_id, $type, $symbol, undef, undef, $chr, $gene_start, $gene_end, $strand) = split /\t/, $line;

    # Check that we have all fields we need
    next if($type ne 'Gene' or $symbol eq 'null' or $chr eq 'null' or
	    $gene_start eq 'null' or $gene_end eq 'null' or $strand eq 'null');

    # Change chr name to UCSC-style and check that it is valid
    $chr = 'M' if($chr eq 'MT');
    unless($valid_chr{"chr$chr"}) {
	$skipped_chr{$chr} = 1;
	next;
    }
    $chr = "chr$chr";

    # Create gene if we have not seen this gene before
    # In case genes in different locations (e.g. pseudoautosomal regions)
    # may have the same id, we handle these cases by indexing by chr and gene_start
    # (in the current file this is not a problem - each ZFIN is only occurs once)
    my $gene = $genes{$gene_id}{$chr}{$gene_start};
    unless($gene) {
	$gene = Gene->new(gene_id => $gene_id,
			  symbol => $symbol, 
			  chr => $chr,
			  start => $gene_start,
			  end => $gene_end,
			  strand => $strand);
	$genes{$gene_id}{$chr}{$gene_start} = $gene;
	$total_gene_counts{$gene_id}++;
	$nr_genes++;
    }

}
print STDERR "Read $nr_genes genes for ".scalar(keys %genes)." unique gene ids.\n";
print STDERR "Skipped genes on sequences: ".join(", ", keys %skipped_chr)." beacuse they are not in the 2bit file.\n"
  if(scalar keys %skipped_chr);


# Print genes and transcripts
foreach my $genes_by_chr (values %genes) {
    my $gene_count = 0;
    foreach my $genes_by_start (values %$genes_by_chr) {
	foreach my $gene (values %$genes_by_start) {
	    $gene_count++;
	    my $gene_id = $gene->gene_id;

	    # Make GFF group string for gene
	    my $gene_group = "Gene $gene_id ; Note \"ZFIN Gene\"";
	    $gene_group .= ' ; Alias "'.$gene->symbol.'"' if($gene->symbol);

	    # Print gene as GFF
	    print join("\t", $gene->chr, $SOURCE, 'gene', $gene->start, $gene->end, '.', $gene->strand, '.', $gene_group), "\n";

	}
    }
}

print STDERR "Done.\n";


