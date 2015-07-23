#!/usr/bin/perl -w
#
###############################################
# 
# write by Dmitry Kobets
###############################################

use strict;

use SDB::common;
use SDB::mysql_object;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use SDB::time qw(get_current_date_and_time);
use SDB::mail;
use Data::Dumper;


use proci::db qw( 
	BeginTransaction 
	CommitTransaction 
	my_quotemeta 
);

use lib qw(/data/pms/lib);
use stations qw( get_station_state_by_proc_id);

### Constants
use proci::_config qw( 
		$TEMPLATE_DIR 
		$COMMON_TEMPLATE_FILE 
		@COMMON_TEMPLATE_SECTIONS
		$PROC_INFO_SCRIPT
		$PROCS_SCRIPT
		$PRINT_CFG_SCRIPT
		$EMPTY_HTML
		
		$DB
		$HOST
		$USER
		$PASSWORD
		$TASKS_TABLE
		$PROCS_TABLE
		$PROC_TASK_TABLE
		
		$DB_pms
		$USER_pms
		$PASSWORD_pms
);

use proci::proci qw( CheckProc );

my $TEMPLATE_FILE = "$TEMPLATE_DIR/procs.htm";
my @TEMPLATE_SECTIONS = qw( );

### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;

### Global variables

### Functions
sub compose_option_list($;$);
sub update_proc_task_info($);
sub remove_proc_task_info($);


### Parse query string
my $query_string =  get_query_string();
my %cgi = parse_query_string( $query_string, {continuation => 1} );
map{ $cgi{$_} = undef if $cgi{$_} eq ""} keys %cgi;

### Connect to DB
my $mysql_pms = new SDB::mysql_object(
	host => $HOST,
	db => $DB_pms,
	user => $USER_pms,
	password => $PASSWORD_pms,
	sql_debug => $SQL_DEBUG,
);												#Connect to pms (use SDB::mysql_object)
my $mysql_proci = new SDB::mysql_object(
	host => $HOST,
	db => $DB,
	user => $USER,
	password => $PASSWORD,
	sql_debug => $SQL_DEBUG,
);												#Connect to proci (use SDB::mysql_object)


my $table_info = $mysql_proci->get_table_info($PROCS_TABLE);
my @fields = @{$table_info->{fields}};
my @keys = @{$table_info->{keys}};	


#----------Extra functionality (Кобец Д.А.)----------
# do_die(Dumper(\%cgi));
my $choose_proc;
if ($cgi{'proc_id_choose'}){
	$choose_proc=$cgi{'proc_id_choose'};
	delete($cgi{'proc_id_choose'});
}

#----------------------------------------------------------

### Check and derive parameters

# Rules for proc parameters
my @valid_parameters_definitions = map{ $_, '*' } @fields;
# Rules for task parameters

my @aux_parameters = map{ $_, '*' } qw(find_this task_select tasks active_tasks others_tasks);

my $rules = {
	valid => {
		mode => [qw( add update remove show) ],
		lang => [qw( russian english ) ],
		@valid_parameters_definitions,
		@aux_parameters,
		
	},
	relation => {
		mode => {
			add => \@fields,
			update => \@fields,
			remove => ["proc_id"],
			show =>  [ qw() ],
		},

	},
	default => {
		mode => "show",
		
	},
	blank2undef => 1,
};

my $opt = get_options( \%cgi, $rules);
unless( defined $opt ) {
	do_die( "Illegal script parameters: ". get_error->{msg} );
}

### Change proc information if required
my @active_tasks;
@active_tasks = split( /,/, $opt->{tasks} ) if $opt->{tasks};

my @keys_values = map { $opt->{$_} } @keys;
my %proc_table_fields_hash;
unless( $opt->{mode} eq "show" ) {
	%proc_table_fields_hash = map { $_, defined $opt->{$_} ? my_quotemeta( $opt->{$_} ) : undef } @fields;
}


my @curr_time = get_current_date_and_time();
my $curr_date = $curr_time[0];



my $alert=0;

my $proc_id = $proc_table_fields_hash{proc_id};

