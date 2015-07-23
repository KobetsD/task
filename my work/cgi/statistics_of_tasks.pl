#!/usr/bin/perl -w
#
# Copyright (c) SMIS-Andry 1999-2004. All rights reserved.
#
# 9/17/2004 13:03

use strict;

use SDB::common;
use SDB::mysql;
use SDB::mysql_object;
use SDB::record;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use SDB::time qw(get_current_date_and_time);
use SDB::mail;
use Data::Dumper;

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
		$STATISTIC_OF_TASK_INFO_SCRIPT
		$STATISTICS_OF_TASKS_SCRIPT
		$PRINT_CFG_SCRIPT
		$EMPTY_HTML
		$DB
		$HOST
		$USER
		$PASSWORD
		
		$SESSION_TABLE
		$THREAD_TABLE
);


my $TEMPLATE_FILE = "$TEMPLATE_DIR/statistics_of_tasks.htm";
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
dbi_connect( "$DB:$HOST", $USER, $PASSWORD );	#Connect to proci (use SDB::mysql)
#----------Extra functionality (Êîáåö Ä.À.)----------
my $mysql_proci = new SDB::mysql_object(
	host => $HOST,
	db => $DB,
	user => $USER,
	password => $PASSWORD,
	sql_debug => $SQL_DEBUG,
);												#Connect to proci (use SDB::mysql_object)
#----------------------------------------------------------

### Check and derive parameters
my $rules	= {
	valid	=> {
		mode			=> [qw( show) ],
		thread_numbers	=> '*',
		proc_select 	=> '*',
		task			=> '*',
	},
	relation	=> {
		mode	=> {
			show	=> [ qw() ],
		},
	},
	default => {
		mode 			=> "show",
		thread_numbers	=> 100,
	},
	blank2undef => 1,
};

my $opt = get_options( \%cgi, $rules );
unless( defined $opt ) {
	do_die( "Illegal script parameters: ". get_error->{msg} );
}

if( $opt->{mode} eq "update" ) {
	# Ñïåö èíñòðóêöèÿ íå ñëó÷àé "update"
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

# Print header
print substitute( $template{header}, {
	choose_num			=> 0,
	add_task_uri		=> $STATISTIC_OF_TASK_INFO_SCRIPT."?".compose_query_string( mode => "add" ),
	url_task			=> $STATISTICS_OF_TASKS_SCRIPT, 
	empty_html			=> $EMPTY_HTML,
	proc_name			=> $proc_select,
	alert				=> 0,
	thread_numbers		=> $opt->{thread_numbers}	
} );


unless( @task_ids ) {
	
	print substitute( $template{table_caption}, {
		url					=> $STATISTICS_OF_TASKS_SCRIPT, 
		proc_option_list	=> compose_option_list( \@proc_option_list) ,
	});
	
	print $template{no_tasks};
	goto FOOTER;
}

# Print tasks table
print substitute( $template{table_caption}, { 
	url					=> $STATISTICS_OF_TASKS_SCRIPT, 
	proc_option_list	=> compose_option_list( \@proc_option_list),
});

print $template{table_header};

my $num = 0;
foreach my $task_id (  @task_ids ) {
	$num++;
	my $task = load SDB::record( $SDB::mysql::DBH, $task_table_info, $task_id );
	my $fields_href = $task->get_fields();
	my %subst = map { $_, defined $fields_href->{$_} ? $fields_href->{$_} : "" } keys %$fields_href;
	$subst{num} = $num;
	$subst{update_task_info_uri} = $STATISTIC_OF_TASK_INFO_SCRIPT."?".compose_query_string( 
		# mode			=> "show",
		task_id			=> $task_id,
		thread_numbers	=> $opt->{thread_numbers},
		task_name		=> $subst{task_name}
	);
	my $tpl = $template{table_row};
		
	#----------Extra functionality (Kobetc D.A.)----------
	#Search information about number of error tasks and success tasks  
	
	# Success tasks
	my $sql	= qq(
		SELECT count(*)
		from (
			select
				$THREAD_TABLE.exit_code as exit_code
			FROM 
				$THREAD_TABLE 
					LEFT OUTER JOIN `$SESSION_TABLE` 
					ON $THREAD_TABLE.session_id = `$SESSION_TABLE`.session_id 
				WHERE 
					`$SESSION_TABLE`.task_id = '$subst{task_id}'
				ORDER BY thread_id DESC
				LIMIT $opt->{thread_numbers}
		) as list_of_threads
		where 
			list_of_threads.exit_code = '0'
		);	
			# SELECT COUNT(*)
			# FROM 
			# 	$THREAD_TABLE 
			# 	LEFT OUTER JOIN 
			# 		`$SESSION_TABLE` 
			# 		ON $THREAD_TABLE.session_id = `$SESSION_TABLE`.session_id 
			# WHERE ( `$SESSION_TABLE`.time_start > DATE_SUB( NOW(), INTERVAL $opt->{thread_numbers} HOUR ))
			# 	and `$SESSION_TABLE`.task_id = '$subst{task_id}'
			# 	AND $THREAD_TABLE.exit_code = '0'

	my $sth			= $mysql_proci->execute($sql);
	my ( $Success )	= $sth->fetchrow_array();
	
	# Error tasks
	$sql	= qq(
		SELECT count(*)
		from (
			select
				$THREAD_TABLE.exit_code as exit_code
			FROM 
				$THREAD_TABLE 
					LEFT OUTER JOIN `$SESSION_TABLE` 
					ON $THREAD_TABLE.session_id = `$SESSION_TABLE`.session_id 
				WHERE 
					`$SESSION_TABLE`.task_id = '$subst{task_id}'
				ORDER BY thread_id DESC
				LIMIT $opt->{thread_numbers}
		) as list_of_threads
		where 
			list_of_threads.exit_code != '0'
		);

			# SELECT COUNT(*)
			# FROM 
			# 	$THREAD_TABLE 
			# 	LEFT OUTER JOIN 
			# 		`$SESSION_TABLE` 
			# 		ON $THREAD_TABLE.session_id = `$SESSION_TABLE`.session_id 
			# WHERE ( `$SESSION_TABLE`.time_start > DATE_SUB( NOW(), INTERVAL $opt->{thread_numbers} HOUR ))
			# 	and `$SESSION_TABLE`.task_id = '$subst{task_id}'
			# 	AND $THREAD_TABLE.exit_code != '0'

	$sth			= $mysql_proci->execute($sql);
	my ( $Error )	= $sth->fetchrow_array();
	
	
	if ( $Success or $Error ) {
		
		$subst{success}	= $Success;
		$subst{error}	= $Error;
		
		$subst{extra_information}="";
		
		$subst{tr_bgcolor}='';
		$subst{td_bgcolor_error}='';
		
	} else {
		
		$subst{success}='DB is<br>empty';
		$subst{error}='DB is<br>empty';
		
		$subst{extra_information}="";
		
		$subst{tr_bgcolor}='#ff9966';
		$subst{td_bgcolor_error}='#ff9966';
		
	};
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