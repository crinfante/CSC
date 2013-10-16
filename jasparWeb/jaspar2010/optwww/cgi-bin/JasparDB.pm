package JasparDB;
use strict;

# temorary fix
#use lib "/home/albin/perl_libs/lib/";
#use lib "/home/albin/DEVEL/TFBS/";
use lib  "/opt/www/jaspar_2010/";
use lib  "/opt/www/jaspar_2010/TFBS";
#use lib "/home/eivind/public_html/";
#use lib "/home/albin/perl_libs/";
#use lib "/home/albin/perl_libs/TFBS";
#use lib "/home/eivind/public_html";
#use lib "/home/eivind/public_html/TFBS";#


use TFBS::Matrix::PFM;
use TFBS::Matrix::PWM;
use TFBS::Matrix::ICM;
use TFBS::MatrixSet;
#use TFBS::Matrix::Alignment;



#use TFBS::DB::JASPAR4;
use TFBS::DB::JASPAR5;

use CGI::Carp qw(carpout); #fatalstobrowser);
#use CGI::Application::Plugin::Redirect;
use Set::Scalar;
use Bio::SeqIO;

use WEBSERVER_OPT;

use constant POPUP_HEIGHT => 520;
use constant POPUP_WIDTH => 700;
use constant POPUP_WIDTH_INC => 40;

use constant REVERSE => 0;
use constant FORWARD => 1;

use constant COMMON_SCRIPT => TEMPLATES_URL."functions.js";
use constant SORT_SCRIPT => TEMPLATES_URL."sortable.js";
use constant STYLE_SHEET => TEMPLATES_URL."style.css";


warn ERROR;
# error dump file: useful for debugging. Will give the wole html call , params etc
open (ERROR_LOG, ">".ERROR)||die;;
carpout(*ERROR_LOG);


use base 'CGI::Application';
use HTML::Template;

# 
use InitDB;
my ($db_info)=InitDB->init;
warn ref ($db_info);
my $dbh= $db_info->jaspar5->dbh;
my $get_species= $dbh->prepare(qq!SELECT SPECIES FROM TAX WHERE TAX_ID=?  !);
my $get_species_id= $dbh->prepare(qq!SELECT TAX_ID FROM TAX WHERE SPECIES=?  !);

 #the db collection, the collections, descriptions for collections
# note that all subdbs are within the same database


########################
# setup: internal method used by CGI:APPLICTAION to see what runmode (= sub routine) that will be used
# ther are som aliases, due to that HTML forms suck
########################

sub setup {
    my $self = shift;

    print STDERR "INC: @INC\n";
    print STDERR $self->dump(); 
    $self->start_mode('start');
    $self->mode_param('rm');
    $self->run_modes(
		     'start' => 'start',
		     'list' => 'showlist',
		     'SCAN' => 'analyze',
		     'browse'=> 'browse',
		     'Show me all versions'=> "browse",
		     "Browse the JASPAR_CORE database right away!"=>"browse",
		     "Browse" =>"browse",
		     "struct_browse"=>"struct_browse",
		     'select'=>'select',
		     "Search"=>"select",
		     'download' => 'download', 
		     'present'=>'present',
		     'export'=>'export',
		     'Go'=>'export',
		     'upload'=>'upload',
		     "Align"=>"compare",
		     'compare'=>'compare', 	
		     "submission"=>"submit",
		     'Make a SVG logo'=>'export_svg',
		     'Reverse complement'=>'present',
		     'CLUSTER'=>'cluster',
		     'RANDOMIZE'=>'random',
		     'PERMUTE'=>'permute',
		     'showsites'=>'showsites'
	);
  }
  
  ########################
# submit: the most underused function, ever. A user can give Albin a tip of a paper to include. Never, ever used by real people...
# not tested yet
########################

  
sub submit{
    use Mail::Mailer;
    my $self = shift;
    warn  ref $self;
    my $q= $self->query();
    warn ref $q;
    #if input, deposit in file system and send email
    if ($q->param("jaspar_core")){
	# save files
	my $string = $q->param("core_submission");
	my $rand= int rand(50000);
	my $file =SUBMISSION_DIRECTORY."$rand.jaspar_core";
	open (OUT, ">$file") ||die;	  
	print  OUT $string;
	close OUT;
	warn $string;

#	notify albin
	my $sendmail = "/usr/sbin/sendmail -t";
	my $mailer = Mail::Mailer->new();
	$mailer->open({From=> "root\@phylofoot.net", To=>"sandelin\@gsc.riken.jp", Subject=> "new jaspar CORE entry at $file"})
	or die "cannot open";
	print $mailer "$string";
	$mailer->close;
	# print message at screen
	return "Dear contributor: We thank you for your suggestion for a JASPAR CORE entry.<p>We will contact you shortly.<p><p>Best Regards, <p>the JASPAR DATBASE team.";

	
    } elsif ($q->param("dataset")){
	my $string = $q->param("data_desc"); 
	my $rand= int rand(50000);
	my $file =SUBMISSION_DIRECTORY."$rand.data_desc  ";
	my $file2=SUBMISSION_DIRECTORY."$rand.data  ";
	open (OUT, ">$file") ||die;	  
	print  OUT $string;
	close OUT;
	$file2.= "_".$q->param("datafile");
	$file2=~s/\s+//;
	open (OUT, ">$file2") ||die;	  
	my $f =  $q->param("datafile");
	while (<$f>){
	    print OUT  $_;
	
	}

	close OUT;
	
	#	notify albin
	my $sendmail = "/usr/sbin/sendmail -t";
	my $mailer =Mail::Mailer->new();
	$mailer->open({From=> "root\@phylofoot.net", To=>"sandelin\@gsc.riken.jp", Subject=> "new jaspar CORE entry at $file"})
	or die "cannot open";
	print $mailer "$string\n $file\n$file2";
	$mailer->close;
	# print message at screen
	
#	warn $string;
	return "Dear contributor: We thank you for your suggestion for a JASPAR dataset.<p>We will contact you shortly.<p><p>Best Regards, <p>the JASPAR DATBASE team.";
	
    } else{
	# otherwise, just give message

	my $template= HTML::Template->new(filename => TEMPLATES.'/submission.html',, die_on_bad_params=>0); 
	$template->param(IMAGE_DIR => "");
	$template->param(ACTION => ACTION);
	return  $template->output();
    }

}



########################
#start: Draws the initial welcome page
# Much trickier than before, beacuse the number of databases etc are not hard-coded: are read in first.
# also, interaction with even uglier javascripts
########################


sub start {
    #this shows the first web page
    my $self = shift;
    #my $template= HTML::Template->new(filename => TEMPLATES.'/start_template.template', die_on_bad_params=>0);
    #my $template= HTML::Template->new(filename => TEMPLATES.'/start_template.template', die_on_bad_params=>0);

    


    my $template= HTML::Template->new(filename => TEMPLATES.'/jaspar_db.htm', die_on_bad_params=>0);
    $template->param(STYLE => STYLE_SHEET);

    print STDERR $self->dump(); 

    # read in version info and links to display
    use InitVersion;
   
    my %version_hash= %{InitVersion->init()};
   
 require Data::Dumper;
    warn Data::Dumper->Dump([%version_hash]);
 warn Data::Dumper->Dump([$version_hash{VERSION}]);
   $template->param(VERSION => $version_hash{"VERSION"});
    $template->param(THIS_SERVER_MESSAGE => $version_hash{"THIS_SERVER_MESSAGE"});
    $template->param(OTHER_SERVER_MESSAGE => $version_hash{"OTHER_SERVER_MESSAGE"});
# fill in the used databases
    my @db_loop_data;
    my $i=0;
    # need to pre-select the first, and make it CORE
    
    my %d;
    $d{DB_INDEX}= 0;
    $d{DB_SHOW_NAME}=  "JASPAR CORE";
    $d{DB_PRESELECT} =0;
    $d{DB_PRESELECT}= 1;
    push (@db_loop_data,\%d );
    $i++;



    # get the current collections
    foreach my $collection (sort $db_info->collections){
	next if $collection eq "CORE";
	my %d;
	$d{DB_INDEX}= $i;
	$d{DB_SHOW_NAME}=  "JASPAR $collection";
	$d{DB_PRESELECT} =0;
#	$d{DB_PRESELECT}= 1 if  $i ==0; #to preselect the first
	push (@db_loop_data,\%d );
	$i++;

    }
    $template->param(BROWSE_DBS => \@db_loop_data);
    # fill in descriptions
    my @desc_loop_data;
    $i=0;
    #my %d;
    $d{DB_INDEX}=0;
   # $d{DB_FOR_BROWSE}="CORE";

    my $desc= $db_info->description("CORE"); 
    $d{DESCRIPTION}= "\"". $desc. "\"";
    push (@desc_loop_data,\%d );
    $i++;
    
    
    foreach my $collection (sort $db_info->collections){
	next if $collection eq "CORE";
	my %d;
	$d{DB_INDEX}= $i;

#	$d{DB_FOR_BROWSE}= $collection;
	my $desc= $db_info->description($collection); 
	$d{DESCRIPTION}= "\"". $desc. "\"";
	push (@desc_loop_data,\%d );
	$i++;

    }
    $template->param(DB_DESCS => \@desc_loop_data);


    $template->param(ACTION => ACTION);#'http://localhost/cgi-bin/JASPAR_DB/jaspar_db.pl');
    $template->param(IMAGE_DIR => HTML_BASE_URL."TEMPLATES/"); 
    $template->param(DOWNLOAD => HTML_BASE_URL."DOWNLOAD/"); 
       
    $template->param(HELP => HTML_BASE_URL."TEMPLATES/help.html");
     # $template->param(CONTACT => HTML_BASE_URL."contact.htm");
  

    return $template->output();
      
}


