#!/usr/bin/perl -w
#
###############################################
# 
# write by Dmitry Kobets
###############################################

use strict;

use SDB::common;
use SDB::mysql_object;
use SDB::record;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use integer;
use Time::Local;
use Data::Dumper;

use proci::db qw( 
	BeginTransaction 
	CommitTransaction 
	GetCachedTableRecordsByKeys 
	my_quotemeta 
);

use lib qw(/data/pms/lib);
use stations qw( get_station_state_by_proc_id);

### Constants
use proci::_config qw( 
	$DB 
	$HOST 
	$PASSWORD 
	$USER 
	$TEMPLATE_DIR 
	$COMMON_TEMPLATE_FILE 
	@COMMON_TEMPLATE_SECTIONS
	$EMPTY_HTML
	$PROCS_TABLE
	$TASKS_TABLE
	
	$PROCS_SCRIPT
	
	$DB_pms
  	$USER_pms
	$PASSWORD_pms
);

my $TEMPLATE_FILE = "$TEMPLATE_DIR/proc_info.htm";
my @TEMPLATE_SECTIONS = qw( 
	header 
	table_caption 
	proc_info 
	table_footer_mode_add 
	table_footer_mode_update 
	table_end empty_list 
	footer
);

### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;

### Global variables

### Functions
sub compose_option_list($;$);

### Parse query string
my $query_string =  get_query_string();
my %cgi = parse_query_string( $query_string, {continuation => 1} );

### Connect to DB
my $proci_mysql = new SDB::mysql_object(
	host => $HOST,
	db => $DB,
	user => $USER,
	password => $PASSWORD,
	sql_debug => $SQL_DEBUG,
);												#Connect to proci (use SDB::mysql_object)
my $pms_mysql = new SDB::mysql_object(
	host => $HOST,
	db => $DB_pms,
	user => $USER_pms,
	password => $PASSWORD_pms,
	sql_debug => $SQL_DEBUG,
);												#Connect to pms (use SDB::mysql_object)

### Obtain mysql table info
my $table_info = $proci_mysql->get_table_info($PROCS_TABLE);
my @fields = @{$table_info->{fields}};
my @keys = @{$table_info->{keys}};

### Check and derive parameters
my $opt = get_options( \%cgi, {
	valid => {
		mode => [qw( add update) ],
		lang => [qw( russian english ) ],
		map { $_, "*" } @keys,
	},
	relation => {
		mode => {
			update => [@keys],

		},
	},
	default => {
		lang => "english",
		mode => "add",
	}
} );
unless( defined $opt ) {
	do_die( "Illegal script parameters: ". get_error->{msg} );
}



## Print HTML
print_content_type;

# Load templates
my %template;
tie %template, 'SDB::hash2template', $TEMPLATE_FILE, \@TEMPLATE_SECTIONS;

my %common_template;
tie %common_template, 'SDB::hash2template', $COMMON_TEMPLATE_FILE, \@COMMON_TEMPLATE_SECTIONS;

my $sql;
my $sth;

# Obtain proc info
my @keys_values = map { $opt->{$_} } @keys;
my $proc_info ;


my @proc_tasks;

if( $opt->{mode} eq "update" ) {
	assert( $opt->{proc_id} );
	$sql = "SELECT proc_id from procs WHERE proc_id = '$opt->{proc_id}'";
	assert( $proci_mysql->get_selection( $sql ) );
	
	$sql = "SELECT * FROM procs WHERE proc_id='$keys_values[0]'";
	( $proc_info ) = $proci_mysql->get_selection( $sql );
		
	$sql = "SELECT task_id FROM proc_task WHERE proc_id='$proc_info->{proc_id}'";
	print STDERR "\n> $sql" if $SQL_DEBUG;
	@proc_tasks = $proci_mysql->get_selection( $sql );
	@proc_tasks = map { $_->{task_id} } @proc_tasks;
} else {
	$proc_info = { map { $_, undef } @fields };
}



#----------Current state----------Extra functionality (Kobetc D.A.)----------
my $Current_state_html='---';

$sql=qq(
		SELECT ProcID
		FROM Process
		WHERE Name='$proc_info->{proc_name}'
	);
$sth=$pms_mysql->execute($sql);
my $ProcID=$sth->fetchrow_array();	#value of the field 'ProcID' in 'Process' of table 'pms'
	
