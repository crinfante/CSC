#!/usr/bin/perl
# This script was written by Par Engstrom, BCCS, University of Bergen, Norway 
# in November 2006.
use warnings;
use strict;

sub usage
{
    my ($cmd) = $0 =~ /([^\\\/]+)$/;
    print STDERR <<EndOfUsage;
    
$cmd 

Function: filter chains to retain those supported by reciprocal nets.
	
Usage: perl $cmd asm1.asm2.all.chain asm1.sizes asm2.sizes
    
Input files:
- The chain file should contain all chains between the two assemblies.
  Appropriate chain files can be found at at genome.ucsc.edu.
- The size files should be text files with sequence sizes as
  generated by twoBitInfo.

The script will generate the following output files:
asm1.asm2.net               (one-way nets)
asm2.asm1.net               (one-way nets)
asm1.asm2.recip-over.chain  (chains for reciprocal nets)
asm2.asm1.recip-over.chain  (chains for reciprocal nets)

The following programs are used and must be in the command path:
chainSwap, chainNet, netChainSubsetRelaxed and chainStitchId.

EndOfUsage
exit;
}


my ($all_chain_fn, $size_fn1, $size_fn2) = @ARGV;
usage() unless($all_chain_fn and $size_fn1 and $size_fn2);
die "File $all_chain_fn does not exist\n" unless(-f $all_chain_fn);
die "File $size_fn1 does not exist\n" unless(-f $size_fn1);
die "File $size_fn2 does not exist\n" unless(-f $size_fn2);
my ($asm1, $asm2) = $all_chain_fn =~ /(\w+)\.(\w+)\.all\.chain$/;
usage() unless($asm2 and $asm2);

print STDERR "ASSEMBLIES: $asm1, $asm2\n\n";

my $net_fn1 = "$asm1.$asm2.net";
my $net_fn2 = "$asm2.$asm1.net";
my $recip_fn1 = "$asm1.$asm2.recip-over.chain";
my $recip_fn2 = "$asm2.$asm1.recip-over.chain";

print STDERR "GENERATING NETS FOR $asm1...\n";
execute('chainNet', '-minSpace=1', $all_chain_fn, $size_fn1, $size_fn2, $net_fn1, '/dev/null');
print STDERR "\n";

print STDERR "GENERATING NETS FOR $asm2...\n";
execute("chainSwap $all_chain_fn /dev/stdout | ".
	"chainNet -minSpace=1 /dev/stdin $size_fn2 $size_fn1 $net_fn2 /dev/null");
print STDERR "\n";

print STDERR "FILTERING CHAINS WITH NETS...\n";
execute("netChainSubsetRelaxed $net_fn1 $all_chain_fn /dev/stdout | ".
	"chainStitchId /dev/stdin /dev/stdout | ".
	"chainSwap /dev/stdin /dev/stdout | ".
	"netChainSubsetRelaxed $net_fn2 /dev/stdin /dev/stdout |".
	"chainStitchId /dev/stdin $recip_fn2");
execute("chainSwap $recip_fn2 $recip_fn1");
print STDERR "\n";

print STDERR "DONE!\n";

sub execute
{
    system(@_) == 0 or die "Failed to execute command:\n@_\n";  
}