sub help{
	# not done yet: gives a pop-up with he - arhument is the anchor name
	
	
}

sub showlist{ # does this do anything?
   my $self = shift;
   my $q= $self->query();
   my $db; # just for now
  my $sth=$db->dbh->prepare(qq{SELECT * FROM MATRIX_INFO });
 # $sth->execute();
 #warn  $sth->dump_results(); 
   
   if($q->param("Submit")){;
   my $template= HTML::Template->new(filename => TEMPLATES.'/list3.htm',, die_on_bad_params=>0); 
   $template->param(IMAGE_DIR => TEMPLATES);
   return $template->output();
       }
}

########################
# analyze: from the browse page (or select, whatever)
# user can pick a few matrices and put in a sequence to scan the 
# and will get a small image with atble of hits, ala consite
# really does not work at the moment - not even looked at it
######################



sub analyze {
    # remade: just makes a table of predicted sites
    
    # not fixed for dynamic db reading
    my $self = shift;
    my $q= $self->query();
    #figure out what database to use: REMAKE
    
 my $work_db= $db_info->jaspar5;
    my $collection;
    unless ($collection) { #  hacky thing to make the javascript work in the previous page - db can also be expressed as an integer
	my $db_index=   $q->param("db_for_browse");
	my @cols;
	$cols[0]="CORE";
	my $i=1;
	foreach my $c(sort $db_info->collections){
	    next if $c eq "CORE";
	    $cols[$i]=$c;
	    $i++;
	}
	$collection=$cols[$db_index];
	warn "collection is now $collection";
	
	
    }
    



   
    my $seqstring= $q->param('seq')|| return $self->error("No valid sequence provided");


    unless ($seqstring=~/^>/){
	return $self->error("You are submitting a sequence that is not fasta-formated<p>Fasta format looks like this:<p>>sequence name<p>AGAAAAAAAGCTAGCGAGCTAGCTGATCGTAGCTAGCTGATCGATGCTAGCTATGCTCAGCGAT<P>ACGTAGCTAGCTAGTCGAT<P>...etc<p>");
    }

    if  (length($seqstring) > 20000){
	return $self->error("You are submitting a sequence longer than 20000 nucleotides. This is beyond the scope of the database. Try out <a href= http://phylofoot.org/consite>ConSite</a>");
    } 
    
    $seqstring=~ s/\r\n/\n/g;
    
     my $file = TEMP_DIR."seq.$$";
     warn $file;
     open (SEQ, ">".$file)|| die;
     print SEQ $seqstring;    
     close SEQ;
     $seqstring=~ s/\r\n/\n/g;
    
    warn   $seqstring;
    # my $seq1= Bio::Seq->new( -seq=>$seqstring, -ID=>"submitted sequence")|| return $self->error("No valid sequence provided");
    
    my $seqstream=Bio::SeqIO->new(-file=> $file,);
    # my $seq1 = ($seqstream->next_seq());
    
    my $seq1 = $seqstream->next_seq();
    
    warn "length ",  $seq1->length();
    
#  $seq1=~ s/[\n\r\s]//g;
    #ID set
    
    my $ID_set=$q->param('ID');
    warn  "single: $ID_set";
    
    my @ID_set= $q->param('ID');
    return $self->error("No profiles selected") unless  @ID_set;
    
    foreach (@ID_set){
	warn "id $_ stop\n";
    }
    
    #warn join("\t" , @ID_set);
    
    
    #cutoff
    
    my $threshold= $q->param('cutoff')."%"|| "80%";
    
    my $set= $work_db->get_MatrixSet( -ID=> [@ID_set],
				 -matrixtype=>'PWM');
    
    my $matrixset_iterator = $set->Iterator(-sort_by =>'name');
    
    while (my $p= $matrixset_iterator->next()){	
	warn  $p->name();

	
    }
     
    # do the stuff
     
     my $siteset = $set->search_seq(-seqobj=>$seq1,
				    -threshold => $threshold);
     
     my $it=  $siteset->Iterator(-sort_by=>"start");
     my $template= HTML::Template->new(filename => TEMPLATES.'/site_table.htm', die_on_bad_params=>0);
     my @loop_data;
 
     my $string='';
     my $sites=0;
     while (my $site=$it->next()){
	 warn $site->score();
	 my %row_data;
	 $sites++;
	 $row_data{'ID'} = $site->pattern->ID();
	 $row_data{'NAME'} = $site->pattern->name();
	 $row_data{'SCORE'} = $site->score;
	 $row_data{'REL_SCORE'} = $site->rel_score;
	 $row_data{'START'} = $site->start;
	 $row_data{'END'} = $site->end;
	 
	 $row_data{'STRAND'} = $site->strand;
	 	 $row_data{'SEQ'} = $site->seq->seq;


	 push(@loop_data, \%row_data);
     }

     $template->param(SITES=> \@loop_data);
     $template->param(SITECOUNT=> $sites);
     
     $template->param(THRESHOLD=> $threshold);
     $template->param(SEQNAME=> $seq1->display_id);


     return ($template->output);

    
}


########################
# download: not sure if this is used anymore. Need to check
# certainly does not work now

sub download {    
    # will have to be redone due to dynamic db
    # is it actually used?
    my $db; # just for now
    my $self = shift;
    #try dumping all matrices as text
    
    my $sth=$db->dbh->prepare(qq{SELECT * FROM MATRIX_INFO });
    # $sth->execute();
    warn  $sth->dump_results();
}

########################
# browse: the most used function: shows all matrices in the database
# works by reading BROWSE_KEYS for the relevant database, and shows those
# Ugly, but does work when tested. However, draws all logos each time (waste of cpu time)
########################



