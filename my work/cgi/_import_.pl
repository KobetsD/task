#!/usr/bin/perl -w
#
# SMIS 
# 12/10/2010 16:18

use strict;

use SDB::common;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use SDB::hash2config;
use SDB::time qw(get_current_date_and_time);
use SDB::mysql_object;
	
use proci::db qw(my_quotemeta);


use proci::_config qw( 
	$DIR_WORKSTN
	
	$DB 
  	$HOST 

  	$USER 
	$PASSWORD 
	
	$PROCS_TABLE
	$TASKS_TABLE
	$PROC_TASK_TABLE
);


### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;


### Global variables

my $proci_mysql = new SDB::mysql_object(
	host		=> $HOST,
	db			=> $DB,
	user		=> $USER,
	password	=> $PASSWORD,
	sql_debug	=> $SQL_DEBUG,
);

### Functions

#my %opt=@_;	
my @tasks;
my %tasks;
 
print STDERR "\n $DIR_WORKSTN/*.ini";

$proci_mysql->do("TRUNCATE $PROC_TASK_TABLE");
$proci_mysql->do("TRUNCATE $PROCS_TABLE");
$proci_mysql->do("TRUNCATE $TASKS_TABLE");

while ( defined ( my $dirname = glob ( "$DIR_WORKSTN/*" ) ) ) {
			
	if ( -d $dirname ) {
			
		my $proc_name	= $dirname;
		$proc_name		=~ s/$DIR_WORKSTN\///;
		
		my $sql	= qq(
			SELECT proc_id 
			FROM $PROCS_TABLE 
			WHERE proc_name="$proc_name"
		);
	 	my $sth	= $proci_mysql->execute( $sql );
		
		my $proc_id;
		
		if ( $sth->rows > 0 ) {
 			$proc_id	= $sth->fetchrow_array();	
 		} else {
 			$proci_mysql->do( 
				"INSERT INTO $PROCS_TABLE 
				SET proc_name='$proc_name'"
			);	
 			$proc_id = $proci_mysql->get_last_insertid();
 		}
		
		$proci_mysql->do( 
			"DELETE FROM $PROC_TASK_TABLE 
			WHERE proc_id='$proc_id'"
		);
		
		while ( defined ( my $filename = glob ( "$dirname/*.ini" ) ) )	{ ## 
			
			my $task_name	= $filename;
			$task_name		=~ s/$dirname\///;
			$task_name		=~ s/\.ini//;
			
			$task_name	= my_quotemeta( $task_name );
			
			open( INI_FILE, "<$filename" );
			#my @str_file;
			#while (<INI_FILE>) {
			#	push @str_file,my_quotemeta($_);	
			#}
			#close(INI_FILE); 
			my $fileContent;
			#my $str_file=join("",@str_file);
			
			binmode( INI_FILE );
			{
				local $/;
				$fileContent = <INI_FILE>;
			}
			close( INI_FILE );
			$fileContent =~ s/\\/\\\\/g;
			$fileContent =~ s/\"/\\"/g;
			
			#----------Extra functionality (Kobetc D.A.)----------
			my @task_full	= split( /\n/, $fileContent );	#Cut the task content into separate strings
			my %hash;								#Create "%hash" for "nPriority" and "nMaxHours"
			foreach my $str ( @task_full ) {
				my @parametr	= split( /=/, $str );		#Cut each string: parameter and value of parameter 
				if (	
					( $parametr[0] eq "nPriority" )	||
					( $parametr[0] eq "nMaxHours" )	||
					( $parametr[0] eq "nRequiredMem" )
				) {
					%hash = (
						%hash, 
						$parametr[0] => $parametr[1]
					);#Add to hash
				}
			}
			#----------------------------------------------------------
			
			my $sql	= qq(
				select task_id 
				FROM $TASKS_TABLE 
				WHERE task_name="$task_name"
			);
		 	my $sth	= $proci_mysql->execute( $sql );
			
			my $task_id;
			
			if ( $sth->rows > 0 ) {
	 			$task_id	= $sth->fetchrow_array();	
	 			#$proci_mysql->do("UPDATE $TASKS_TABLE SET task_name='$task_name' WHERE task_id='$task_id'");
	 		} else {
	 			$proci_mysql->do(
					qq(
						INSERT INTO $TASKS_TABLE 
						SET task_name='$task_name',
							task_full="$fileContent",
							nPriority="$hash{"nPriority"}",
							nMaxHours="$hash{"nMaxHours"}",
							nRequiredMem="$hash{"nRequiredMem"}"
					)
				);# nPriority, nMaxHours и nRequiredMem - Extra functionality (Kobetc D.A.) 
	 			$task_id	= $proci_mysql->get_last_insertid();
	 		}
			$proci_mysql->do( 
				"INSERT INTO $PROC_TASK_TABLE 
				SET task_id='$task_id',
					proc_id='$proc_id'"
			);
		}
	}					
 }	