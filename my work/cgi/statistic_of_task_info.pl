#!/usr/bin/perl -w
#
# Kobets Dmitry - IKI
#
# 07/02/2014

use strict;

use SDB::common;
use SDB::mysql_object;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use integer;
use Data::Dumper;

### Constants
use proci::_config qw( 
	$DB
	$HOST
	$PASSWORD
	$USER
	
	$STATISTIC_OF_TASK_INFO_SCRIPT
	
	$TEMPLATE_DIR 
	$COMMON_TEMPLATE_FILE
	@COMMON_TEMPLATE_SECTIONS

	$SESSION_TABLE
	$THREAD_TABLE
	$PROCESS_TABLE
	$TASKS_TABLE
	$PROCS_TABLE
);

my $TEMPLATE_FILE		= "$TEMPLATE_DIR/statistic_of_task_info.htm";
my @TEMPLATE_SECTIONS	= qw( 
	header
	bar_chart_start
	bar_chart_data
	bar_chart_element
	bar_chart_element_end
	bar_chart_data_end
	bar_chart_specification_start
	bar_chart_specification_gragh
	bar_chart_specification_end
	submit_init_start
	submit_init_dar_chart_3D
	submit_init_end
	google_chart_start
	gragh_data
	gragh_element
	gragh_element_end
	gragh_draw
	timeline_data
	timeline_element
	timeline_element_end
	timeline_options_start
	timeline_options_color_start
	timeline_options_color_set
	timeline_options_color_end
	timeline_options_end
	timeline_draw
	google_chart_end
	Body
	Body_empty_database
	Body_select
	END
);


my %exit_code_list_default = (
	0 => {
		'color'		=> '#ccff99',
		'name'		=> 'Success'
	},
	3 => {
		'color'		=> '#ffff99',
		'name'		=> 'CASCADE EXIT'
	},
	65479 => {
		'color'		=> '#ff9900',
		'name'		=> 'NOT GET EXIT CODE'
		
	},
	65497 => {
		'color'		=> '#ff9900',
		'name'		=> 'Killed'
	},
	65519 => {
		'color'		=> '#ff9900',
		'name'		=> 'UNKilled'
	},
	65521 => {
		'color'		=> '#ff9900',
		'name'		=> 'Unstarted'
	},
);

### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;

### Global variables

### Functions
sub compose_option_list($;$);
sub alphabetical_order;


### Parse query string
my $query_string =  get_query_string();
my %cgi = parse_query_string( $query_string, {continuation => 1} );

### Connect to DB proci (use SDB::mysql_object)
my $mysql_proci = new SDB::mysql_object(
	host		=> $HOST,
	db			=> $DB,
	user		=> $USER,
	password	=> $PASSWORD,
	sql_debug	=> $SQL_DEBUG,
);

### Check and derive parameters
	
	# Obtain mysql table info
	my $href = $mysql_proci->get_table_info( $TASKS_TABLE );

my $opt = get_options( \%cgi, {
	valid		=> {
		mode			=> '*',
		thread_numbers	=> '*',
		map { $_, "*" } @{$href->{fields}},
		selected_option	=> '*',
	},
	relation	=> {},
	default		=> {
		mode			=> {
			chartdiv	=> 'show',
			gragh		=> 'show',
			selects		=> 'show',
		},
		selected_option	=> 0,
	}
} );
unless( defined $opt ) {
	do_die( "Illegal script parameters: ". get_error->{msg} );
}

# --------- Get list of processs -------------
	#---
	my %bar_chart_processes_list_statistics;
	#---
my $sql	= qq(
	SELECT 
		$PROCESS_TABLE.`process`, 
		$PROCESS_TABLE.exit_code, 
		SUM( UNIX_TIMESTAMP( $PROCESS_TABLE.time_finish ) - UNIX_TIMESTAMP( $PROCESS_TABLE.time_start ) ) as time,
		COUNT(*) as number
	from (
		select
			$THREAD_TABLE.thread_id as thread_id
		FROM
			thread
				LEFT OUTER JOIN $SESSION_TABLE 
				ON $THREAD_TABLE.session_id = $SESSION_TABLE.session_id 
		WHERE 
			$SESSION_TABLE.task_id = '$opt->{task_id}'
		ORDER BY thread_id DESC
		LIMIT $opt->{thread_numbers}
	) as list_of_threads
		LEFT OUTER JOIN $PROCESS_TABLE
		on $PROCESS_TABLE.thread_id = list_of_threads.thread_id
	WHERE 
		$PROCESS_TABLE.time_finish is not NULL
	GROUP BY 
		$PROCESS_TABLE.`process`, 
		$PROCESS_TABLE.exit_code
);
	