sub browse {
    # this is typically used to either browse a whole db, or in the case of core, a tax_group part of a db

   my $self= shift;
    my %translate=(
                   'ID'=>'ID',
                   'Species'=>'species',
                   'Class'=>'class', 
                   'Name'=>'name',
                   'Taxonomic group'=>'tax_group'
		  
		   
		   );
                 
  
    my $q = $self->query();
    #param db for browse is now an integer: this comes from the array of databases - so, from this we select db

   # depending on what database, we will have a set of key-value 
   # pairs that will be shipped to the browser: this should be 
   # implemented in the template also
   
   

  
  
  
   my $j5= $db_info->jaspar5; # should be  just one database here - maybe remake the initdb stuff altogether? 

   #
   my $collection = uc($q->param("db"));


   unless ($collection) { #  hacky thing to make the javascript work in the previous page - db can also be expressed as an integer
       my $db_index=   $q->param("db_for_browse");
       my @cols;
       $cols[0]="CORE";
       my $i=1;
       foreach my $c(sort $db_info->collections){
	   next if $c eq "CORE";
	   $cols[$i]=$c;
	   $i++;
       }
       $collection=$cols[$db_index];
       warn "collection is now $collection";

       
   }
   

# whole db or a subpart based on taxgroup, or "give all versions"?


   my $selected; # the matrices
 


   if ( $q->param("tax_group") && $collection eq "CORE"){
       # tranlate frm latin to pseudo-english
       my %tr=();



       $selected = $j5->get_MatrixSet(-collection=>$collection , -tax_group=> $q->param("tax_group") );
 

   }
   elsif( $q->param("base_id")  ){
              $selected = $j5->get_MatrixSet( -ID=> [$q->param("base_id")],  -all_versions=>1 );
	     


   }
   else{


       $selected = $j5->get_MatrixSet(-collection=>$collection);
       
   }   

   my $matrixset_iterator = $selected->Iterator(-sort_by => $translate{$q->param("BROWSE_BY") } );
                  

    my $template= HTML::Template->new(filename => TEMPLATES.'/generic_browse_template.template', die_on_bad_params=>0);# if  $q->param("db_for_browse") eq  "CORE";
   $template->param(STYLE => STYLE_SHEET);
   $template->param(SORT_SCRIPT => SORT_SCRIPT);
   $template->param(COMMON_SCRIPT => COMMON_SCRIPT);

    #the goal is to fill in a very dynamic table from the keys and values specified in he initdb line in the begining
    # first,a loop is used to fill in the coumns (one item per coumn
    # then a nested loop is use to fill in every matrix row, and an inner loop for each value of te matrix
    # each such row always starts with the selector, the ID and ends with the logo and the view button
    my @column_loop_data; # simple loop data: an array of hashes (with just one key)
    my @matrix_loop_data; # nested loop data:  : an array of hashes , where one item actually is the next loop (another array of hashes)

    # first define the column loop
   #REDO DB selection here
   

   foreach my $key ( @{$db_info->browse_keys($collection)}){

	my %rowhash;
	$rowhash{KEY}=$key;
	push ( @column_loop_data,  \%rowhash);

    }
    
 	$template->param(BROWSE_COLUMNS => \@column_loop_data);

	#the matrix loop
    while (my $pfm = $matrixset_iterator->next) {
	# do whatever you want with individual matrix objects 
	warn $pfm->ID;	
	my %row_data;  # get a fresh hash for the row data

	# draw the logo: speedup: if file already exist, don't redraw
	my $file_name= TEMP_DIR."/".$pfm->ID().".png";
	unless (-e $file_name){ 
	    # draw from scracth			
            draw_new_logo(-pfm=>$pfm, -size=>"small", -direction=>"F", -file_name=>$file_name); # other options: 
	}
	
	# fill in this row
	$row_data{'ID'} = $pfm->ID();
	$row_data{'LOGO'} = TEMP_URL.$pfm->ID().".png";
	$row_data{'ACTION'} = ACTION.'?ID='.$pfm->ID().'&rm=present&collection='.$collection;
	$row_data{'HEIGHT'} = POPUP_HEIGHT;


	# Length doesn't differ for matrices smaller than 10
	my $len = ($pfm->length() - 10);
	$len = ($len < 0 ? 0 : $len);

	$row_data{'WIDTH'} = POPUP_WIDTH + $len * POPUP_WIDTH_INC;
	$row_data{'IMAGE_DIR'} =HTML_BASE_URL."TEMPLATES/";
	# fill in actual values (another loop)
	my @second_loop;
	foreach my $key2 ( @{$db_info->browse_keys($collection)}){


	    my %rowhash2;
	    warn  "here $key2";
	    # handle the fact that some keys are only gooten by tag(name)
	    # and some have actual methods
	    # pfms have methods for ID, name and class
	    my $val= '';
	    $val = $pfm->class if ($key2 eq "class");
	    $val = $pfm->name if ($key2 eq "name");
	    $val= $self->_species_list($pfm) if  ($key2 eq "species");
	    # otherwise use the "tagged" value
	    
	    unless ($val){	    
# is it an array?
		
		
		if ( ref $pfm->tag($key2) eq "ARRAY"){
		    $val= join(",",  @{$pfm->tag($key2)});
		}
		else{
		    
		    $val = $pfm->tag($key2);
		}
	    }
		$rowhash2{VAL}=$val;
	    # here, get the actual values. For now, just use the key

	    push ( @second_loop,  \%rowhash2);
	    
	}
	$row_data{'VALUES'}= \@second_loop, 


	
     push(@matrix_loop_data, \%row_data);

   }

    
 require Data::Dumper;
    warn Data::Dumper->Dump([\@matrix_loop_data]);

   $template->param(ACTION => ACTION);#'http://localhost/cgi-bin/JASPAR_DB/jaspar_db.pl');
   $template->param(SMALL_MATRIX => \@matrix_loop_data);
   $template->param(DB=> $q->param("db_for_browse"));
   $template->param(IMAGE_DIR => TEMPLATES);
   $template->param(HELP => HTML_BASE_URL."TEMPLATES/help.html"), 
    
   return $template->output();
    
}
####
# run mode to dynamically fill in a html page with all structure classes
#
# clocik on a link and you will get to the browse/select page
#
sub struct_browse{

    # this is typically used to either browse a whole db, or in the case of core, a tax_group part of a db

   my $self= shift;
    my %translate=(
                   'ID'=>'ID',
                   'Species'=>'species',
                   'Class'=>'class', 
                   'Name'=>'name',
                   'Taxonomic group'=>'tax_group'
		  
		   
		   );
                 
  
    my $q = $self->query();
    #param db for browse is now an integer: this comes from the array of databases - so, from this we select db

   # depending on what database, we will have a set of key-value 
   # pairs that will be shipped to the browser: this should be 
   # implemented in the template also
   
   

  
  
  
   my $j5= $db_info->jaspar5; # should be  just one database here - maybe remake the initdb stuff altogether? 

   #
   my $collection = "CORE"; # only will work with CORE

   # walk thru the web page to dinf names - and then seacrh for the IDs in question. REALLY iffy. Should be a database in the first place

   




   # make links
    my $template= HTML::Template->new(filename => TEMPLATES.'/TF_classifications2.html', die_on_bad_params=>0);# if  $q->param("db_for_browse") eq  "CORE";
   
   $template->param(ACTION => ACTION);#
   return $template->output();




}


####
#
#  draw_new_logo : draws a specified logo given a pfm at a given location. can be small, large or revcomp
#

sub draw_new_logo{
    my (%args)= @_;
    my $pfm = $args{-pfm};
    my $file_name= $args{-file_name};
    my $size= $args{-size};
    my ($xsize, $ysize);
    
    # size is a multiple of width, plus a static x axis space	
    if ( $size eq "small"){
	#$xsize=$pfm->length*13 + 20;
	$ysize=80;
	$xsize=200;
    } elsif ( $size eq "big") {
	$xsize = $pfm->length() * 40;
	$ysize = 200;
    }

    my $svg = $args{-svg}||0;
    my $direction= $args{-direction};
    # if direction is R, reverse pfm (not inplemented)
    
    
    my $icm = $pfm->to_ICM;
    warn $file_name;
    my $image= $icm->draw_logo(
			       -file =>  $file_name,
			       -xsize=> $xsize,  
			       -ysize=> $ysize,
			       );
	
	
}

########################
# select: Same as browse(), but the user has selected a set of names, IDs or whatnot
# and only matrices that fulfil criteria are shown
# very hacky, but does work when tested
########################



