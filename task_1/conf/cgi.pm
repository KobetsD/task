#!/usr/local/bin/perl -w
#
# Copyright (c) SMIS-Andry 1999-2001. All rights reserved.
#
# 19.07.00
# 28.02.01 function compose_query_string can use undefined hash values
# 14.02.2003 Samm small improvements

package cgi;

use common;

BEGIN
{
    	use strict;
    	use Exporter   ();
    	use vars       qw( @ISA @EXPORT );
    	@ISA         = ( 'Exporter' );
	@EXPORT = ( 'get_query_string', 'parse_query_string', 'compose_query_string' );
}

# cgi
sub get_query_string();
sub parse_query_string($;$);
sub compose_query_string(@);

sub get_query_string()
{
	my $result;
	if( !exists $ENV{SCRIPT_NAME} ) {
		$result = join( '&', @ARGV );
	} else {
		if( $ENV{REQUEST_METHOD} eq 'GET' ) {
			$result = $ENV{QUERY_STRING};
		} elsif(  $ENV{REQUEST_METHOD} eq 'POST' ) {
#			check( read( STDIN, $result, $ENV{'CONTENT_LENGTH'} ), "Read from STDIN failed" );
#			!!! by Tolpin read in POST can return 0 if end of stream !!!
			my $read_ret = read( STDIN, $result, $ENV{'CONTENT_LENGTH'} );
			check(0, "Read from STDIN failed" ) if !defined $read_ret;
		} else {
#			print STDERR "\nRequest method $ENV{REQUEST_METHOD}";
			$result = "";
		}
	}
	return $result;
}

sub parse_query_string($;$)
{
	my $query_string = shift || "";
	my $arg_hr = shift;
	my $continuation =  ( defined $arg_hr && defined $arg_hr->{ continuation } )?$arg_hr->{ continuation }:0;
	my $continuation_separator = ( defined $arg_hr && defined $arg_hr->{ continuation_separator} )?$arg_hr->{continuation_separator}:',';

	my $delimiter_mask = '&';
    	$query_string =~ s/\\&/&/g ;
    	$query_string =~ s/\&amp\;/\&/g ;
	my @pairs = split(/$delimiter_mask/, $query_string );
	my %result;
  	foreach (0 .. $#pairs) {
		my( $key, $val );
 		# Convert plus's to spaces
    		$pairs[$_] =~ s/\+/ /g;
    		# Split into key and value.
    		($key, $val) = split(/=/,$pairs[$_],2); # splits on the first =.
		check( defined $key && defined $val, "cgi.pm: Illegal query_string" );
    		# Convert %XX from hex numbers to alphanumeric
                $key =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/chr( hex( $1 ) )/ge;
                $val =~ s/%([0-9A-Fa-f][0-9A-Fa-f])/chr( hex( $1 ) )/ge;
    		# Associate key and value
		if( $continuation && exists $result{$key} ){
			$result{$key} .= "$continuation_separator$val";
		}else{
			$result{$key} = $val;
		}
	}
	return %result;
}

sub compose_query_string( @ )
{
	my %input = @_;
	my $set = '[^a-zA-Z0-9_ ]';
	my $delimiter = '&amp;';
	my @pairs;

	foreach ( keys %input ) {
		my( $key, $val );
		$key = $_;
		$val  = defined $input{$_} ? $input{$_} : "";
		$key =~ s/($set)/sprintf( "%%%02x", ord( $1 ) )/ge;
		$val =~ s/($set)/sprintf( "%%%02x", ord( $1 ) )/ge;
		$key =~ s/ /+/g;
		$val =~ s/ /+/g;
		push @pairs, "$key=$val";
	}
	return join( $delimiter, @pairs );
}

1; #return true