if ($ProcID) {

	my @Current_state_TEMPLATE_SECTIONS = qw( copyright );	#(from \193.232.9.86\data\pms\www\cgi\_config.pm)
	
	#Load HTML templates
	my %Current_state_template;
	tie %Current_state_template, 'SDB::hash2template', "/data/pms/www/templates/common.htm", \@Current_state_TEMPLATE_SECTIONS;
	
	my $state_href = stations::get_station_state_by_proc_id( \%Current_state_template, $ProcID);
	
	$Current_state_html = $state_href->{html};
	$Current_state_html =~ s/<nobr>/<BR><nobr>/g;
	
}
#----------------------------------------------------------------------------



### Print HTML


# Compose proc info substitutes
my %subst = map { $_, defined $proc_info->{$_} ? my_quotemeta( $proc_info->{$_} ) : "" } keys %$proc_info;

# Print header
$subst{mode} = $opt->{mode};
$subst{empty_html} = $EMPTY_HTML;
$subst{proc_desc} =~ s/([\n\r]+)/\\n/mg ;

print substitute( $template{header}, \%subst );


# Print table caption
print substitute( $template{table_caption}, {
	url => $PROCS_SCRIPT, 
	#----------Extra functionality (Kobetc D.A.)----------
	#task_id => $task_id
	#-----------------------------------------------------
} );

print substitute( $template{proc_info}, {
		url => $PROCS_SCRIPT, 
		#----------Extra functionality (Kobetc D.A.)----------
		current_state => $Current_state_html,
		#-----------------------------------------------------
} );

my (@active_tasks_options,@others_tasks_options);
my $time_of_last_change;#time of last change of select directory

$sql = "SELECT task_id,task_name,task_full,nPriority FROM $TASKS_TABLE ORDER BY task_name";

foreach my $href ($proci_mysql->get_selection( $sql )) {
	my $name = $href->{task_name} || $href->{task_id};
		
	if( find_in_list( \@proc_tasks, $href->{task_id} ) ) {
			push @active_tasks_options, {text => $name, 
										value => $href->{task_id}, 
										nPriority => $href->{nPriority},
										};
	} else {
			push @others_tasks_options, {text => $name, 
										value => $href->{task_id},
										nPriority => $href->{nPriority},
										};
	}
		
}


#----------Extra functionality (Kobetc D.A.)----------
#Sort tasks by priority
#"priority" - function for sort:
	#"$a" is the first element of massif and "$b" the second
	#-1 - "$a" behind "$b"
	#1 - "$b" behind "$a"
	#0 - it doesn't matter
sub priority{
	if($a->{nPriority}>$b->{nPriority}){-1}
	elsif($a->{nPriority}<$b->{nPriority}){1}
	else{0}
}

@active_tasks_options=sort priority @active_tasks_options;
@others_tasks_options=sort priority @others_tasks_options;


#Search "$task_id" of selected element, after frame is rebooting
# my $selected;

# foreach (@active_tasks_options,@others_tasks_options){
	# if ($_->{value}==$task_id){
		# $selected=$_;
	# }
# }
#----------------------------------------------------------

# Print tasks info
print substitute( $template{proc_tasks_info}, {
	active_tasks_options => compose_option_list(\@active_tasks_options),
	others_tasks_options => compose_option_list(\@others_tasks_options),
	#----------Extra functionality (Kobetc D.A.)----------
	#task_full_text => $task_full
	#-----------------------------------------------------
});



if( $opt->{mode} eq "update" ) {
	print $template{table_footer_mode_update};
}
 elsif( $opt->{mode} eq "add" ) {
	print $template{table_footer_mode_add};
} else {
	assert( 0, "Illegal mode \"$opt->{mode}\"" );
}


print $template{table_end};

# Print footer
print $template{footer};


# Functions


sub compose_option_list($;$)
{
	my %common_template;
	tie %common_template, 'SDB::hash2template', $COMMON_TEMPLATE_FILE, \@COMMON_TEMPLATE_SECTIONS;

	my $aref = shift;
	my $selected_option = shift || "";
	my @option_list;
	foreach my $option ( @$aref ) {
		my $t = $option eq $selected_option ? $common_template{selected_option} : $common_template{option};
		$option->{nPriority}=sprintf "%03d",$option->{nPriority};	#Returns a formatted string (like 10 -> 010) 
		push @option_list, substitute( $t, {
			option_name => $option->{nPriority}.' - '.$option->{text},
			option_value => $option->{value},
			extra_information => $option->{text},
		} );
	}
	return join( "\n", @option_list );
}