sub select{
    my $self = shift;
    my $q= $self->query();
    my %translate=(
		   ID=>'-ID', 
		   Name=>'-name',
		   Type=>'-type',
		   Species=>'-species',
		   Class=>'-class', 
		   );
 
 
 
    my $s= $q->param("db_for_browse");
    warn $s;
    $s = $q->param("db_for_search") unless  $s;
    warn $s;
   
    my $db= $db_info->jaspar5; # should be  just one database here - maybe remake the initdb stuff altogether? 

   #
   my $collection = uc($q->param("db"));


   unless ($collection) { #  hacky thing to make the javascript work in the previous page - db can also be expressed as an integer
       my $db_index=   $q->param("db_for_browse");
       my @cols;
       $cols[0]="CORE";
       my $i=1;
       foreach my $c(sort $db_info->collections){
	   next if $c eq "CORE";
	   $cols[$i]=$c;
	   $i++;
       }
       $collection=$cols[$db_index];
       warn "collection is now $collection";

      
   }


  
  
    #make three database searches if necessary
    # perfom boolean opertaions on those depending on 'OR', AND, NOT
    unless( $q->param('selectfield1')){ # error check
        
        return $self->error("You have not selected any properties to search for");
	
    }
    # first search
    my @result_set;
    #my $r;
   
    # hacky conversion of species to species ID
    my $input1= join (" ", $q->param('selectfield1') );
  
    if ($q->param('select1') eq "Species"){
	$input1=_species_id($input1);
    }

   
    my @first= @{$db->_get_IDlist_by_query(
					 eval($translate{ $q->param('select1')})=>[$input1], 
					 );
	     };

    foreach ( @first){
	warn ref $_;
	
    }

    my $r= Set::Scalar->new(@first); 
    @result_set= $r->elements();
    warn "\n\nresulting set:\n";
    foreach my $item( @result_set){
        warn  $item;
    }
    
    
    if ($q->param('selectfield2')){
	my @query = split(/\,\s?/, $q->param('selectfield2') );
	 my $input2= join (" ", @query );
  
	if ($q->param('select2') eq "Species"){
	    $input2=_species_id($input2);
	}


        my @second= @{$db->_get_IDlist_by_query(
					      eval($translate{ $q->param('select2')})=>[$input2], 
						);};
	warn "second set\n";
        
        foreach my $item( @second){
	    warn $item;
	}
	my $second = Set::Scalar->new(@second);
        if ($q->param('boolean1') eq "AND"){
            $r= $r->intersection($second);
        }
        elsif($q->param('boolean1') eq "OR"){
            $r= $r->union($second);
        }
        elsif($q->param('boolean1') eq "NOT"){
	    $r= $r->difference($second); 
        }
    }
    
    warn "\n\nresulting set:\n";
    foreach my $item( @result_set){
        warn $item;
    }
    if ($q->param('selectfield3')){
	my @query = split(/\,\s?/, $q->param('selectfield3') );
	 my $input3= join (" ", @query );
  
	if ($q->param('select3') eq "Species"){
	    $input3=_species_id($input3);
	}
        my @third= @{$db->_get_IDlist_by_query(
					     eval($translate{ $q->param('select3')})=>[$input3], 
					       );};
	warn "third set\n";
        
        foreach my $item( @third){
	    warn $item;
	}
	my $third = Set::Scalar->new(@third);
        if ($q->param('boolean2') eq "AND"){
            $r= $r->intersection($third);
	    
        }
        elsif($q->param('boolean2') eq "OR"){
            $r= $r->union($third);
        }
        elsif($q->param('boolean2') eq "NOT"){
	    $r= $r->difference($third); 
        }
    }
    
    
# boolean operations
    
    @result_set= $r->elements();
    warn "resulting set:\n";
    foreach my $item( @result_set){
        warn $item;
    }
    
    
    
    
    
    if  ($r->is_empty()){
	return ($self->error('no profiles in JASPAR satisfies search criteria'));
    }
    
    
    #get set of matrix objects
    my $selected=  TFBS::MatrixSet->new();
    foreach my $int_id( @result_set){
	$selected->add_matrix(	$db->_get_Matrix_by_int_id($int_id) );
    }


  #  my $selected=$db->get_MatrixSet(-ID =>[@result_set]);
    my $matrixset_iterator = $selected->Iterator(-sort_by =>'ID');
    
    # draw page (identical to browse)
    
    my $template= HTML::Template->new(filename => TEMPLATES.'/generic_browse_template.template', die_on_bad_params=>0);# if  $q->param("db_for_browse") eq  "CORE";
    $template->param(STYLE => STYLE_SHEET);
    $template->param(SORT_SCRIPT => SORT_SCRIPT);
    $template->param(COMMON_SCRIPT => COMMON_SCRIPT);
    
    #the goal is to fill in a very dynamic table from the keys and values specified in he initdb line in the begining
    # first,a loop is used to fill in the coumns (one item per coumn
    # then a nested loop is used to fill in every matrix row, and an inner loop for each value of te matrix
    # each such row always starts with the selector, the ID and ends with the logo and the view button
    my @column_loop_data; # simple loop data: an array of hashes (with just one key)
    my @matrix_loop_data; # nested loop data:  : an array of hashes , where one item actually is the next loop (another array of hashes)
    # first define the column loop
    
    foreach my $key ( @{$db_info->browse_keys($collection)}){

	my %rowhash;
	$rowhash{KEY}=$key;
	push ( @column_loop_data,  \%rowhash);
	
    }
    
    $template->param(BROWSE_COLUMNS => \@column_loop_data);
    
    #the matrix loop
    while (my $pfm = $matrixset_iterator->next) {
	# do whatever you want with individual matrix objects 
	warn $pfm->ID;	
	my %row_data;  # get a fresh hash for the row data

	# draw the logo: speedup: if file already exist, don't redraw
	my $file_name= TEMP_DIR."/".$pfm->ID().".png";
	unless (-e $file_name){ 
	    # draw from scracth			
            draw_new_logo(-pfm=>$pfm, -size=>"small", -direction=>"F", -file_name=>$file_name); # other options: 
	}
	
	# fill in this row
	$row_data{'ID'} = $pfm->ID();
	$row_data{'LOGO'} = TEMP_URL.$pfm->ID().".png";
	$row_data{'ACTION'} = ACTION.'?ID='.$pfm->ID().'&rm=present&collection='.$collection;
	$row_data{'HEIGHT'} = POPUP_HEIGHT;
	
	
	# Length doesn't differ for matrices smaller than 10
	my $len = ($pfm->length() - 10);
	$len = ($len < 0 ? 0 : $len);
	
	$row_data{'WIDTH'} = POPUP_WIDTH + $len * POPUP_WIDTH_INC;
	$row_data{'IMAGE_DIR'} =HTML_BASE_URL."TEMPLATES/";
	# fill in actual values (another loop)
	my @second_loop;
	foreach my $key2 ( @{$db_info->browse_keys($collection)}){


	    my %rowhash2;
	    warn $key2;
	    # handle the fact that some keys are only gooten by tag(name)
	    # and some have actual methods
	    # pfms have methods for ID, name and class
	    my $val= '';
	    $val = $pfm->class if ($key2 eq "class");
	    $val = $pfm->name if ($key2 eq "name");
	    $val= $self->_species_list($pfm) if  ($key2 eq "species");

	    # otherwise use the "tagged" value
	    unless ($val){	    
# is it an array?
		
		if ( ref $pfm->tag($key2) eq "ARRAY"){
		    $val= join(",",  @{$pfm->tag($key2)});
		}
		else{
		    
		    $val = $pfm->tag($key2);
		}
	    }
	    $rowhash2{VAL}=$val;
	    # here, get the actual values. For now, just use the key
	    
	    push ( @second_loop,  \%rowhash2);
	    
	}
	$row_data{'VALUES'}= \@second_loop, 
	
	
	
	push(@matrix_loop_data, \%row_data);
	
    }
    
    
    require Data::Dumper;
    warn Data::Dumper->Dump([\@matrix_loop_data]);
    
    $template->param(ACTION => ACTION);#'http://localhost/cgi-bin/JASPAR_DB/jaspar_db.pl');
    $template->param(SMALL_MATRIX => \@matrix_loop_data);
    $template->param(DB=> $q->param("db_for_browse"));
    $template->param(IMAGE_DIR => TEMPLATES);
    $template->param(HELP => HTML_BASE_URL."TEMPLATES/help.html"), 
    
    return $template->output();
    



    
    
    
    
    
}

########################
# error: a custom error message is hwon when suer messes up (bad input etc)
########################


sub error{
    my ($self, $error)= @_;
    warn $error;
    my $q=$self->query();
    my $out=( $q->start_html());
    $out.=$q->p($error);
    return  $out;
}


########################
# export: gives a zipped Flatfile dir with selected matrices
# not sure how often this is used...
# does not work yet