foreach my $element ( $mysql_proci->get_selection( $sql ) ) {
	push 
		@{ $bar_chart_processes_list_statistics{$element->{process}} }, 
		{
			exit_code	=> $element->{exit_code},
			time		=> $element->{time},
			number		=> $element->{number}
		};
}
# Structure of element:
	# (
	# name of process	=> [
		# {
			# 'exit_code'	=> exit code
			# 'number'		=> number of process with this exit code
			# 'time'		=> number of seconds of processing these processes
		# },
		# ...
	# ],
	# name of next process => [],
	# ...
	# )

unless ( %bar_chart_processes_list_statistics ) {
	$opt->{mode}{chartdiv} = "not_show";
}
# -------------------------------------------

# --- Get list of threads ---
	#---
	my @main_timeline_threads_list_statistics;
	#---
$sql	= qq(
	select *
	from (
		select
			$THREAD_TABLE.thread_id   as thread_id,
			$THREAD_TABLE.exit_code   as exit_code, 
			$THREAD_TABLE.time_start  as time_start,
			$THREAD_TABLE.time_finish as time_finish
		FROM
			thread
				LEFT OUTER JOIN $SESSION_TABLE 
				ON $THREAD_TABLE.session_id = $SESSION_TABLE.session_id 
		WHERE 
			$SESSION_TABLE.task_id = '$opt->{task_id}' and
			$THREAD_TABLE.time_finish is not NULL			
		ORDER BY thread_id DESC
		LIMIT $opt->{thread_numbers}
	) as list_of_threads
	ORDER BY list_of_threads.exit_code	
);

@main_timeline_threads_list_statistics	= $mysql_proci->get_selection( $sql );
# Structure of element:
# (
# 	{
# 		'file_name'		=> Name of thread
# 		'exit_code'		=> Exit code of thread
#		'time_start'	=> Time of thread's start
# 		'time_finish'	=> Time of thread's finish
#	},
# 	...
# )

unless ( @main_timeline_threads_list_statistics ) {
	$opt->{mode}{chartdiv}	= "not_show";
}
# ---------------------------

# -------- Get exit code process's list from DB ----------
	# ---
	my @bar_chart_processes_exit_code_list;
	# ---
$sql	= qq(
	select 
		DISTINCT `$PROCESS_TABLE`.exit_code
	from (
		select
			$THREAD_TABLE.thread_id as thread_id
		FROM
			thread
				LEFT OUTER JOIN $SESSION_TABLE 
				ON $THREAD_TABLE.session_id = $SESSION_TABLE.session_id 
		WHERE 
			$SESSION_TABLE.task_id = '$opt->{task_id}'
		ORDER BY thread_id DESC
		LIMIT $opt->{thread_numbers}
	) as list_of_threads
		LEFT OUTER JOIN $PROCESS_TABLE
		ON list_of_threads.thread_id = $PROCESS_TABLE.thread_id 
	WHERE
		$PROCESS_TABLE.time_finish is not NULL	
	ORDER BY $PROCESS_TABLE.exit_code
);
	
@bar_chart_processes_exit_code_list	= $mysql_proci->get_selection( $sql );

unless ( @bar_chart_processes_exit_code_list ) {
	$opt->{mode}{chartdiv} = "not_show";
}
#-------------------------------------------

#---------- Get list of processes for gragh -------------
	#---
	my @main_gragh_processes_edges;
	#---
$sql	= qq(
	select DISTINCT 
		`$PROCESS_TABLE`.`process`,
		`$PROCESS_TABLE`.`parent_process`
	from (
		select
			$THREAD_TABLE.thread_id as thread_id
		FROM
			thread
				LEFT OUTER JOIN $SESSION_TABLE 
				ON $THREAD_TABLE.session_id = $SESSION_TABLE.session_id 
		WHERE 
			$SESSION_TABLE.task_id = '$opt->{task_id}'
		ORDER BY thread_id DESC
		LIMIT $opt->{thread_numbers}
	) as list_of_threads
		LEFT OUTER JOIN $PROCESS_TABLE
		ON list_of_threads.thread_id = $PROCESS_TABLE.thread_id 
	WHERE
		$PROCESS_TABLE.time_finish is not NULL	
);

