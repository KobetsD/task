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
use integer;
use Data::Dumper;

#use lib qw( ../lib );

use proci::db qw( 
	BeginTransaction 
	CommitTransaction 
	GetCachedTableRecordsByKeys 
	my_quotemeta 
	my_quotemeta_special
);

### Constants
use proci::_config qw( 
	$DB
	$HOST
	$PASSWORD
	$USER
	$TEMPLATE_DIR 
	$COMMON_TEMPLATE_FILE @COMMON_TEMPLATE_SECTIONS
	$EMPTY_HTML
	$TASKS_TABLE
	$PROCS_TABLE
	
	$TASKS_SCRIPT
);

use proci::proci qw(CheckTask); 

my $TEMPLATE_FILE = "$TEMPLATE_DIR/task_info.htm";
my @TEMPLATE_SECTIONS = qw( header table_caption task_info table_footer_mode_add table_footer_mode_update table_end empty_list footer);

### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;

### Global variables

### Functions
sub compose_option_list($;$);
sub CheckTask($);

### Parse query string
my $query_string =  get_query_string();
my %cgi = parse_query_string( $query_string, {continuation => 1} );

### Connect to DB
dbi_connect( "$DB:$HOST", $USER, $PASSWORD );


### Obtain mysql table info
my $table_info = get_table_info( $TASKS_TABLE );
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

# Obtain task info
my @keys_values = map { $opt->{$_} } @keys;
my $task_info ;


my @task_procs;

if( $opt->{mode} eq "update") {


	unless( CheckTask($opt->{task_id}) ) {
		print $template{no_such_task};
		do_exit( $RET_OK );
	}



	my $tasks = load SDB::record( $SDB::mysql::DBH, $table_info, \@keys_values );
	$task_info = $tasks->get_fields();
	
	$sql = "SELECT proc_id FROM proc_task WHERE task_id='$task_info->{task_id}'";
	print STDERR "\n> $sql" if $SQL_DEBUG;
	$sth = mysql_execute( $sql );
	while( my $href = $sth->fetchrow_hashref() ) {
			push @task_procs, $href->{proc_id};
	}
	$sth->finish();

	
	
} else {
	$task_info = { map { $_, undef } @fields };
}







### Print HTML


# Compose task info substitutes
my %subst = map { $_, defined $task_info->{$_} ? my_quotemeta_special( $task_info->{$_} ) : "" } keys %$task_info;

# Print header
$subst{mode} = $opt->{mode};
$subst{empty_html} = $EMPTY_HTML;
$subst{task_desc} =~ s/([\n\r]+)/\\n/mg ;

$subst{task_full} =~ s/([\n\r]+)/\\n/mg ;

#do_die(Dumper(\%subst));
print substitute( $template{header}, \%subst );


# Print table caption
print substitute( $template{table_caption}, {url => $TASKS_SCRIPT, } );

print substitute( $template{task_info}, {url => $TASKS_SCRIPT, } );


my (@active_procs_options,@others_procs_options);

$sql = "SELECT proc_id,proc_name FROM $PROCS_TABLE ORDER BY proc_name";
$sth = mysql_execute( $sql );
		
while (my $href=$sth->fetchrow_hashref) {
	my $name = $href->{proc_name} || $href->{proc_id};
	
	if( find_in_list( \@task_procs, $href->{proc_id} ) ) {
			push @active_procs_options, {text => $name, value => $href->{proc_id} };
	} else {
			push @others_procs_options, {text => $name, value => $href->{proc_id} };
	}
		
}
$sth->finish;


# Print procs info
print substitute( $template{task_procs_info}, {
	active_procs_options => compose_option_list( \@active_procs_options ),
	others_procs_options => compose_option_list(\@others_procs_options )
});
#

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
		push @option_list, substitute( $t, {
			option_name => $option->{text},
			option_value => $option->{value},
			extra_information => $option->{text},
		} );
	}
	return join( "\n", @option_list );
}