sub export{
    use TFBS::DB::FlatFileDir;
    
    # also have to be redone due to dynamic locading of DBs
    # now nonfunctinoal
    # not really sure if this function is ever used
    
    my ($self)= @_;
   
    my $q=$self->query();
    my @IDs= $q->param('ID');
    
    return $self->error("No profiles selected") unless (@IDs) ;
    if ($q->param('export_as') eq 'IDs'){
        my $out='<html><pre>';      
      foreach (@IDs){
        $out.="$_\t";
      }
        $out.='</pre></html>';
        return $out;
    }
    # else: flatfile
    # get all ids
    # save themin some work trash dir
    
    system ("rm -r ".TEMP_DIR."/MatrixDir");
    system ("rm  ".TEMP_DIR."/MatrixDir.zip");
    my $flatfile_db = TFBS::DB::FlatFileDir->create(TEMP_DIR."/MatrixDir"); 
   
   my $db; # just for now
   
    #$db=$phylofacts_db if $q->param("db_for_search") eq "PHYLOFACTS";
    #$db=$core_db if $q->param("db_for_search") eq  "CORE";
    #$db=$familial_db if $q->param("db_for_search") eq  "FAM";
    my $matrixset = $db->get_MatrixSet(
                                    -ID=>[@IDs] 
                            );

    

    my $matrix_iterator = 
                   $matrixset->Iterator(-sort_by =>'name');
           while (my $matrix_object = $matrix_iterator->next) {
               
               
               $flatfile_db->store_Matrix($matrix_object);
              # print $matrix_object->name(), "\n";
               # do whatever you want with individual matrix objects
           }
    warn "zip -rj  ".TEMP_DIR . "MatrixDir.zip ". TEMP_DIR. "MatrixDir";
      system ("zip -rj ".TEMP_DIR . "MatrixDir.zip ". TEMP_DIR. "MatrixDir");     
           

#my $out='<html><head><meta NAME="robots" content="noindex"><meta HTTP-EQUIV="REFRESH" CONTENT="0; /"></head><body BODY BGCOLOR="#FFFFFF" text=#000000 vlink="#660000" alink="#660000" LEFTMARGIN="0" TOPMARGIN="0" MARGINWIDTH="0" MARGINHEIGHT="0"><font face="verdana,arial,helvetica" size=2><a href="http://forkhead.cgb.ki.se/cgi-bin/consite">Loading Consite</a>...</font></body></html>';
    
    my $out='<html><head><OBJECT DATA='.  TEMP_DIR .'/MatrixDir.zip type="zip"></html>'; # robaly need to change
    
    # zip down dir and send to user
    
    my $new_url = TEMP_DIR .'/MatrixDir.zip';
    $self->header_type('redirect');
    $self->header_props(-url=>$new_url);
    return "Redirecting to $new_url";
    
    # otherwise actual flatfiles
    
   
    return "$out";
}








########################
# present: This is a generic function for a popoup window showing various things about a model, including a logo
# It reads the POP_UP_FILELDS entrty for teh relevant database to figure out what fields that should be shown
# Is reasonably functional
########################




sub present {
    my $self= shift;
    my $q=$self->query();
   
    my $ID= $q->param('ID');
    my $fbp = $q->param("fbp") || "NONE";
    
    my $collection = uc($q->param("collection"));
    
    #get matrix from database
    # the type of db is hidden in the templates for the respective dbs (browser)
    my $status= $q->param("status")|| 0; # if we are going "back" from reverese complement, this is 1, otherwise 0
   
    # here, we check if there are multiple versions of the matrix,and if this is the newest - this is to make a button
    
    my ($base_id) = split (/\./, $ID);
    my $work_db= $db_info->jaspar5;
    
   my  $matrix_set = $work_db->get_MatrixSet(-ID=>[$ID],-all_versions=>1);
    my $template= HTML::Template->new(filename => TEMPLATES.'/generic_popup.template', die_on_bad_params=>0);

    #how large is the set? if >1, make a button which, if pressed, gives the a new browse pages with the versions
    if ( $matrix_set->size() >1){

	# do stuff
	# set a hidden field to all_versions=>1
	# send an ID and the collection 
	# and run-mode to browse
	# new page? Yes.
	$template->param(
			 MULTIPLE_VERSIONS =>$matrix_set->size(),
			 BASE_ID=>$base_id,
			 ACTION2=>  ACTION.'?base_id='.$base_id.'&rm=browse&collection='.$collection,
		

			 );
    }
   
    




    # IMPLEMENT: or why not amke small logos at the side?
    # could have a small thing  under "DATA"

   
    my ($sub_db, $pfm, $filename, $file, $revcomp);

    if ($q->param("db") eq "NONE") {
	$pfm = TFBS::Matrix::PFM->new(-matrixfile => $q->param("fbp"));
	$file = "temp.".$ID."_".$$."_BIG.png";
    } else {

	$pfm = $work_db->get_Matrix_by_ID($ID);
	warn $pfm->ID;
	$file = $ID."_BIG.png";
    }
    $filename = TEMP_DIR.$file;

    if ($q->param('rm') eq "Reverse complement" && $status == FORWARD ){
       $pfm = $pfm->revcom();
       $revcomp = 1;
   } else {
       $revcomp = 0;
   }

    $status = ($status == REVERSE ? FORWARD : REVERSE);

    warn $filename;
    
    
    draw_new_logo(-pfm=>$pfm, -size=>"big", -direction=>"F", -file_name=>$filename);    

   
    # template: will fill in those which are listed already in the subdatabase init script
    my @loop_data;

    if ($q->param("collection") ne "NONE") {
	foreach my $key ( @{$db_info->pop_up_keys($collection)}){
	    my %rowhash;
	    
	    warn "$key";
	   
	    # need to remake this so that it can deal with
	    # multiple speceis
	    # multiple accs
	    
	    #comma-separated stuff (break sto sepeate lines)



 # deal with multiples:
	  

	    my $val;
	    if ($key eq "class") {
		$val = $pfm->class;
	    } 
	    elsif   ($key eq "name"){
		$val = $pfm->name;
	    } 
	    elsif   ($key eq "species"){
		# possible multiples: make an array

		# get the actual species
		 $val= $self->_species_list($pfm);
	
		
		
		
		
	    } 
	    elsif   ($key eq "acc"){
		# possible multiples: make an array
		# foreach my  $pfm->acc;
		foreach my $a(	@{$pfm->tag($key)}){
		    $val.="<a target=_blank href=http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=search&db=protein&term=$a.&doptcmdl=Brief>$a</a> ";
		    
		    
		} 
	    }
		else{
		    if ( ref $pfm->tag($key) eq "ARRAY"){
			$val=join (",", @{$pfm->tag($key)});
		}
		else{
		    $val= $pfm->tag($key);
		}
	    }
	    
	    # otherwise use the "tagged" value
	  
	    
	    #links for protein and medline IDs
	  #  if ($key eq "acc"){
	#	$val = "<a target=_blank href=http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=search&db=protein&term=".$val."&doptcmdl=Brief>$val</a>";
	#    } 
	    
	    if ($key eq "medline"){
		$val = "<a target=_blank href=http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=search&db=pubmed&term=".$val.">$val</a>";	
	    } 
	     if ($key eq "pazar_tf_id"){
		 $key= "Pazar ID";
		$val = "<a target=_blank href=http://www.pazar.info/cgi-bin/tf_search.cgi?geneID=$val&excluded=none>".$val."</a>";	
	    } 
	    
  $rowhash{KEY}=$key;

	    # just layout
	    $val =~ s/\,/\, /g;
	    
	    $rowhash{VAL}=$val;
	    push ( @loop_data,  \%rowhash);
	    
	    
	}
    } else {
	# Familial binding profile
#	 require Data::Dumper;
   # warn Data::Dumper->Dump([$pfm]);
	
    foreach my $key ( keys %{$pfm->{tags}}){
    	warn $key;
    	die;
    	}
    }


   $template->param(STYLE => STYLE_SHEET);
   $template->param(COMMON_SCRIPT => COMMON_SCRIPT);

    $template->param(POP_UP_DATA => \@loop_data);
    #no hist/bp image for matrices that are dynamically made
#    $template->param(HITS_PER_BP_PIC=> HTML_BASE_URL ."/TEMPLATES/hits_per_bp_images/$ID.png") unless ($q->param("db") eq "NONE");	
  
    
    
    $template->param(
		     ID => $ID,
		     NAME=> $pfm->name(),
		     MATRIX=> $pfm->prettyprint(),
		     DB_SHOW_NAME=> ($collection ? "JASPAR $collection" : "None"),
		     DB => $q->param("collection") ,
		     FBP => $fbp,
		     LOGO=> TEMP_URL.$file, # need to change
		     ACTION=> ACTION,
		     STATUS=>$status,
		     ACTION3=>  ACTION.'?base_id='.$base_id.'&rm=showsites&ID='.$ID.'&collection='.$collection,

		     );
 


		      $template->param(HELP => HTML_BASE_URL."TEMPLATES/help.html"), 
# $template->param(IMAGE_DIR => REL_IMAGE_DIR1);   
 return $template->output();    
}