@main_gragh_processes_edges	= $mysql_proci->get_selection( $sql );
# Structure of element:
	# (
	# 	{
	# 		'parent_process'	=> parent's process's name
	# 		'process'			=> process's name
	# 	},
	# 	...
	# )

	
unless ( @main_gragh_processes_edges ) {
	$opt->{mode}{gragh} = "not_show";
} else {
	# Set unique name
	my %temp_hash;
	foreach my $number ( 0 .. $#main_gragh_processes_edges ) {
		# parent_process named
		$main_gragh_processes_edges[$number]->{parent_process} = 
			$main_gragh_processes_edges[$number]->{parent_process}.' ('.do{ $temp_hash{$main_gragh_processes_edges[$number]->{parent_process}} || 1}.')';
		
		$temp_hash{$main_gragh_processes_edges[$number]->{process}}	+= 1;
		
		# process named
		$main_gragh_processes_edges[$number]->{process} = $main_gragh_processes_edges[$number]->{process}.' ('.$temp_hash{$main_gragh_processes_edges[$number]->{process}}.')';
	}
}
#------------------------------------------------------

#----------Get error list from DB-----------
	# ---
	my @select_threads_list;
	# ---
$sql	= qq(
	SELECT 
		list_of_threads.thread_id,
		list_of_threads.file_name
	from (
		select
			$THREAD_TABLE.thread_id as thread_id,
			$THREAD_TABLE.file_name as file_name,
			$THREAD_TABLE.exit_code as exit_code
		FROM 
			$THREAD_TABLE 
				LEFT OUTER JOIN `$SESSION_TABLE` 
				ON $THREAD_TABLE.session_id = `$SESSION_TABLE`.session_id 
			WHERE 
				`$SESSION_TABLE`.task_id = '$opt->{task_id}'
			ORDER BY thread_id DESC
			LIMIT $opt->{thread_numbers}
	) as list_of_threads
	where 
		list_of_threads.exit_code != '0'
	ORDER BY list_of_threads.thread_id
);
	
@select_threads_list	= $mysql_proci->get_selection( $sql );
	# (
 	#	{
	# 		'thread_id' => id of thread
	# 		'file_name' => name of file
    #   },
	# 	...
	# )
unless ( @select_threads_list ) {
	$opt->{mode}{selects} = "not_show";
} else {
	if ( $opt->{selected_option} == 0 ) {
		$opt->{selected_option}	= $select_threads_list[0]->{thread_id};
	}
}
#-------------------------------------------


# --- Get gragh of selected error files ---
	#---
	my @error_gragh_processes_edges_and_statistics;
	#---
if ( $opt->{mode}{selects} eq "show" ) {

	$sql	= qq(
		SELECT 
			`$PROCESS_TABLE`.`process`												as `process`,
			`$PROCESS_TABLE`.`parent_process`										as `parent_process`,
			`$PROCESS_TABLE`.`error_log`											as `error_log`,
			ifnull( `$PROCESS_TABLE`.`exit_code`, 65479 )							as `exit_code`,
			`$PROCESS_TABLE`.`time_start`											as `time_start`,
			ifnull( `$PROCESS_TABLE`.`time_finish`, `$PROCESS_TABLE`.`time_start`)	as `time_finish`,
			`$SESSION_TABLE`.station_name											as station_name
		FROM 
			`$PROCESS_TABLE`
			LEFT OUTER JOIN 
				$THREAD_TABLE 
				ON `$PROCESS_TABLE`.thread_id = $THREAD_TABLE.thread_id
				LEFT OUTER JOIN 
					`$SESSION_TABLE` 
					ON $THREAD_TABLE.session_id = `session`.session_id 
		WHERE `$SESSION_TABLE`.task_id = '$opt->{task_id}'
			and $THREAD_TABLE.thread_id = '$opt->{selected_option}'
		ORDER BY `$PROCESS_TABLE`.time_start
	);
			# * - exit_code = 65479 - 'NOT GET EXIT CODE'


	@error_gragh_processes_edges_and_statistics	= $mysql_proci->get_selection( $sql );

	# Structure of element:
		# (
		# 	{
		# 		'parent_process'	=> parent's process's name
		# 		'process'			=> process's name
		#		'error_log' 		=> process's log
        #		'exit_code' 		=> process's exit code
		# 		'time_start' 		=> process's time start
		# 		'time_finish' 		=> process's time finish
		# 		'station_name' 		=> station that is processing process
		# 	},
		# 	...
		# )

	# Set unique name
	my %temp_hash;
	foreach my $number ( 0 .. $#error_gragh_processes_edges_and_statistics ) {
		# parent_process named
		$error_gragh_processes_edges_and_statistics[$number]->{parent_process} = 
		$error_gragh_processes_edges_and_statistics[$number]->{parent_process}.' ('.do{ $temp_hash{$error_gragh_processes_edges_and_statistics[$number]->{parent_process}} || 1}.')';
	
		$temp_hash{$error_gragh_processes_edges_and_statistics[$number]->{process}}	+= 1;
	
		# process named
		$error_gragh_processes_edges_and_statistics[$number]->{process} = $error_gragh_processes_edges_and_statistics[$number]->{process}.' ('.$temp_hash{$error_gragh_processes_edges_and_statistics[$number]->{process}}.')';
	}

}
# -----------------------------------------

