#!/usr/bin/perl -w
#
# Copyright (c) SMIS-Andry 1999-2004. All rights reserved.
#
# 9/17/2004 13:03

use strict;

use SDB::common;
use SDB::mysql;
use SDB::record;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use SDB::time qw(get_current_date_and_time);
use SDB::mail;

use Data::Dumper;

use DBI;
use proci::db qw( 
	BeginTransaction 
	CommitTransaction 
	GetCachedTableRecordsByKeys 
	my_quotemeta 
	my_quotemeta_special
);
use proci::proci qw(CheckTask); 

### Constants
use proci::_config qw( 
		$TEMPLATE_DIR 
		$COMMON_TEMPLATE_FILE 
		@COMMON_TEMPLATE_SECTIONS
		$TASK_INFO_SCRIPT
		$TASKS_SCRIPT
		$PRINT_CFG_SCRIPT
		$EMPTY_HTML
		$DB
		$HOST
		$USER
		$PASSWORD
);


my $TEMPLATE_FILE = "$TEMPLATE_DIR/tasks.htm";
my @TEMPLATE_SECTIONS = qw( );

### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;

### Global variables

### Functions
sub compose_option_list($;$);
sub update_task_procs_info(%);
sub remove_task_procs_info($);

### Parse query string
my $query_string =  get_query_string();
my %cgi = parse_query_string( $query_string, {continuation => 1} );
map{ $cgi{$_} = undef if $cgi{$_} eq ""} keys %cgi;

### Connect to DB
dbi_connect( "$DB:$HOST", $USER, $PASSWORD );

my $table_info = get_table_info("tasks");
my @fields = @{$table_info->{fields}};
my @keys = @{$table_info->{keys}};	

#----------Extra functionality (Kobetc D.A.)----------
my $choose_task;
if ($cgi{'task_id_choose'}){
	$choose_task=$cgi{'task_id_choose'};
	delete($cgi{'task_id_choose'});
}

if ($cgi{'task_full'}){		#If key exists, then...
	#---
	my %hash;										#Creating hash for 'nPriority' and 'nMaxHours'
	my @task_full=split(/\n/,$cgi{'task_full'});	#Cut 'task_full' for separates strings
	foreach my $str (@task_full){					#Cut each string for parameter and value
		my @parametr=split(/=/,$str);		
		%hash = (%hash, 
				$parametr[0] => $parametr[1]
		);											#Get elements into a hash
	}
	
	#---
	$cgi{nPriority}=$hash{'nPriority'};
	$cgi{nMaxHours}=$hash{'nMaxHours'};
	$cgi{nRequiredMem}=$hash{'nRequiredMem'};
	$cgi{task_name}=$hash{'Title'};
		chop ($cgi{task_name});						#(Remove the newline symbol)
}
#----------------------------------------------------------

### Check and derive parameters

# Rules for task parameters
my @valid_parameters_definitions = map{ $_, '*' } @fields;
# Rules for task parameters

my @aux_parameters = map{ $_, '*' } qw(find_this proc_select procs active_procs others_procs);

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
			remove => ["task_id"],
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
	do_die( "Illegal script parameters: ". get_error->{msg});
}

### Change task information if required
my @active_procs;
@active_procs = split( /,/, $opt->{procs} ) if $opt->{procs};

my @keys_values = map { $opt->{$_} } @keys;
my %task_table_fields_hash;
unless( $opt->{mode} eq "show" ) {
	%task_table_fields_hash = map { $_, defined $opt->{$_} ? my_quotemeta_special( $opt->{$_} ) : undef } @fields;
}


my @curr_time = get_current_date_and_time();
my $curr_date = $curr_time[0];

# do_die(Dumper($opt));

my $alert=0;