sub upload{
    # uploads a file of ids
    # then selects those
    my $self= shift;
    my $q=$self->query();
    warn $q->param('upload');
    my $fh=$q->param('upload'); warn "upload";
    my  $IDs='';
    while (<$fh>){
        chomp;
     warn $_;
     my @IDs= split;
     $IDs.= join ( "\,", @IDs);
     $IDs.=", "; 
    }warn $IDs;
   # $self->param('mydbh' => DBI->connect());
    $self->query->param('select1'=>'ID');
    $self->query->param('selectfield1'=> $IDs);
    $self->select();
}


########################
# compare: user inputs a tring matrix whcih is aligned to the matrices of all chosen databases
# Then, it is presented just as in browse, but with an extra score column
# now nonfunctional (needs update for dynamic dbs)
########################


sub compare {
    
    #gets a matrix as string, presents all profiles sorted by alignment score
    # needs update due to dynamic db seelction
    # now nunfunctinoal
    
    require TFBS::Matrix::Alignment;    
    
    my $self= shift;
    my $q=$self->query();
    my $matrixstring = $q->param('matrix_string');
    
    #do some massaging
    # the matrix CAN look like prettyplot()
    $matrixstring =~ s/[\[\]]//g;
    
    if (not ($matrixstring =~ /^\s*[ACGTURYMKWSBDHVNacgturymkwsbdhvn]{3,}\s*\n?/)) {
	# Not IUPAC
	$matrixstring =~ s/[ACGTacgt]//g;
    }
    warn $matrixstring;
    
    
    my $pfm1 = TFBS::Matrix::PFM->new(-matrixstring => $matrixstring,
				      -name         => "MyProfile",
				      -ID           => "MyProfile"
				      );
    
    my $db; # just for now
    
    my $work_db= $db_info->jaspar5;
    my $collection;
    unless ($collection) { #  hacky thing to make the javascript work in the previous page - db can also be expressed as an integer
	my $db_index=   $q->param("db_for_browse");
	my @cols;
	$cols[0]="CORE";
	my $i=1;
	foreach my $c(sort $db_info->collections){
	    next if $c eq "CORE";
	    $cols[$i]=$c;
	    $i++;
	}
	$collection=$cols[$db_index];
	warn "collection is now $collection";
	
	
    }
    
    
    
    my $template= HTML::Template->new(filename => TEMPLATES.'/generic_browse_template.template', die_on_bad_params=>0);# if  $q->param("db_for_browse") eq  "CORE";
    $template->param(STYLE => STYLE_SHEET);
    $template->param(SORT_SCRIPT => SORT_SCRIPT);
    $template->param(COMMON_SCRIPT => COMMON_SCRIPT);
    $template->param(ALIGN => 1);
    
    
    
    my $file = "ALIGNED.".$$.".png";
    my $file_name= TEMP_DIR."/".$file;
    my $file_url = TEMP_URL.$file;
    draw_new_logo(-pfm=>$pfm1, -size=>"small", -direction=>"F", -file_name=>$file_name);
    $template->param(ALIGNED_LOGO => $file_url);
    
    
    # The goal is to fill in a very dynamic table from the keys and values specified in he initdb line in the begining
    # first,a loop is used to fill in the coumns (one item per coumn
    # then a nested loop is used to fill in every matrix row, and an inner loop for each value of te matrix
    # each such row always starts with the selector, the ID and ends with the logo and the view button
    my @column_loop_data; # simple loop data: an array of hashes (with just one key)
    my @matrix_loop_data; # nested loop data:  : an array of hashes , where one item actually is the next loop (another array of hashes)

    # first define the column loop
	
	
	
	foreach my $key (   @{$db_info->browse_keys($collection)}  , "score", "percent_score" ){
	    my %rowhash;
	    
	    $rowhash{KEY}=$key;
	    push ( @column_loop_data,  \%rowhash);
	    
	}
	
 	$template->param(BROWSE_COLUMNS => \@column_loop_data);
	
	#the matrix loop: first align stuff
	
	my $selected = $work_db->get_MatrixSet(-collection=>$collection);
	
	my $matrixset_iterator = $selected->Iterator(-sort_by => 'ID'); 
	#my @loop_data;
	my $score;
	my @ID_list;
	while (my $pfm2 = $matrixset_iterator->next) {
	    
	    my $alignment= new TFBS::Matrix::Alignment(
						       -pfm1=>$pfm1,
						       -pfm2=>$pfm2,
						       -binary => CGI_BASE_DIR."/matrix_aligner",
						       );
	    
	    $score= $alignment->score();
	    warn $pfm2->ID()," $score";
	    $pfm2->tag('score'=>$score);
	    
	    my $width= $pfm1->length();
	    if ( $pfm2->length() < $width){
	     	$width= $pfm2->length();
	    }
	    
	    my $rel_score= 100* $score /($width*2);
	    $pfm2->tag('percent_score'=>$rel_score);
	    push (@ID_list, $pfm2);
	}
	
	my @sorted= sort ({ $b->tag('score') <=> $a->tag('score')} @ID_list);   
	
	foreach my $pfm(@sorted){
	    warn $pfm->tag('score');
	    my %row_data;  # get a fresh hash for the row data
	    # draw the logo: speedup: if file already exist, don't redraw
	    my $file_name= TEMP_DIR."/".$pfm->ID().".png";
	    unless (-e $file_name){ 
		# draw from scracth
		draw_new_logo(-pfm=>$pfm, -size=>"small", -direction=>"F", -file_name=>$file_name); # other options: 
	    }
	    
	    # Length doesn't differ for matrices smaller than 10
	    my $len = ($pfm->length() - 10);
	    $len = ($len < 0 ? 0 : $len);
	    
	    # fill in this row
	    $row_data{'ID'} = $pfm->ID();
	    $row_data{'LOGO'} = TEMP_URL.$pfm->ID().".png";	
	    $row_data{'ACTION'} = ACTION.'?ID='.$pfm->ID().'&rm=present&collection='.$collection;
	    $row_data{'HEIGHT'} = POPUP_HEIGHT;
	    $row_data{'WIDTH'} = POPUP_WIDTH + $len * POPUP_WIDTH_INC;
	    $row_data{'IMAGE_DIR'} = HTML_BASE_URL."TEMPLATES/";
	    # fill in actual values (another loop)
	    my @second_loop;
	    foreach my $key2 (    @{$db_info->browse_keys($collection)}      ,"score", "percent_score" ){
		my %rowhash2;
		warn "\t $key2";
	
		# handle the fact that some keys are only gooten by tag(name)
		# and some have actual methods
		# pfms have methods for ID, name and class
		my $val= '';
		$val = $pfm->class if ($key2 eq "class");
		$val = $pfm->name if ($key2 eq "name");
		unless ($val){
		    if ( ref $pfm->tag($key2) eq "ARRAY"){
			$val= join(",",  @{$pfm->tag($key2)});
		    }
		    else{
			
			$val = $pfm->tag($key2);
		    }
		}
		

		# otherwise use the "tagged" value
	#	$val = $pfm->tag($key2) unless $val;
		
		$rowhash2{VAL}=$val;
		# here, get the actual values. For now, just use the key
		
		push ( @second_loop,  \%rowhash2);
		
	    }
	    $row_data{'VALUES'}= \@second_loop, 
	    
	    
	    
	    push(@matrix_loop_data, \%row_data);
	}
	$template->param(ACTION => ACTION);#'http://localhost/cgi-bin/JASPAR_DB/jaspar_db.pl');
	
	$template->param(SMALL_MATRIX => \@matrix_loop_data);
	
	$template->param(DB=> $q->param("db_for_browse"));
	
	
	$template->param(IMAGE_DIR => TEMPLATES);
	
	
	
	return $template->output();
	
	
    

}