# Load templates
my %template;
tie %template, 'SDB::hash2template', $TEMPLATE_FILE, \@TEMPLATE_SECTIONS;

### Print HTML
print_content_type;

# Print header
print substitute( 
	$template{header},
	{} 
);

# Print header
if ( $opt->{mode}{chartdiv} eq "show") {
	
	# --- Print Bar chart ---
	# Print bar_chart_start
	print substitute( 
		$template{bar_chart_start},
		{}
	);
	
	foreach my $script ( sort alphabetical_order keys %bar_chart_processes_list_statistics ) {
		
		#script - Cut every 9 symbols and past "\n" behind them
		print substitute( $template{bar_chart_data}, {
			script	=> join ( '\n', grep {$_ ne ''} split( /(.........)/, $script ) ), 
		});
		
		foreach my $kind ( 0 .. $#{$bar_chart_processes_list_statistics{$script}} ) {
			print substitute( $template{bar_chart_element}, {
			exit_code	=> ${$bar_chart_processes_list_statistics{$script}}[$kind]->{exit_code},
			numbers		=> ${$bar_chart_processes_list_statistics{$script}}[$kind]->{number},	
		});
		}
		
		# Print bar_chart_element_end
		print substitute( 
			$template{bar_chart_element_end},
			{}
		);
	}

	# Print bar_chart_data_end
	print substitute( 
		$template{bar_chart_data_end},
		{}
	);
	
	
		# --- Bar chart specification ---
			
		# Print bar_chart_specification_start
		print substitute( 
			$template{bar_chart_specification_start}, 
			{}
		);
		
		# Print bar_chart_specification_gragh
		foreach my $code ( @bar_chart_processes_exit_code_list ) {
			print substitute( 
			$template{bar_chart_specification_gragh}, 
			{
				exit_code_title			=> 
					'exit code - '.$code->{exit_code}.' - '.($exit_code_list_default{$code->{exit_code}}->{name} || 'Error'),
				exit_code_valueField	=> $code->{exit_code},
				color					=> $exit_code_list_default{$code->{exit_code}}->{color}	|| '#FF0000'
			}
		);
		}
		
		# Print bar_chart_specification_end
		print substitute( 
			$template{bar_chart_specification_end}, 
			{}
		);
		# -------------------------------
	# -----------------------

	
	# --- Submit and Init ---
	# Print submit_init_start
	print substitute( 
		$template{submit_init_start}, 
		{}
	);
	
	# Print submit_init_dar_chart_3D
	print substitute( 
		$template{submit_init_dar_chart_3D},
		{}
	);
	
	# Print submit_init_end
	print substitute( $template{submit_init_end}, {
		thread_numbers		=> $opt->{thread_numbers},
		task_name	=> $opt->{task_name},
		task_id		=> $opt->{task_id},
	});
	# -----------------------
	
	# --- Gragh and timeline ---
	
		# --- Gragh main ---
		# Print google_chart_start
		print substitute( 
			$template{google_chart_start},
			{}
		);
		
		# Print gragh_data
		print substitute( 
			$template{gragh_data},
			{
				gragh_data	=> 'main_structure_gragh_data'
			}
		);
		
		# Print gragh_element
		foreach my $edge ( @main_gragh_processes_edges ) {
			print substitute( 
				$template{gragh_element},
				{
					process			=> $edge->{process},
					parent_process	=> $edge->{parent_process},
					extra			=> ''
				}
			);
		}
		
		# Print gragh_element_end
		print substitute( 
			$template{gragh_element_end},
			{}
		);
		
		# Print gragh_draw
		print substitute( 
			$template{gragh_draw},
			{
				gragh		=> 'main_structure_gragh',
				gragh_chart	=> 'main_structure_chart',
				gragh_data	=> 'main_structure_gragh_data'
			}
		);
		# ------------------
		
		# --- Gragh error ---
		if ( $opt->{mode}{selects} eq "show" ) {
			# Print gragh_data
			print substitute( 
				$template{gragh_data},
				{
					gragh_data	=> 'error_structure_gragh_data'
				}
			);
			
			# Print gragh_element
			foreach my $edge ( @error_gragh_processes_edges_and_statistics ) {
				$edge->{error_log} =~ s/[\n|\s]/_/g;
				$edge->{error_log} =~ s/['|"]/\\$&/g;

				print substitute( 
					$template{gragh_element},
					{
						process			=> $edge->{process},
						parent_process	=> $edge->{parent_process},
						extra			=> $edge->{error_log} 
					}
				);
			}
			
			# Print gragh_element_end
			print substitute( 
				$template{gragh_element_end},
				{}
			);
			
			# Print gragh_draw
			print substitute( 
				$template{gragh_draw},
				{
					gragh		=> 'error_structure_gragh',
					gragh_chart	=> 'error_structure_chart',
					gragh_data	=> 'error_structure_gragh_data'
				}
			);
		}
		# -------------
		
		# --- Timeline main ---
		# Print timeline_data
		print substitute( 
			$template{timeline_data},
			{
				container		=> 'main_timeline_container',
				timeline		=> 'main_timeline',
				timeline_chart	=> 'main_timeline_chart',
				dataTable		=> 'main_timeline_dataTable'
			}
		);
		
		# Print timeline_element
		foreach my $thread ( @main_timeline_threads_list_statistics ) {
			print substitute( 
				$template{timeline_element},
				{
					group	=> $thread->{exit_code},
					name	=> $thread->{thread_id},
					start	=> do { 
							my @tmp	= split ( /[-| |:]/, $thread->{time_start} );
							# Correcting form of month - ( 0 .. 11 )
							$tmp[1]	-= 1;
							join( ',', @tmp );
						},
					end		=> do { 
							my @tmp	= split ( /[-| |:]/, $thread->{time_finish} );
							# Correcting form of month - ( 0 .. 11 )
							$tmp[1]	-= 1;
							join( ',', @tmp );
						}
				}
			);
		}
		
		# Print timeline_element_end
		print substitute( 
			$template{timeline_element_end},
			{}
		);
		
		# Print timeline_options_start
		print substitute( 
			$template{timeline_options_start},
			{
				options			=> 'main_timeline_options',
				groupByRowLabel	=> 'true'
			}
		);
		
		# Print timeline_options_color_start
		print substitute( 
			$template{timeline_options_color_start}, 
			{}
		);
		
		# Print timeline_options_color_set
		foreach my $thread ( @main_timeline_threads_list_statistics ) {
			print substitute( 
				$template{timeline_options_color_set},
				{
					color	=> $exit_code_list_default{$thread->{exit_code}}->{color}	|| '#FF0000',
				}
			);
		}

		# Print timeline_options_color_end
		print substitute( 
			$template{timeline_options_color_end}, 
			{}
		);
		
		# Print timeline_options_end
		print substitute( 
			$template{timeline_options_end}, 
			{}
		);
		
		# Print timeline_draw
		print substitute( 
			$template{timeline_draw},
			{
				timeline_chart	=> 'main_timeline_chart',
				dataTable		=> 'main_timeline_dataTable',
				options			=> 'main_timeline_options',
			}
		);
		# ---------------------
		
		# --- Timeline error ---
		# Print timeline_data
		print substitute( 
			$template{timeline_data},
			{
				container		=> 'error_timeline_container',
				timeline		=> 'error_timeline',
				timeline_chart	=> 'error_timeline_chart',
				dataTable		=> 'error_timeline_dataTable'
			}
		);
		
		# Print timeline_element
		foreach my $process ( @error_gragh_processes_edges_and_statistics ) {
			print substitute( 
				$template{timeline_element},
				{
					group	=> $process->{exit_code},
					name	=> $process->{process},
					start	=> do { 
							my @tmp	= split ( /[-| |:]/, $process->{time_start} );
							# Correcting form of month - ( 0 .. 11 )
							$tmp[1]	-= 1;
							join( ',', @tmp );
						},
					end		=> do { 
							my @tmp	= split ( /[-| |:]/, $process->{time_finish} );
							# Correcting form of month - ( 0 .. 11 )
							$tmp[1]	-= 1;
							join( ',', @tmp );
						}
				}
			);
		}

		# Print timeline_element_end
		print substitute( 
			$template{timeline_element_end},
			{}
		);
		
		# Print timeline_options_start
		print substitute( 
			$template{timeline_options_start},
			{
				options			=> 'error_timeline_options',
				groupByRowLabel	=> 'false'
			}
		);
		
		# Print timeline_options_color_start
		print substitute( 
			$template{timeline_options_color_start}, 
			{}
		);
		
		# Print timeline_options_color_set
		foreach my $process ( @error_gragh_processes_edges_and_statistics ) {
			print substitute( 
				$template{timeline_options_color_set},
				{
					color	=> $exit_code_list_default{$process->{exit_code}}->{color}	|| '#FF0000',
				}
			);
		}
		
		# Print timeline_options_color_end
		print substitute( 
			$template{timeline_options_color_end}, 
			{}
		);
		
		# Print timeline_options_end
		print substitute( 
			$template{timeline_options_end}, 
			{}
		);
		
		# Print timeline_draw
		print substitute( 
			$template{timeline_draw},
			{
				timeline_chart	=> 'error_timeline_chart',
				dataTable		=> 'error_timeline_dataTable',
				options			=> 'error_timeline_options',
			}
		);
		# ---------------------
		
		# Print google_chart_end
		print substitute( 
			$template{google_chart_end},
			{}
		);
	
	# ------------------------------------
	
	
} else {
	
	# Print submit_init_start
	print substitute( 
		$template{submit_init_start},
		{} 
	);
	
	# Print submit_init_end
	print substitute( 
		$template{submit_init_end}, 
		{
			thread_numbers		=> $opt->{thread_numbers},
			task_name	=> $opt->{task_name},
			task_id		=> $opt->{task_id},
		}
	);
	
}

# Print bar_chart and timeline
if ($opt -> {mode}{chartdiv} eq "show") {
	
	# Print Body
	print substitute( $template{Body}, {
		task_name	=> $opt->{task_name},
		url			=> $STATISTIC_OF_TASK_INFO_SCRIPT,
		timeline	=> 'main_timeline',
		gragh		=> 'main_structure_gragh'
	});

}else{
	# Print Body_empty_database
	print substitute( $template{Body_empty_database}, {});
}

# Print Body_select
if ( $opt -> {mode}{selects} eq "show" ) {
	print substitute( $template{Body_select}, {
		thread_id			=> $opt->{selected_option},
		file_name			=> do{ 
			my ( $selected_option ) = grep { 
				$_->{thread_id} == $opt->{selected_option} 
			} @select_threads_list;
			$selected_option->{file_name};
		},
		station_name		=> $error_gragh_processes_edges_and_statistics[0]->{station_name} || 'unknown station',
		error_list_options	=> compose_option_list( \@select_threads_list, $opt->{selected_option} ),
		gragh				=> 'error_structure_gragh',
		timeline			=> 'error_timeline',
	});
}

# Print END
print substitute( $template{END}, {} );

# ------------------------------------------------------------------------------------------------

### Functions ###
sub compose_option_list($;$)
{
	my %common_template;
	tie %common_template, 'SDB::hash2template', $COMMON_TEMPLATE_FILE, \@COMMON_TEMPLATE_SECTIONS;

	my $aref = shift;
	my $selected_option = shift || "";
	my @option_list;
	foreach my $option ( @$aref ) {
		my $t = $option->{thread_id} eq $selected_option ? $common_template{selected_option} : $common_template{option};
		push @option_list, substitute( $t, {
			option_name			=> "$option->{thread_id}: $option->{file_name}",
			option_value		=> $option->{thread_id},
			extra_information	=> $option->{file_name},
		} );
	}
	return join( "\n", @option_list );
}


sub alphabetical_order{
	#"$a" is the first element of massif and "$b" the second
	#-1 - "$a" behind "$b"
	#1 - "$b" behind "$a"
	#0 - it doesn't matter

	if(		$a gt $b ){ 1 }
	elsif(	$a lt $b ){ -1 }
	else{ 0 }
}