#!/usr/local/bin/perl -w
#
# Copyright (c) SMIS-Andry 1999-2001. All rights reserved.
#
# 17.02.00
# 01.02.01
# 13.08.01 Added version info
# 16.10.01 Corrected prototypes of functions max, min, sum
#	Before (absolete code) its called as &function without prototypes check
# 14.12.01 Support work under mod_perl was added. ( by Mike Andreev )
# 09.01.02 Fixed handling of warnings
#	Now if warning detected during script execution exit code calculated by call choose_exit_code( $exit_code, $RET_WARN )
# 29.07.02 Added global parameter $OS_TYPE
# 6/21/2004

package common;

use strict;
#use SDB::debug qw( $DEBUG $SQL_DEBUG smislog smislog_sql );


BEGIN {
	use Exporter   ();
	if(exists $ENV{'GATEWAY_INTERFACE'} && $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-Perl\// ){
		require Apache;
	}
	use vars       qw( @ISA @EXPORT );
	use vars qw( $VERSION $RET_ERR $RET_OK $RET_NODATA $RET_SIG $RET_FATAL $RET_LOCK $RET_WARN $RET_HANG $OS_TYPE $OS_NAME );

	$VERSION = '2.62'; # SDB libraries version

	@ISA         = ( 'Exporter' );
	my @exit_codes = qw( $RET_ERR $RET_OK $RET_NODATA $RET_SIG $RET_FATAL $RET_LOCK $RET_WARN $RET_HANG);

	my @functions1 = qw( do_exit do_die check assert do_warn safe_system set_error get_error choose_exit_code  );
	my @functions2 = qw( print_content_type print_location );
	my @functions3 = qw( list_length min max sum check_hash_keys find_in_list );
	my @flags = qw( $OS_TYPE $OS_NAME );
	@EXPORT = ( @exit_codes, @functions1, @functions2, @functions3, @flags );

	# Exported constatnts
	$RET_OK     = 0;	#  OK, processing done
	$RET_ERR    = 1;  	#  1 - Error
	$RET_NODATA = 10;	# 10 - No data to process
	$RET_LOCK   = 20;	# 20 - Files locked, unable to process
	$RET_SIG    = 30;	# 30 - Killed by signal
	$RET_WARN	= 40;	# 40 - Warning
	$RET_FATAL  = 50;	# 100 - Launcher failed to execute
	$RET_HANG  = 60;	# 100 - Launcher failed to execute

	# Declaration of global variables and flags
	use vars qw($CGI $CONTENT $ERROR $IS_CALLBACK $MOD_PERL $WARNING_DETECTED );
	sub init(){
		$CGI = exists $ENV{'GATEWAY_INTERFACE'} ? 1 : 0;
		$CONTENT = 0;
		$WARNING_DETECTED = 0;
		$ERROR = { code => 0, msg => 'Undefined error' };
		$IS_CALLBACK = 0;
		$MOD_PERL = ( $CGI && $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-Perl\// ) ? 1 : 0;
		# Define OS type. Supported variants: windows_nt, windows_9x, unix
		# Make some stubs for unsupported functions
		if( $^O eq "MSWin32" ) {
			$OS_TYPE = "windows";
			if( exists $ENV{OS} && $ENV{OS} eq "Windows_NT" ) {
				$OS_NAME = "windows_nt";
			} else {
				$OS_NAME = "windows_9x";
			}
		} else {
			$OS_TYPE = "unix";
			$OS_NAME = $^O;
		}
	}
	init();
}

END
{
}

# All functions unless specified another behaviour
# calls exit on error

# 1. Control related functions
sub do_exit($;$);
sub do_die(;$);
sub check($;$);
sub assert($;$);
sub safe_system($);
sub set_error($;$);
sub get_error();
sub choose_exit_code(@);

# 2. Common functions
sub list_length(@);
sub min(@);
sub max(@);
sub sum(@);
sub check_hash_keys($@); # (bool) errors: 1 - "Hash key not found"

# 3. CGI related functions
sub print_content_type(;$);
sub print_location($);

######################################################################
# 1. Control related functions
######################################################################
# Function prints message, defines ERROR structure and calls exit with specified code
# Under CGI enviroment in case of non zero exit code
# it puts message in STDIO as HTML formated text
#  (for zero exit code no messages are outputed)
# In ordinary enviroment it prints message in STDERR
# As error code for defining ERROR structure used reserved value "-1"
# It allows distinguish exit call from concerned function from other cases
# usage: do_exit( $exit_value, $message )
sub do_exit ($;$) {
	my $code = shift;
	my $msg = shift;

	if( $msg ) {
		$msg = "\n$msg\n";
		$msg =~ s/\n\n+/\n/;
	} else {
		$msg = "";
	}

	if( $WARNING_DETECTED ) {
		$WARNING_DETECTED = 0;
		my $new_code = choose_exit_code( $code, $RET_WARN );
		if( $new_code != $code ) {
			$msg = "Warning detected. Force change exit code from \"$code\" to \"$new_code\". $msg";
			$code = $new_code;
		} else {
			$msg = "Warning detected. Keep exit code \"$code\". $msg";
		}
	}
	$ERROR = { code => -1, msg => $msg };
	if( $CGI ) {
		if( $code ) { #  in case of "exit 0" don't print any message
			cgi_print( "<html><head><title>CGI SCRIPT ERROR</title></head>\n".
			   "<body><h3>Request aborted due to fatal error</h3>\n".
			   "<H4>$msg</H4>\n".
			   "</body></html>\n" );
		}
	}

	if( $code == $RET_ERR ) {
#		if( $CGI ) {
#			smislog "CGI SCRIPT ERROR: ", $msg;
#		}
		$! = $code;
		die ( $msg );
	} else {
		print STDERR $msg;
		exit $code;
	}
}

sub do_warn (;$) {
	my $msg = shift || "";
	$WARNING_DETECTED = 1;
	if( $CGI ) {
		cgi_print( "<H4>Warning: $msg</H4>" );
	} else {
		print STDERR "\nWarning: ";
		if( $msg ne "" ) {
			$msg = "$msg\n";
			$msg =~ s/\n\n+/\n/;
			print STDERR $msg;
		}
	}
}


# Function calls do_exit with error code $RET_ERR
# and specified message
sub do_die(;$)
{
	my $msg = shift || "";
	my $composed = "Die call: $msg";
	do_exit( $RET_ERR, $composed );
}

# If expression is not defined or equals 0
# function compose  error message and
# calls do_exit with code $RET_ERR
sub check($;$)
{
	my $exp = shift;
	my $msg = shift || "";
	if( ! defined $exp || $exp == 0 ) {
		my $composed = "Check failed: $msg";
		do_exit( $RET_ERR, $composed );
	}
}

# The same as check but provides
# error message with some debug information
sub assert($;$)
{
	my $exp = shift;
	my $msg = shift || "";
	if( ! defined $exp || $exp == 0 ) {
		my $composed = "Assert failed at ". join( ' ', caller )."\n$msg";
		do_exit( $RET_ERR, $composed );
	}
}

# Function "safe_system" calls perl routine "system"
# and analyses its return code
# If command cannot be executed, broken by signal or
# failed with coredump, function calls method do_exit( $RET_ERR, ... )
# with corresponding message
# Otherwise function return command exit code
sub safe_system($)
{
	my $command = shift;
	my ( $low, $high, $code, $signal );
    my $rc = 0xffff & system $command;
    if ( $rc == 0 ) {
		$code = 0;
		return $code;
    }
    if ( $rc == 0xff00 ) {
		do_exit( $RET_ERR, "\"$command\" failed" );
    }
	( $high, $low ) = ( $rc >> 8, $rc & 0x00ff );

	if ( $low  == 0 ) {
		$code = $high;
		return $code;
	} else {
		$signal = $rc & 0x7f;
		if( ( $rc & 0x80 ) == 0x80 )  {
			do_exit( $RET_ERR, "\"$command\": coredump from signal $rc" );
		} else {
			do_exit( $RET_ERR, "\"$command\" killed by signal $rc" );
		}
	}
}

# Function fills global structure $ERROR:
# usage: set_error( $err_code, $err_msg )
# Code must be positive numeric value,
# negative values reserved for library special purposes
sub set_error($;$)
{
	my $code = shift;
	my $msg = shift;
	assert( defined $ERROR );
	check( $code >= 0 && $code * 1 == $code, "Function set_error: illegal parameter code \"$code\"" );
	$ERROR->{code} = $code;
	$ERROR->{msg} = $msg || "";
}

# Functions returns reference to hash $ERROR
# examples: my $hashref = get_error(),  get_error->{msg},  get_error->{code}
sub get_error()
{
	assert( defined $ERROR );
	return $ERROR;
}


# Function chooses exit code from specified list according with EXIT_CODE_PRIORITY_LIST
my @EXIT_CODE_PRIORITY_LIST = ( $RET_ERR, $RET_WARN, $RET_LOCK, $RET_OK, $RET_NODATA );
sub choose_exit_code(@)
{
	check( $#_ > -1, "Function needs at least one parameter in list" );
    my $code ;
    foreach $code ( @EXIT_CODE_PRIORITY_LIST )
    {
        foreach( @_ ) {
            if( $_ == $code ) {
                    return $code;
            }
        }
    }
    return $RET_ERR;
}

######################################################################
# 2. Common functions
######################################################################
# function returns number of scalars in specified list
# it's usefull when list is returned some function
# usage: &list_length( @list )
sub list_length(@)
{
	my $list_ref = \@_;
	return $#$list_ref + 1;
}

sub min(@)
{
	my $best = shift;
	&check( defined $best );
	foreach ( @_ ) {
		$best = $_ if $_ < $best;
	}
	return $best;
}

sub max(@)
{
	my $best = shift;
	&check( defined $best );
	foreach ( @_ ) {
		$best = $_ if $_ > $best;
	}
	return $best;
}

sub sum(@)
{
	my @args = @_;
	my $sum = 0;
	foreach ( @args ) {
		$sum = $sum + $_
	}
	return $sum;
}

# Function checks existing of specified keys in hash
# If some keys is not found function sets error with code 1
# and returns undef elsewhere returns 1
sub check_hash_keys( $@ )
{
	my $hash_ref = shift;
	foreach ( @_ ) {
		unless( exists $hash_ref->{$_} && defined $hash_ref->{$_} ) {
			set_error( 1, "Key \"$_\" not found in hash" );
			return;
		}
	}
	return 1;
}

# Function searches specified list for particular element
sub find_in_list($$)
{
	my $list_ref = shift;
	my $el = shift;
	foreach( @$list_ref ) {
		return 1 if $_ eq $el;
	}
	return;
}


######################################################################
# 2. CGI related functions
######################################################################
# Function prints in STDOUT HTTP header Content-type: ..
# If no type is defined it uses type "text/html"
# In console mode ($CGI=0) no output is produced
sub print_content_type(;$)
{
	my $content_type = shift || "text/html";
	return unless $CGI;
	if( $MOD_PERL ){
		$CONTENT = 1;
		Apache->request->send_http_header("text/html");
	}
	if( ! $CONTENT ) {
		$CONTENT = 1;
		$| = 1;
		print "Content-type: $content_type\n\n";
		$| = 0;
	}
}

sub print_location($)
{
	my $location = shift;
	assert( defined $location, "function \"print_location\" failed" );
	check( $CONTENT == 0,
		"Cannot print location header after content-type header" );
	$CONTENT = 1;
	print STDOUT "location: $location\n\n";
}

sub cgi_print($)
{
	print_content_type() unless $CONTENT;
	print STDOUT shift;
}

1;