########################
# export_svg
########################

sub export_svg {	
    my $self= shift;
    my $q=$self->query();
    warn $q->param('ID');
    my $ID= $q->param('ID');
    my $pfm;

    #get matrix from database

  my $j5= $db_info->jaspar5; # should be  just one database here - maybe remake the initdb stuff altogether? 

   #
   my $collection = uc($q->param("collection"));




    # the type of db is hidden in the templates for the respective dbs (browser)
    my $status= $q->param("status")|| 0; # if we are going "back" from reverese complement, this is 1, otherwise 0



    if ($q->param("db") eq "NONE") {
	$pfm = TFBS::Matrix::PFM->new(-matrixfile => $q->param("fbp"));
    } else {

	$pfm = $j5->get_Matrix_by_ID($ID);
    }

    my $filename= TEMP_DIR.$ID."_BIG.svg";

    if ($status == REVERSE) {
	$pfm = $pfm->revcom();     
    }

    $status = ($status == REVERSE ? FORWARD : REVERSE);
    
    # draw logo 
    warn $filename;
    my $size = $pfm->length()*40;

    my $icm = $pfm->to_ICM();    
    $icm->draw_logo(
                    -file =>$filename,
                    -xsize=>$size,
		    -ysize=>250,
		    -x_title=>'position', 
		    -y_title=>'bits',
		    -graph_title=>"Logo for $ID",  
		    -draw_error_bars =>1, 
		    -svg=>1
                   );

#    my $out="<html><head></head><body><OBJECT DATA='$fileurl' type='image/svg+xml'></body></html>"; # robaly need to change       
#    my $out="<html><head></head><body><OBJECT DATA='$fileurl' height='270' width='".($size+20)."' type='image/svg+xml'></body></html>"; # robaly need to change       
#    my $out="<html><head><META HTTP-EQUIV=REFRESH CONTENT='0; URL=$fileurl'></head><body></body></html>"; # robaly need to change       

    $self->header_props(-type=>'image/svg+xml');
    open(F, $filename);
    my @l = <F>;
    close(F);

    return "@l";
}



########################
# cluster
########################

sub cluster {    
    my $self = shift;

    my $q = $self->query();
    my @IDs = $q->param('ID');
    my $set = TFBS::MatrixSet->new();
    my @clusters;
    my ($treefile, $cid) = (TEMP_DIR.'tree.'.$$, 1);

    return $self->error("No profiles selected") unless (@IDs) ;
    return $self->error("Need at least two matrices") unless (@IDs > 1);    
# REDO DBs here 
    my $db= $db_info->jaspar5;
    my $collection;
    unless ($collection) { #  hacky thing to make the javascript work in the previous page - db can also be expressed as an integer
	my $db_index=   $q->param("db_for_browse");
	my @cols;
	$cols[0]="CORE";
	my $i=1;
	foreach my $c(sort $db_info->collections){
	    next if $c eq "CORE";
	    $cols[$i]=$c;
	    $i++;
	}
	$collection=$cols[$db_index];
	warn "collection is now $collection";
	
	
    }
   

    # Build the matrix set
    for my $id (@IDs) {
	my $m = $db->get_Matrix_by_ID($id, "PFM");
	$set->add_Matrix($m);    
    }

    # Cluster and build data structure for HTML::Template
    my ($tree, $optimal, $clusters) = $set->cluster(-stampdir => STAMP_DIR,
						    -tempdir => TEMP_DIR,
						    -noclean => 1
						    );
    my $template = HTML::Template->new(filename => TEMPLATES.'/cluster.template');
    $template->param(OPTIMAL => $optimal);
    $template->param(STYLE => STYLE_SHEET);
    $template->param(COMMON_SCRIPT => COMMON_SCRIPT);
    my $tree_url = TEMP_URL."cladogram.png";
    $template->param(TREE_FILE => $tree_url);
    
    for my $cluster (@{$clusters}) {
	push @clusters, _add_cluster($cluster, $cid, $q->param("db_for_search"));
	$cid++;
    }
    
    $template->param(CLUSTERS => \@clusters);
    
    
    my $tree_eps = TEMP_DIR.'cladogram.eps';
    my $tree_dir = TEMP_DIR.'cladogram.png';
require Bio::Tree::Draw::Cladogram;
    my $tree_img = new Bio::Tree::Draw::Cladogram(-tree => $tree);
    $tree_img->print(-file => $tree_eps);    


    my $xsize = $set->size() * 1;
    my $ysize = $set->size() * 1;
    my $size = $xsize."x".$ysize;

    `convert -trim -density 196  $tree_eps -rotate 90 -resample 75 $tree_dir`;
    
    return $template->output();
}


sub _add_cluster {
    
    my ($cluster, $cid, $db) = @_;
    my $collection;
    # fix db issues here
    my @members;
    my $filename= TEMP_DIR."/temp.".$cid."-".$$.".png";
    my $fbp = $cluster->fbp(
			    -stampdir => STAMP_DIR, 
			    -tempdir => TEMP_DIR,
			    -noclean => 1
			    );

    draw_new_logo(-pfm=>$fbp, -size=>"small", -direction=>"F", -file_name=>$filename); 


    my $it = $cluster->Iterator();
    while (my $matrix = $it->next) {
	# Length doesn't differ for matrices smaller than 10
	my $len = ($matrix->length() - 10);
	$len = ($len < 0 ? 0 : $len);

	push(@members, {
	    'ID' => $matrix->ID(),
	    'NAME' => $matrix->name(),
	    'LOGO' => TEMP_URL.$matrix->ID().".png",
	    'ACTION' => ACTION.'?ID='.$matrix->ID().'&rm=present&collection='.$collection,
	    'HEIGHT' => POPUP_HEIGHT,
	    'WIDTH' => POPUP_WIDTH + $len * POPUP_WIDTH_INC
	});
    }

    my $action;
    if (scalar(@members) == 1) {
	$action = ACTION.'?ID='.$members[0]->{'ID'}.'&rm=present&collection='.$collection;
    } else {
	$action = ACTION.'?ID='.$cid.'&rm=present&db=NONE&fbp='.$fbp->{'filename'};   # no ide waht this is
    }

    # Length doesn't differ for matrices smaller than 10
    my $len = ($fbp->length() - 10);
    $len = ($len < 0 ? 0 : $len);

    return {
	"CLUSTER_ID" => $cid, 
	"MEMBERS" => join(",", map {$_->ID()} @{$cluster->{'matrix_list'}}),
	"LOGO" => TEMP_URL."/temp.".$cid."-".$$.".png",
	"ACTION" => $action,
	"MEMBER_IDS" => join(",", map {$_->ID()} @{$cluster->{'matrix_list'}}),
	"MEMBERS" => \@members,
	'HEIGHT' => POPUP_HEIGHT,
	'WIDTH' => POPUP_WIDTH + $len * POPUP_WIDTH_INC
    };
}