if( $opt->{mode} eq "add" ) {
	
	if (! CheckProc($opt->{proc_id}))
		{
			$proc_table_fields_hash{ts}="$curr_time[0] $curr_time[1]";

			#-----------
			# INSERT new record in $PROCS_TABLE
			my $sql="INSERT INTO $PROCS_TABLE 
					SET ".join(', ', map {"$_ = '".$proc_table_fields_hash{$_}."'"} (keys %proc_table_fields_hash));
			$mysql_proci -> do(qq($sql));
			
			# Get last insert ID
			my ($proc_id) = $mysql_proci -> get_value("SELECT LAST_INSERT_ID()");
			$opt->{proc_id}	= $proc_id;
			
			# INSERT record in $PROC_TASK_TABLE
			update_proc_task_info($opt->{tasks});
			
			#-----------
			BeginTransaction();
			CommitTransaction();
			$choose_proc = $proc_id;
			$alert=1;
	}
	else {
		$choose_proc = $proc_id;
		$alert=2;
		}
	
} elsif( $opt->{mode} eq "update") {

	BeginTransaction();
	$proc_table_fields_hash{ts}="$curr_time[0] $curr_time[1]";
	#-----------
	
	# Update record in $PROCS_TABLE
	my $sql="UPDATE $PROCS_TABLE 
				SET ".join(', ', map {"$_ = '".$proc_table_fields_hash{$_}."'"} (keys %proc_table_fields_hash))."
				WHERE proc_id='$proc_id'";
	$mysql_proci -> do(qq($sql));
	
	# Update record in $PROC_TASK_TABLE
	update_proc_task_info($opt->{tasks});
	
	#-----------
	$choose_proc = $proc_id;
	CommitTransaction();
	
	$alert=3;
	
} elsif( $opt->{mode} eq "remove") {
	
	BeginTransaction();
	#-----------
	
	# Remove record from $PROCS_TABLE
	my $sql="DELETE FROM $PROCS_TABLE 
				WHERE proc_id='$proc_id'";
	$mysql_proci -> do(qq($sql));
	
	# Remove record from $PROC_TASK_TABLE
	remove_proc_task_info($proc_id);
	
	#-----------
	
	CommitTransaction();
	$choose_proc = 0;
	$alert=4;
}

my $TasksRecords = $mysql_proci->GetCachedTableRecordsByKeys( table => $TASKS_TABLE, keys => ['task_id'], where => "", refresh => 1 );

# Load template
my %template;
tie %template, 'SDB::hash2template', $TEMPLATE_FILE, \@TEMPLATE_SECTIONS;

my %common_template;
tie %common_template, 'SDB::hash2template', $COMMON_TEMPLATE_FILE, \@COMMON_TEMPLATE_SECTIONS;

## Print HTML
print_content_type;


my $sql;
my $sth;

# default element select task_name list
my $task_select='All tasks';
#two first element
my @task_option_list;

push @task_option_list, {text => 'Любая задача', value => 'All tasks' };
 
#select task_option_list
foreach my $task_id ( keys %{$TasksRecords} ) {
			my $name=$TasksRecords->{$task_id}{task_name} || $task_id;
			push @task_option_list, {text => $name, value => $task_id };
}

#----------Extra functionality (Kobetc D.A.)----------
#Sort tasks by alphabetical order
#"alphabetical_order" - function for sort:
	#"$a" is the first element of massif and "$b" the second
	#-1 - "$a" behind "$b"
	#1 - "$b" behind "$a"
	#0 - it doesn't matter

my ( $first_option, @sorted_option )	= @task_option_list;
@sorted_option							= sort alphabetical_order @sorted_option;
@task_option_list						= ( $first_option, @sorted_option );

sub alphabetical_order{
	
	my $min_length = ( length $a->{text} , length $b->{text} )[ length $a->{text} > length $b->{text} ];
	my $a_ = substr( $a->{text}, 0, $min_length );
	my $b_ = substr( $b->{text}, 0, $min_length );

	$a_= lc $a_;	#Returns with all characters in lower-case
	$b_= lc $b_;

	if( $a_ gt $b_ ){1}
	elsif( $a_ lt $b_ ){-1}
	else{0}
}
#----------------------------------------------------------

if ( $opt->{mode} eq 'first') {

	
	print substitute( $template{header}, {
		choose_num => 0,
		add_proc_uri =>  $PROC_INFO_SCRIPT."?".compose_query_string( mode => "add" ),
		url_proc => $PROCS_SCRIPT, 
		empty_html=>$EMPTY_HTML,
		task_name =>  'All tasks',
		find_this =>  '',
		double_add_proc=>0,
		alert=>$alert,
		
	} );
	
	
	
	print substitute( $template{table_caption}, {
		url => $PROCS_SCRIPT, 
		add_proc_uri =>  $PROC_INFO_SCRIPT."?".compose_query_string( mode => "add" ),
		print_cfg_uri => $PRINT_CFG_SCRIPT,
		task_option_list =>  compose_option_list( \@task_option_list) ,
		
	} );
	
	
	goto FOOTER;
}









