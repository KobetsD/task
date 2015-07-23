#!/usr/bin/perl -w
#
# SMIS 
# 12/10/2010 16:18

use strict;

use SDB::common;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use SDB::time qw(get_current_date_and_time);
use SDB::mail;
	
use proci::_config qw(
 	$URL_WWW
 	$CONF_CGI
 	
	$TEMPLATE_DIR 
	
	$COMMON_TEMPLATE_FILE
	@COMMON_TEMPLATE_SECTIONS
);

use workstn_conf qw(
 	workstn_info
 	add_tasks
 	remove_tasks
 	
);


### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;

### Global variables

### Functions
sub compose_option_list($;$);
sub compose_options_from_hash($;$);

my $TEMPLATE_FILE = ( "$TEMPLATE_DIR/configure.htm" );
my @TEMPLATE_SECTIONS = qw(header footer);

### Parse query string
my $query_string =  get_query_string();
my %cgi = parse_query_string( $query_string, {continuation => 1} );
map{ $cgi{$_} = undef if $cgi{$_} eq ""} keys %cgi;

### DB

my @workstn=qw(workstn rule tasks);
my @task=qw(task rule workstns);

my @workstn_parameters = map{ $_, '*' } @workstn;
my @task_parameters = map{ $_, '*' } @task;


my $rules = {
	valid => {
		mode => [qw(t_apply w_apply workstn task) ],
		@workstn_parameters,
		@task_parameters,
		
	},
	relation => {
		mode => {
			w_apply => \@workstn,
			t_apply => \@task,
		},

	},
	default => {
		mode => "workstn",
	},
	blank2undef => 1,
};


my $opt = get_options( \%cgi, $rules);
unless( defined $opt ) {
	do_die( "Illegal script parameters: ". get_error->{msg} );
}

 

# Load template
my %template;
tie %template, 'SDB::hash2template', $TEMPLATE_FILE, \@TEMPLATE_SECTIONS;

my %common_template;
tie %common_template, 'SDB::hash2template', $COMMON_TEMPLATE_FILE, \@COMMON_TEMPLATE_SECTIONS;
	

my $err_code=0;

my @curr_time = get_current_date_and_time();
my $curr_date = $curr_time[0];

print_content_type;

print substitute( $template{header}, {
	url_www=>$URL_WWW,
	url_form=>$CONF_CGI,
	
} );

my %all=(all=>'Все обработчики');

my ($workstns,$tasks)=workstn_info();
my %rule=(
	add=>'Добавить задание',
	remove=>'Удалить задание',
);




if( $opt->{mode} eq "workstn" ) {
	print substitute( $template{workstn}, {
		mode=>'w_apply',
		workstn_options=>compose_options_from_hash(\%all).compose_option_list($workstns),
		rule_options=>compose_options_from_hash(\%rule),
		tasks_options=>compose_option_list($tasks),
	} );
	
}

elsif( $opt->{mode} eq "task" ) {
	print substitute( $template{task}, {
		mode=>'t_apply',
		workstn_options=>compose_option_list($workstns),
		rule_options=>compose_options_from_hash(\%rule),
		tasks_options=>compose_option_list($tasks),
	} );
}
elsif( $opt->{mode} eq "w_apply" ) {
	if ($opt->{rule} eq 'add') {
		add_tasks({workstn=>$opt->{workstn},tasks=>$opt->{tasks}});
	}
	elsif ($opt->{rule} eq 'remove') {
		remove_tasks({workstn=>$opt->{workstn},tasks=>$opt->{tasks}});
	}
	
	
}
elsif( $opt->{mode} eq "t_apply" ) {
	
	
}

	


FOOTER:


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
			#option_name => $option->{text},
			#option_value => $option->{value},
			option_name => $option,
			option_value => $option,
		} );
	}
	return join( "\n", @option_list );
}

sub compose_options_from_hash ($;$)
{
	my %common_template;
	tie %common_template, 'SDB::hash2template', $COMMON_TEMPLATE_FILE, \@COMMON_TEMPLATE_SECTIONS;
	
	my $aref = shift;
	my $selected_option = shift || "";
	my @option_list;
	foreach my $option (keys %$aref ) {
		my $t = $option eq $selected_option ? $common_template{selected_option} : $common_template{option};
		push @option_list, substitute( $t, {
			option_name => $aref->{$option},
			option_value => $option,
		} );
	}
	return join( "\n", @option_list );
}