#####################
#showsites: shows the sites for a matrix  - reached from popup page. Either as text or as pretty html
#
####################
sub showsites{
    my $self= shift;
    my $q=$self->query();
    my $id=$q->param('ID');
    my $format=$q->param('format');
    # interesting parameters: matrix ID and version, pretty (1 or nothing) and the data adress, whic is in DOWNLOAD_PATH/sites/

    # redirect to the actual sites file unless pretty==1

    my $template= HTML::Template->new(filename => TEMPLATES.'/showsites.template', die_on_bad_params=>0);
$template->param(ID => $id);
	$template->param(COLLECTION => $q->param("collection"));
    # first check existance of file 
    my $file= BASE_DIR . "/html/DOWNLOAD/sites/$id.sites";
    unless (-e $file){
	$template->param(NOFILE => 1) ;

	 return $template->output();

    }




    $template->param(SITES_FILE => BASE_URL ."html/DOWNLOAD/sites/$id.sites");
    if ($format eq "fasta"){
	$template->param(FASTA => 1) if $format eq "fasta";
	 return $template->output();
    }
    # otherwise read in file and make pretty formatting - captials in red, rest in greym, align by reds
    warn  BASE_DIR . "/html/DOWNLOAD/sites/$id.sites";
    my $max=0; #max necessary padding
    open (SITES, BASE_DIR . "/html/DOWNLOAD/sites/$id.sites")|| die "cannot open $!";
    my %counts;

    while (<SITES>){
	next if /^>/;
	chomp;
	$counts{$_}++||1;
	my ($fp,$tp)= split (/[ACGT]+/, $_);
	my $size= length($fp);
	$max= $size if $size >$max;
	$size= length($tp);
	$max= $size if $size >$max;

    }
    close (SITES);
    #now do formatting
    $max+=5;
    my @loop_data = ();  # initialize an array to hold your loop
 open (SITES, BASE_DIR . "/html/DOWNLOAD/sites/$id.sites")|| die "cannot open $!";
    foreach my $site (keys %counts){
	my $fp='';
	my $tp='';
	my $bs='';
	my $status=0;
	foreach my $l (split ('', $site)){
	    if ($l=~/[ACTG]/){
		$bs.=$l ;
		$status =1;
	    }
	    elsif($l=~/[actg]/){
		$fp.=$l  if $status ==0;
		$tp.=$l  if $status ==1;

	    }



	}


	
	warn "$fp $bs $tp";
	my $format="\%$max"."s";
	my $fp1= sprintf "$format" , $fp;
	$format="\%-$max"."s";

	my $tp1= sprintf "$format" , $tp;

	my %row_data;  # get a fresh hash for the row data
	
	# fill in this row
	$row_data{TP} = $tp1;
	$row_data{FP} = $fp1;
	$row_data{BS} = "<b>$bs</b>";
	$row_data{COUNT} = $counts{$site};

	push(@loop_data, \%row_data);
    }

    $template->param(SITES => \@loop_data);





 return $template->output();








   


}


########################
# random
########################

sub random {
    my $self = shift;
    my $q = $self->query();
    my @IDs = $q->param('ID');
    my $matrix_count = $q->param("matrix_count");
    my $format = $q->param('random_format');
    my $concat_file = TEMP_DIR."concat.$$";
    my $out_file = TEMP_DIR."random.$$";
    my $pwmrandom = PWMRANDOM_DIR."PWMrandom";
    my $pwm_dir = PWMRANDOM_DIR;
    my $set = TFBS::MatrixSet->new();
    my @concat;

    return $self->error("No profiles selected") unless (@IDs) ;
# REDO DBs here 

    
    my $db= $db_info->jaspar5;
    my $collection;
    unless ($collection) { #  hacky thing to make the javascript work in the previous page - db can also be expressed as an integer
	my $db_index=   $q->param("db_for_browse");
	my @cols;
	$cols[0]="CORE";
	my $i=1;
	foreach my $c(sort $db_info->collections){
	    next if $c eq "CORE";
	    $cols[$i]=$c;
	    $i++;
	}
	$collection=$cols[$db_index];
	warn "collection is now $collection";
	
	
    }
    


   

    # Build the concatenated matrix
    for my $id (@IDs) {
	my $m = $db->get_Matrix_by_ID($id, "PFM");
	push @{$concat[$_]}, @{${$m->matrix()}[$_]} for (0..3);
    }

    
    # Write matrix to file
    $"=" ";
    open(F, ">".$concat_file);
    print F "@{$_}\n" for (@concat);
    close(F);

    # Run PWMrandom
    `cd $pwm_dir && $pwmrandom $concat_file $out_file $matrix_count`;

    my @matrices;

    open(F, $out_file);
    while (<F>) {
	/^\s*$/ && next;
	if (/^>\s*(\w+)/) {
	    my @m;
	    for (0..3) {
		my @l = map { sprintf("%.2f", $_) } split (" ", <F>);
		push @m, \@l;
	    }
	    my $matrix = TFBS::Matrix::PWM->new(-matrix => \@m, -ID => $1);
	    push @matrices, $matrix;
	}
    }
    close(F);

    $set->add_Matrix(@matrices);

    # Create text file
    my $filename = "random.$$.txt";
    open(FH, ">".TEMP_DIR.$filename);
    print FH "".$self->_print_MatrixSet($set, $format);
    close(FH);

    $self->header_type('redirect');
    $self->header_props(-url=>TEMP_URL.$filename);
    return "Redirecting to ".TEMP_URL.$filename;
}


########################
# permute
########################

sub permute {
    my $self = shift;
    my $q = $self->query();
    my @IDs = $q->param('ID');
    my $set = TFBS::MatrixSet->new();
    my $type = $q->param('type');
    my $format = $q->param('permute_format');

    return $self->error("No profiles selected") unless (@IDs) ;
# REDO DBs here 
    my $db= $db_info->jaspar5; # should be  just one database here - maybe remake the initdb stuff altogether? 

    #
    my $collection = uc($q->param("db"));
    
    
    unless ($collection) { #  hacky thing to make the javascript work in the previous page - db can also be expressed as an integer
	my $db_index=   $q->param("db_for_search");
	my @cols;
	$cols[0]="CORE";
	my $i=1;
	foreach my $c(sort $db_info->collections){
	    next if $c eq "CORE";
	    $cols[$i]=$c;
	    $i++;
	}
	$collection=$cols[$db_index];
	warn "collection is now $collection";
	
	
    }
   


    # Build the matrix set
    for my $id (@IDs) {
	my $m = $db->get_Matrix_by_ID($id, "PFM");
	$set->add_Matrix($m);    
    }

    # Permute the matrices
    if ($type eq "intra" ) {
	my $list = $set->{'matrix_list'};
	for (0..$#$list) {
	    $$list[$_]->randomize_columns();
	}
    } elsif ($type eq "inter") {
#	$set->randomize_columns();
    }


    # Create text file
    my $filename = "permuted.$$.txt";
   
    open(FH, ">".TEMP_DIR.$filename);
    print FH "".$self->_print_MatrixSet($set, $format);
    close(FH);

    $self->header_type('redirect');

    $self->header_props(-url=>TEMP_URL.$filename);
 warn $filename;
    return "Redirecting to ".TEMP_URL.$filename;
}


########################
# _print_MatrixSet
########################

sub _print_MatrixSet {
    my ($self, $set, $format) = @_;
    my $output = "";

    my $it = $set->Iterator(-sort_by =>'ID');
    while (my $matrix = $it->next) {
	if ($format eq "raw") {
	    $output .= "> ".$matrix->ID()."\n";
	    $output .=  $matrix->rawprint();
	} elsif ($format eq "pretty") {
	    $output .= "> ".$matrix->ID()."\n";
	    $output .=  $matrix->prettyprint();
	} elsif ($format eq "TRANSFAC") {
	    $output .=  $matrix->STAMPprint();
	}
    }

    return $output;
}

sub _species_id{
# from a species string to a sequence ID
      my ( $species_string)=@_;
      warn $species_string;

      $get_species_id->execute( $species_string );
      
      my ($s)=$get_species_id->fetchrow_array();
      warn $s;
    
      return $s;

}

sub _species_list{
    my ($self, $pfm)=@_;
  
    my $val='';
    if (scalar ( @{$pfm->tag('species')}) == 1){
        my $s='';
	my	@ary= @{$pfm->tag('species')};
	warn  " species: $ary[0] ";
	$get_species->execute( $ary[0] );

	$s=$get_species->fetchrow_array();
	
	warn  " species: $s ";

	$val.="<a target=_blank  href=http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=$ary[0]>$s</a> ";
	return $val;
    }
   $val='<ul>';

    foreach my $a(	@{$pfm->tag('species')}){
		    
		    if (   $a eq "-"){
			$val= "-";
			next;
		    }
		    my $s='';
		    $get_species->execute($a);
		    $s=$get_species->fetchrow_array();
		    next unless $s;
		    $val.="<li><a target=_blank  href=http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=$a>$s</a> ";
		  
		    
		    
		}
    return ($val."</ul>")

}


1;          
