#!/usr/bin/perl -w
#
# Copyright (c) SMIS-Andry 1999-2005. All rights reserved.
#
# 2/9/2005 17:32

use strict;

use SDB::common;
use SDB::mysql;
use SDB::cgi;
use SDB::options qw(get_options);
use SDB::hash2template;
use Data::Dumper;

### Constants
use proci::_config qw( 
	$TEMPLATE_DIR 
	$COMMON_TEMPLATE_FILE 
	@COMMON_TEMPLATE_SECTIONS
	$PROCS_FRAMESET 
	$TASKS_FRAMESET
	$STATISTICS_FRAMESET
	$DB $HOST $PASSWORD $USER
	 
);

use proci::proci qw(WriteProcTask); 

my @valid_titles = qw( header procs tasks statistics);
my $TEMPLATE_FILE = "$TEMPLATE_DIR/header.htm";

### Flags
my $DEBUG = 0;

### Function prototypes

### Global variables
my $alert=0;

dbi_connect( "$DB:$HOST", $USER, $PASSWORD );


### Parse query string
my $query_string =  get_query_string();
my %cgi = parse_query_string( $query_string, {continuation => 1} );

### Check and derive parameters
my $opt = get_options( \%cgi, {
	valid	=> {
		mode	=> [qw(export import) ],
		title	=> \@valid_titles
	},
	required	=> ["title"],
	default		=> { },
} );
unless( defined $opt ) {
	do_die( "Illegal script parameters: ". get_error->{msg} );
}
my $title = $opt->{title};

if ( $opt->{mode} ) {
	if ( $opt->{mode} eq 'export' ) {
		my $ret = WriteProcTask();
		if ( $ret == 1 ) {
			$alert = 1;
		}
	}
}


## Print HTML
print_content_type;

# Load pms header template
my %template;
tie %template, 'SDB::hash2template', $TEMPLATE_FILE;
my %titles = split( /[\s\n\r]*,[\s\r\n]*/, $template{titles} );
foreach( keys %titles ) {
#	$titles{$_} =~ s/^[^\w\d]*(.*?)[^\w\d]*$/$1/;
}
check( exists $titles{$title}, "Title \"\" not found in template" );

print substitute( $template{header}, {
	proci_title => $titles{start},
	alert		=>$alert,
} );


my %first_href	= (
	1	=> [("Обработчики",
			$PROCS_FRAMESET,
			'procs')],
	2	=> [("Задания",
			$TASKS_FRAMESET,
			'tasks')],
	3	=> [("Статистика",
			$STATISTICS_FRAMESET,
			'statistics')],
);

print substitute( $template{proci_start_header}, {
	opt_title	=>$title,
	title		=> $titles{start},
	start_uri	=> $PROCS_FRAMESET,
} );
#

foreach ( sort keys %first_href ) {
	my $url		= $first_href{$_}->[1];
	my $name	= $first_href{$_}->[0];
		
	print substitute( $template{urls}, {
		url		=> $url,
		name	=> $name,
		class	=> ( $opt->{title} eq $first_href{$_}->[2] ) ? 'url_now': 'url_' ,
		title	=> $titles{$first_href{$_}->[2]},
	});		
}


# Print footer
print $template{footer};