if (defined ($opt->{task_select})) 
	{	
		$task_select=$opt->{task_select};
	}




print STDERR "\n> task_select $task_select" if $DEBUG;



#prepare search
my $find="";
my $find_proc;
if (defined ($opt->{find_this}))
	{	
		if ( ($opt->{find_this}) eq ""){
			
		}
		else {
			$find_proc=$opt->{find_this};
			$find=$find_proc;
		}
	
	}

my @query_add;

if (defined ($find_proc)) {push @query_add, qq(procs.proc_id LIKE '%$find_proc%') }
	 		

# Get proc ids
my @proc_ids;


	
if ($task_select eq 'All tasks') {
	$sql = "SELECT proc_id FROM procs";
		
} elsif ($task_select eq 'Without any task')	{
		$sql = "SELECT proc_id FROM procs ";
		 push @query_add, qq(proc_id NOT IN (SELECT DISTINCT proc_id FROM proc_task) );
		
}
else {
		$sql = "SELECT proc_task.proc_id FROM proc_task,procs";
		 push @query_add, qq(proc_task.task_id='$task_select');
		 push @query_add, qq(proc_task.proc_id=procs.proc_id);
		
}



if (@query_add) { $sql=$sql.' WHERE '.join(' AND ',@query_add);}

$sql=$sql.' ORDER BY proc_name';


print STDERR "\n> $sql" if $SQL_DEBUG;
foreach my $proc_id_select ($mysql_proci->get_selection( $sql )){
	push(@proc_ids, $proc_id_select->{proc_id});
}


print STDERR "\n> proc_ids @proc_ids" if $DEBUG;


my $choose_num;
if( $choose_proc ) {
	for ( my $i = 0; $i<= $#proc_ids; $i++ ) {
		if(  $proc_ids[$i] eq $choose_proc ) {
			$choose_num = $i + 1;
		}
	}
	assert( $choose_num );
} else {
	$choose_num = 0;
}


# Print header


print substitute( $template{header}, {
	choose_num => $choose_num,
	add_proc_uri =>  $PROC_INFO_SCRIPT."?".compose_query_string( mode => "add" ),
	url_proc => $PROCS_SCRIPT, 
	empty_html=>$EMPTY_HTML,
	task_name =>  $task_select,
	find_this =>  $find,
	alert=>$alert,
	
} );


unless( @proc_ids ) {

	
	print substitute( $template{table_caption}, {
	url => $PROCS_SCRIPT, 
	add_proc_uri =>  $PROC_INFO_SCRIPT."?".compose_query_string( mode => "add" ),
	print_cfg_uri => $PRINT_CFG_SCRIPT,
	find_this =>  $find,
	task_option_list =>  compose_option_list( \@task_option_list) ,
	
	
} );
	
	print $template{no_procs};
	goto FOOTER;
}








# Print procs table
print substitute( $template{table_caption}, { 
	add_proc_uri =>  $PROC_INFO_SCRIPT."?".compose_query_string( mode => "add" ), 
	print_cfg_uri => $PRINT_CFG_SCRIPT,
	task_option_list =>  compose_option_list( \@task_option_list) ,
		
	
} );

print $template{table_header};

