#!C:\strawberry\perl\bin\perl

use strict;

use lib "C:\\conf";

use common;
use cgi;
use options qw(get_options);
use hash2template;
# use integer;
use DBI;
use Data::Dumper;
use POSIX qw(ceil);

### Constants

use _config qw( 
	$DB
	$HOST
	$PASSWORD
	$USER
);

my $TEMPLATE_FILE		= "..\\..\\htdocs\\task_1\\task_1.htm";
my @TEMPLATE_SECTIONS	= qw( 
	header
	script
	Body
	checkbox
	TABLE_head
	TABLE_TR
	TABLE_end
	end
);

### Functions
sub order;


### Parse query string
my $query_string =  get_query_string();
my %cgi			 = parse_query_string( $query_string, {continuation => 1} );

### Connect to DB
my $dbh	=	DBI->connect(
	"DBI:mysql:$DB;$HOST;3306",
	$USER,
	$PASSWORD
) or die "<--Unable to connect to database--> $DBI::errstr\n";

### Check and derive parameters
my $opt = get_options( \%cgi, {
	valid		=> {
		input_in	=> '*',
		input_out	=> '*',
		id 			=> '*'
	},
	default		=> {
		input_in	=> 'true',
		input_out	=> 'true',
		id 			=> 0
	}
} );
unless( defined $opt ) {
	do_die( "Illegal script parameters: ". get_error->{msg} );
}
# -----------------------------------------

my $hash = {
	true => '=',
	false => '!='
};

my $sth;
my $all_lines;
if ( $opt->{id} != 0  ){
	# Select all lines from DB
	$sth	= $dbh->prepare("
		SELECT *
		FROM board
		where 
			id =  $opt->{id}
	");
	$sth->execute();
	
	# Data selection to array reference
	$all_lines = $sth->fetchall_arrayref();

} else {
	unless (
		$opt->{input_in} eq 'false' and
		$opt->{input_out} eq 'false'
	) {
		# Select all lines from DB
		$sth	= $dbh->prepare("
			SELECT *
			FROM board
			where 
				flight_type $hash->{$opt->{input_in}} 'прилет' or
				flight_type $hash->{$opt->{input_out}} 'вылет'
		");
		$sth->execute();

		# Data selection to array reference
		$all_lines = $sth->fetchall_arrayref();
	}

	# Sorting by time
	@{$all_lines} = sort order @{$all_lines};
}

# -----------------------------------------

# Load templates
my %template;
tie %template, 'hash2template', $TEMPLATE_FILE, \@TEMPLATE_SECTIONS;

### Print HTML
print_content_type;

# Print header
print substitute( 
	$template{header},
	{} 
);

# Print submit_init_start
print substitute( 
	$template{script},
	{
		out	=> $opt->{input_out},
		in	=> $opt->{input_in}
	} 
);

print substitute( 
	$template{Body}, 
	{}
);

unless( $opt->{id} != 0 ){
	print substitute( 
		$template{checkbox}, 
		{}
	);
}


print substitute( 
	$template{TABLE_head}, 
	{}
);

foreach my $number ( 0 .. $#{$all_lines} ) {
	print substitute( 
		$template{TABLE_TR}, 
		{
			id 				=> $all_lines->[$number][9],
			tr_bgcolor		=> ( '#D9D9D9', '#F2F2F2' )[ceil($number%2)],
			flight_type		=> $all_lines->[$number][0],
			flight			=> $all_lines->[$number][1],
			airline			=>  $all_lines->[$number][2],
			airline_logo	=> '/task_1/'.substr(
				$all_lines->[$number][3],
				1,
				length( $all_lines->[$number][3] )
			),
			aircraft_type	=> $all_lines->[$number][4],
			destination		=> $all_lines->[$number][5],
			time_plan		=> $all_lines->[$number][6],
			status			=> $all_lines->[$number][7],
			note			=> $all_lines->[$number][8]
		}
	);
}

print substitute( 
	$template{TABLE_end}, 
	{}
);

print substitute( 
	$template{end}, 
	{}
);
# ------------------------------------------------------------------------------------------------

### Functions ###
sub order{
	#"$a" is the first element of massif and "$b" the second
	#-1 - "$a" behind "$b"
	#1 - "$b" behind "$a"
	#0 - it doesn't matter
	my $a_ = $a->[6];
	my $b_ = $b->[6];

	
	my @arr_temp;
	foreach my $number ( 0, 1 ) {
		my @arr = split(':', ( split(' ', ($a_,$b_)[$number] ) )[1] );
		$arr_temp[$number] = eval "$arr[0] * 60 + $arr[1]";
	}
	
	# print Dumper(\@arr_temp);
	# <STDIN>;

	if(		$arr_temp[0] > $arr_temp[1] ){ 1 }
	elsif(	$arr_temp[0] < $arr_temp[1] ){ -1 }
	else{ 0 }
}