my $task_id = $task_table_fields_hash{task_id};
if( $opt->{mode} eq "add" ) {
	
	# --- Chek existing name in DB ---
	my $dbh = DBI->connect(
		"DBI:mysql:proci;193.232.9.86;3306",
		"admin",
		"trambler23"
	) or die "<--Unable to connect to database--> $DBI::errstr\n";

	my ( $task_name ) = $dbh->selectrow_array("
		Select task_name
		FROM tasks
		WHERE tasks.task_name = '$cgi{task_name}'
	");
	# -------------------------------

	# if name is new then...
	unless ( $task_name ) {
		if (! CheckTask($opt->{task_id})) {
				$task_table_fields_hash{ts}="$curr_time[0] $curr_time[1]";
				my $task 	= new SDB::record( $SDB::mysql::DBH, $table_info, \%task_table_fields_hash);
				my $task_id = $task->get_fields()->{task_id};
				BeginTransaction();
				update_task_procs_info( proc_ids => \@active_procs, task_id => $task_id );
				CommitTransaction();
				$choose_task	= $task_id;
				$alert			=1;
		}		
	} else {
		$choose_task	= $task_id;
		$alert			= 2;
	}
	
} elsif( $opt->{mode} eq "update") {
	BeginTransaction();
	my $task = load SDB::record( $SDB::mysql::DBH, $table_info, \@keys_values );
	$task_table_fields_hash{ts}="$curr_time[0] $curr_time[1]";
	$task->update( \%task_table_fields_hash );
	my $task_id = $task->get_fields()->{task_id};
	$choose_task = $task_id;
	update_task_procs_info( proc_ids => \@active_procs, task_id => $task_id );
	CommitTransaction();
	
	$alert=3;
	
} elsif( $opt->{mode} eq "remove") {
	BeginTransaction();
	my $task = load SDB::record( $SDB::mysql::DBH, $table_info, \@keys_values );
	$task->remove;
	remove_task_procs_info($task_id);
	CommitTransaction();
	$choose_task = 0;
	$alert=4;
}

my $ProcInTasksRecords = GetCachedTableRecordsByKeys( table => "proc_task", keys => [qw(proc_id task_id)] );
my $ProcsRecords = GetCachedTableRecordsByKeys( table => "procs", keys => [qw(proc_id)]);

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
my $proc_select='All procs';
#two first element
my @proc_option_list;

push @proc_option_list, {text => 'Любой обработчик', value => 'All procs' };
 
#select proc_option_list
foreach my $proc_id ( sort {$a cmp $b}  keys %{$ProcsRecords} ) {
			my $name=$ProcsRecords->{$proc_id}{proc_name} || $proc_id;
			push @proc_option_list, {text => $name, value => $proc_id };
}

#----------Extra functionality (Kobetc D.A.)----------
#Sort procs by alphabetical order
#"alphabetical_order" - function for sort:
	#"$a" is the first element of massif and "$b" the second
	#-1 - "$a" behind "$b"
	#1 - "$b" behind "$a"
	#0 - it doesn't matter

my ($first_option,@sorted_option)=@proc_option_list;
@sorted_option=sort alphabetical_order @sorted_option;
@proc_option_list=($first_option,@sorted_option);

sub alphabetical_order{
	
	my ($a_)=split(//,$a->{text});
	my ($b_)=split(//,$b->{text});

	$a_= lcfirst $a_;	#Returns with first character in lower-case
	$b_= lcfirst $b_;
	
	if( $a_ gt $b_ ){1}
	elsif( $a_ lt $b_ ){-1}
	else{0}
}
#----------------------------------------------------------

if (defined ($opt->{proc_select})) 
	{	
		$proc_select=$opt->{proc_select};
	}

print STDERR "\n> proc_select $proc_select" if $DEBUG;

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
my $task_table_info = get_table_info( 'tasks' );
my @task_ids;


	
if ($proc_select eq 'All procs') {
	$sql = "SELECT task_id FROM tasks ";
		
} elsif ($proc_select eq 'Without any task')	{
		$sql = "SELECT task_id FROM tasks ";
		 push @query_add, qq(task_id NOT IN (SELECT DISTINCT task_id FROM proc_task) );
		
}
else {
		$sql = "SELECT proc_task.task_id FROM proc_task,tasks";
		 push @query_add, qq(proc_task.proc_id='$proc_select');
		 push @query_add, qq(proc_task.task_id=tasks.task_id);
		
}



if (@query_add) { $sql=$sql.' WHERE '.join(' AND ',@query_add);}
$sql=$sql.' ORDER BY task_name';


print STDERR "\n> $sql" if $SQL_DEBUG;

$sth = mysql_execute( $sql );
while (my $task_id_select=$sth->fetchrow_array) {
				push(@task_ids, $task_id_select);
}


print STDERR "\n> task_ids @task_ids" if $DEBUG;


my $choose_num;
if( $choose_task ) {
	for ( my $i = 0; $i<= $#task_ids; $i++ ) {
		if(  $task_ids[$i] eq $choose_task ) {
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
	add_task_uri =>  $TASK_INFO_SCRIPT."?".compose_query_string( mode => "add" ),
	url_task => $TASKS_SCRIPT, 
	empty_html=>$EMPTY_HTML,
	proc_name =>  $proc_select,
	alert=>$alert,
	
} );


unless( @task_ids ) {

	
	print substitute( $template{table_caption}, {
	url => $TASKS_SCRIPT, 
	add_task_uri =>  $TASK_INFO_SCRIPT."?".compose_query_string( mode => "add" ),
	print_cfg_uri => $PRINT_CFG_SCRIPT,
	find_this =>  $find,
	proc_option_list =>  compose_option_list( \@proc_option_list) ,
	
	
} );
	
	print $template{no_tasks};
	goto FOOTER;
}








# Print tasks table
print substitute( $template{table_caption}, { 
	add_task_uri =>  $TASK_INFO_SCRIPT."?".compose_query_string( mode => "add" ), 
	print_cfg_uri => $PRINT_CFG_SCRIPT,
	proc_option_list =>  compose_option_list( \@proc_option_list) ,
		
	
} );

print $template{table_header};

my $num = 0;
foreach my $task_id (  @task_ids ) {
	$num++;
	my $task = load SDB::record( $SDB::mysql::DBH, $task_table_info, $task_id );
	my $fields_href = $task->get_fields();
	my %subst = map { $_, defined $fields_href->{$_} ? $fields_href->{$_} : "" } keys %$fields_href;
	$subst{num} = $num;
	$subst{update_task_info_uri} = $TASK_INFO_SCRIPT."?".compose_query_string( mode => "update", task_id => $task_id );
	my $tpl = $template{table_row};
	
	
	#----------Extra functionality (Kobetc D.A.)----------
	#Set information about time of last change of directory with task. And drawing fields in the tables 
	
	# Set time of last change of directory and background colour
	if ( $subst{rdy} eq 'Access<br>ERROR' ) {
		$subst{extra_information}	= $subst{directory_last_change};
		$subst{tr_bgcolor}			= '#ffff00';
		$subst{td_bgcolor_error}	= '#ffff00';
	} elsif ( $subst{rdy} eq 'Bad SMB<br>connect' ) {
		$subst{extra_information}	= $subst{directory_last_change};
		$subst{tr_bgcolor}			= '#ffff66';
		$subst{td_bgcolor_error}	= '#ffff66';
	} elsif ( $subst{rdy} eq '' ) {
		$subst{extra_information}	= $subst{directory_last_change};
		$subst{tr_bgcolor}			= '#ffffff';
		$subst{td_bgcolor_error}	= '#ffffff';
	} else {
		
		#---search Flags in "task_full"---
		# Cut the task content into separate. 
		# Cut each string: parameter and value of parameter. Add to hash
			# Flags=0x200	- task turn on
			# Flags=0x2		- task turn off
		my $Flag;
		my @vars	= split( /\n/, $subst{task_full} );
		while ( @vars ) {
			my $var	= shift @vars;
			if ( $var =~ /\[Batch 001\]/) {
				foreach my $var (@vars) {
					if ( $var =~ /Flags=0x(\d+)/ ) {
						$Flag	= $1;
						last;
					}
				}
				last;
			}
		}
		# ------
		
		$subst{extra_information} = 'Последние изменения - '.$subst{directory_last_change}.' суток назад';
		
		if ( $Flag == 200 ) {
			if ( $subst{time_out_update} ) {
				# Drawing based on information about 'Time properties'
				if ( $subst{directory_last_change} * 24 > $subst{time_out_update} ) {
					$subst{tr_bgcolor}	= '#ff9966';
				} else {
					$subst{tr_bgcolor}	= '';
				}
			} elsif ( $subst{directory_last_change} > 1 and $subst{rdy} > 0 ) {
				# Drawing based on information about 'rdy numbers'
				$subst{tr_bgcolor}	= '#ff9966';
			} else {
				# Drawing for other cases
				$subst{tr_bgcolor}	= '';
			}
			
			# Drawing based on information about 'error numbers'
			if ( $subst{error} > 0 ) {
				$subst{td_bgcolor_error}	= '#ff0000';
			} else {
				$subst{td_bgcolor_error}	= '';
			}
		} elsif ( $Flag == 2 ) {
			$subst{tr_bgcolor}			= '#cccccc';
			$subst{td_bgcolor_error}	= '';
		}
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


sub update_task_procs_info(%)
{
	my %opt = @_;
	my $sql;

	# Delete old process groups information
	remove_task_procs_info( $opt{task_id} );

	# Add new process groups info
	foreach my $id ( @{$opt{proc_ids}} ) {
		$sql = "INSERT INTO proc_task VALUES ( '$id','$opt{task_id}')";
		print STDERR "\n> $sql" if $SQL_DEBUG;
		mysql_do( $sql );
	}
}


sub remove_task_procs_info($)
{
	my $task_id = shift;
	my $sql = "DELETE FROM proc_task WHERE task_id='$task_id'";
	print STDERR "\n> $sql" if $SQL_DEBUG;
	mysql_do( $sql );

}