my $num = 0;
foreach my $proc_id (  @proc_ids ) {
	$num++;
	#--------------
	$sql	= 'SELECT '.join(', ', @{$table_info->{fields}})."\n
				FROM $PROCS_TABLE
				WHERE proc_id	= '$proc_id'";
	my $fields_href = $mysql_proci->get_record($sql);
	#--------------
	my %subst = map { $_, defined $fields_href->{$_} ? $fields_href->{$_} : "" } keys %$fields_href;
	
	$subst{num} = $num;
	$subst{update_proc_info_uri} = $PROC_INFO_SCRIPT."?".compose_query_string( mode => "update", proc_id => $proc_id );
	my $tpl = $template{table_row};
	

	#----------Extra functionality (Кобец Д.А.)----------
	#Get 'ProcID' from table 'Process' of 'pms' DB
	my $sql_pms=qq(
		SELECT ProcID
		FROM Process
		WHERE Name='$subst{proc_name}'
	);
	my $sth_pms=$mysql_pms->execute($sql_pms);
	my $ProcID=$sth_pms->fetchrow_array();
	
	if ( $ProcID ) {

		my $table_name='Process_'.$ProcID.'_Jobs';
	
		#--- Get time of activation [sec] of selected process ----
		$sql_pms=qq(
			SELECT
				SUM(
					if( FinishTime IS NULL,
						UNIX_TIMESTAMP( NOW() ),
						UNIX_TIMESTAMP( FinishTime )
					)
					-
					if( StartTime >= DATE_SUB( CURRENT_TIMESTAMP(), INTERVAL 3 DAY ),
						UNIX_TIMESTAMP( StartTime ),
						UNIX_TIMESTAMP( DATE_SUB( NOW(), INTERVAL 3 DAY ) ) 
					)
				)
			FROM $table_name
			WHERE FinishTime is NULL OR FinishTime > DATE_SUB( NOW(), INTERVAL 3 DAY )
		);
		$sth_pms=$mysql_pms->execute($sql_pms);

		my ($time)	= $sth_pms->fetchrow_array() || 0;
		$subst{busy_time}=int($time/(86400*3)*100);

		# ---
		
		
	
		# Set color
		if ($subst{busy_time} == 0) {
			$subst{tr_bgcolor}	= '#FFCC99';
		}elsif ($subst{busy_time} >= 50){
			$subst{tr_bgcolor}	= '#CCFF99';
		}else{
			$subst{tr_bgcolor}	= '';
		}
	
		$subst{busy_time}	= $subst{busy_time}.'%';
		
		# --- Current state ---
		my @Current_state_TEMPLATE_SECTIONS = qw( copyright );	#(from \193.232.9.86\data\pms\www\cgi\_config.pm)
	
		#Load HTML templates
		my %Current_state_template;
		tie %Current_state_template, 'SDB::hash2template', "/data/pms/www/templates/common.htm", \@Current_state_TEMPLATE_SECTIONS;

		my $state_href 		= stations::get_station_state_by_proc_id( \%Current_state_template, $ProcID);
			
		$state_href->{html}	=~ /\<font.*?font\>/ ? 
			do{ 
				$subst{state}	= $&; 
			} :
			do{	
				$subst{state}	= '---';
				$subst{tr_bgcolor}	= '#FF9966';
			};
			
		if ( 
			$state_href->{html}	=~ /CONNECTION LOST/	or 
			$state_href->{html}	=~ /long running/		or
			$state_href->{html}	=~ /MESSAGE BOX/
		){
			$subst{tr_bgcolor}	= '#FF9966';
			
				# --- Outline for font ---
					# Synopsis of text-shadow style of CSS:
					# text-shadow: #colour X_shift Y_shift size_of_blurring
				# $subst{state}		= '<font color="#FF9966" style=\'text-shadow: #000 1px 0px 0px, #000 0px 1px 0px, #000 0px -1px 0px, #000 -1px 0px 0px\'>
								# <b>CONNECTION LOST</b>
							# </font>';
				# ------------------------
		}
		
		# ---------------------

	} else {
		$subst{busy_time}	= '---';
		$subst{state}		= '---';
		$subst{tr_bgcolor}	= '#ff0000';
	}
						
	#---------------------------------------------------------- 
	print substitute( $tpl, \%subst );

}

FOOTER:
print $template{table_end};




# Print footer
print $template{footer};


sub compose_option_list($;$)
{
	my %common_template;
	tie %common_template, 'SDB::hash2template', $COMMON_TEMPLATE_FILE, \@COMMON_TEMPLATE_SECTIONS;
	
	my $aref = shift;
	my $selected_option = shift || "";
	my @option_list;
	foreach my $option ( @$aref ) {
		my $t = $option eq $selected_option ? $common_template{selected_option} : $common_template{option};
		push @option_list, substitute( $t, {
			option_name => $option->{text},
			option_value => $option->{value},
			extra_information => $option->{text},
		} );
	}
	return join( "\n", @option_list );
}

sub update_proc_task_info($){
	my $tasks_list = shift;
	my $sql;

	## Delete old process groups information
	remove_proc_task_info( $opt->{proc_id} );

	## Add new process groups info
	foreach my $task_id (split(',', $tasks_list)){
		$sql = "INSERT INTO $PROC_TASK_TABLE 
			(proc_id,task_id) VALUES ( '$opt->{proc_id}','$task_id')";
		$mysql_proci -> do(qq($sql));
	}
}


sub remove_proc_task_info($){
	my $proc_id = shift;
	my $sql="DELETE FROM $PROC_TASK_TABLE 
			WHERE proc_id='$proc_id'";
	$mysql_proci -> do(qq($sql));
}