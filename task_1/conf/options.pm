#!/usr/local/bin/perl -w
#
# Copyright (c) SMIS-Andry 1999-2010. All rights reserved.
# 9/10/2004 18:10
# 9/28/2010  01:28:34
# 10/21/2010  11:54:47
# 12/28/2010  03:23:04

# Library provide unified tools to check program input parameters and use defaults
# It mainly intended to parse query string parameters

package options;
use strict;
use common;
use Data::Dumper;

BEGIN
{
	use Exporter();
	use vars qw( @ISA @EXPORT @EXPORT_OK);
	@ISA = ( 'Exporter' );
	@EXPORT_OK = qw( get_options %VALID_TYPE_MASKS );
}


### Constants
our %VALID_TYPE_MASKS = (
	'*' => '.*' ,
	ANY  => '.*' ,
	NUMBER => '\d+',
	WORD => '\w+',
	DATE => '(\d\d)(\d\d)-(\d\d)-(\d\d)',
	TIME => '(\d\d):(\d\d)(:\d\d)?',
	DATETIME => '(\d\d)(\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d)(:\d\d)?',
	PATH => '[\w\/\\\.\_]+',
	BOOL => '(1|0)',
	STRING => '[^\t\s\n\r]+',
	LIST => '[\w\_\-\,\s\+\:]+',
	DATE_OR_DATETIME => '(\d\d)(\d\d)-(\d\d)-(\d\d)( (\d\d):(\d\d)(:\d\d)?)?',
	BBOX => '([\d\.\-]+)\,([\d\.\-]+)\,([\d\.\-]+)\,([\d\.\-]+)',
	FLOAT => '\-?\d*\.?\d*',
	WKT => '\w+\([\d\(\)\,\. ]+\)',
);


### Functions declarations
sub get_options($$);
sub check_bbox(@);
sub check_dt($);

### Implementation
# Function check parameters and derives options using rules specified by arguments
# Usage: my $options_ref = get_options( \%parameters, \%arguments_hash );
# Required hash elements:
#	parameters => {}  - Source parameters (eg. cgi parameters)
# Optional hash elements:
#	valid => [] | {}
# 		[] - List of valid parameter names. In this case only parameter names will be checked
#		{} - Hash describing valid parameter names and values. Parameter values will be checked also.
#			Validness of values can be defined by two methods
#			1. Using list of valid values, eg. parameter_name => [ "value", "value1" ]
#			2. Using value type masks (see above definition of hash %VALID_TYPE_MASKS). eg parameter_name => "DATE"
#	required => []  - List of required parameter names
#	relation => {}  - Hash describing parameters relation
#		each element of hash correspond with format: # parameter_name => { parameter_value => "required_parameter" | [required_parameter1, .],  }
#	default => {} - Hash of default values.
#   ignore_empty => [1|0] - Only nonempty parameters considerated
#

my %bad_parameters;

sub get_options($$)
{
	my( $pars, $rules ) = @_;
	my $function = (caller(0))[3];

	my %options;
	foreach my $key ( keys %$pars ) {
		if( $rules->{ignore_empty} ) {
			if( ! defined $pars->{$key} || $pars->{$key} eq "" ) {
				next;
			}
		}
		$options{$key} = $pars->{$key};
	}

	# Check validity of parameters
	my @valid_parameter_names;
	if( exists $rules->{valid} ) {
		my $valid = $rules->{valid};
		if( ref( $valid ) eq 'ARRAY' ) { # Check parameter names only
			@valid_parameter_names = @$valid;
			foreach my $name ( keys %options ) {
				unless( find_in_list( \@valid_parameter_names, $name ) ) {
					$bad_parameters{$name} = "Parameter \"$name\" not valid";
					next;
				}
			}
		} elsif( ref( $valid ) eq 'HASH' ) { # Check parameter names and values
			@valid_parameter_names = keys %$valid;
			foreach my $name ( keys %options ) {
				my $value = $options{$name};
				next unless defined $value;
				next if $value eq "";
				unless( find_in_list( \@valid_parameter_names, $name ) ) {
					$bad_parameters{$name} = "Parameter not valid";
					next;
				}
				if( ref( $valid->{$name} ) eq "ARRAY" ) { # List of valid parameter values
					my @valid_values = @{$valid->{$name}};
					unless( find_in_list( \@valid_values, $value ) ) {
						$bad_parameters{$name} = qq( Invalid value "$value". Valid values: ). join( ",", @valid_values );
						next;
					}
				} elsif( ! ref( $valid->{$name} ) ) { # Parameter type
					my $type = $valid->{$name};
					my @valid_types = keys %VALID_TYPE_MASKS;
					check( find_in_list( \@valid_types, $type ), "$function. Illegal parameter type \"$type\"" );
					my $type_mask = $VALID_TYPE_MASKS{$type};
					unless( $value =~ /^$type_mask$/s ) {
						$bad_parameters{$name} = qq(Value "$value" doesn't conform to type "$type"). "( RE mask:'$VALID_TYPE_MASKS{$type}' )";
						next;
					}
					if( $type eq "BBOX" || $type eq "LIST" ) {
						$options{$name} = [split( /,/, $value)];
						if( $type eq "BBOX" ) {
							unless( check_bbox( @{$options{$name}} ) ) {
								my $err = get_error()->{msg};
								$bad_parameters{$name} = qq(Value "$value" doesn't conform to type "$type": $err );
								next;
							}
						}
					}
				}
			}
		} else {
			do_die( "$function: Illegal parameter \"valid\"" );
		}
	}

	# Check required parameters
	if( exists $rules->{required} ) {
		check( ref( $rules->{required} )eq 'ARRAY', "$function: Illegal parameter \"required\"" );
		foreach my $name ( @{$rules->{required}} ) {
			if( @valid_parameter_names ) {
				check( find_in_list( \@valid_parameter_names, $name ), "$function. Illegal parameter \"required\": parameter name \"$name\" not valid" );
			}
			unless( exists $options{$name} && defined $options{$name} ) {
				unless( exists $bad_parameters{$name} ) {
					$bad_parameters{$name} = "Parameter not found";
				}
			}
		}
	}

	# Check parameters relations
	if( exists $rules->{relation} ) {
		# Check validity of relation rule definition
		my %relations;
		foreach my $mode_par ( keys %{$rules->{relation}} ) {
			$relations{$mode_par} = {};
			if( @valid_parameter_names ) {
				check( find_in_list( \@valid_parameter_names, $mode_par ),
					"$function. Illegal parameter \"relation\": parameter name \"$mode_par\" not valid" );
			}
			foreach my $mode_par_value ( keys %{$rules->{relation}{$mode_par}} ) {
				my $relation_info = $rules->{relation}{$mode_par}{$mode_par_value};
				my @relation_pars;
				if( ref( $relation_info ) eq 'ARRAY' ) {
					@relation_pars = @{$relation_info};
				} elsif( ref( $relation_info ) eq '' )  {
					push @relation_pars, $relation_info;
				} else {
					do_die( "$function. Illegal parameter \"relation\": hash value can be arrayref or scalar only" );
				}

				foreach my $par ( @relation_pars ) {
					if( @valid_parameter_names ) {
						check( find_in_list( \@valid_parameter_names, $par ),
							"$function. Illegal parameter \"relation\": parameter name \"$par\" not valid" );
					}
				}
				$relations{$mode_par}{$mode_par_value} = [@relation_pars];
			}
		}

		# Check relation rule conditions
		foreach my $mode_par ( keys %relations ) {
			if( exists $options{$mode_par} && $options{$mode_par} ne "" ) {
				my $mode_par_value = $options{$mode_par};
				if( exists $relations{$mode_par}{$mode_par_value} ) {
					my @relation_pars = @{$relations{$mode_par}{$mode_par_value}};
					foreach my $par ( @relation_pars ) {
						unless( exists $options{$par} ) {
							unless( exists $bad_parameters{$par} ) {
								$bad_parameters{$par} = "Parameter \"$mode_par\" equal \"$mode_par_value\", so parameter \"$par\" must exist";
							}
						}
					}
				}
			}
		}
	}

	# Set defaults values for parameters
	if( exists $rules->{default} ) {
		check( ref( $rules->{default} ) eq "HASH", "$function. Illegal parameter \"default\"" );
		foreach my $name ( keys %{$rules->{default}} ) {
			unless( defined $options{$name} ) {
				$options{$name} = $rules->{default}{$name};
			}
		}
	}
	if( %bad_parameters ) {
		my $delimiter = $SDB::common::CGI ? "<BR>" : "\n";
		set_error( 1,
			$delimiter.join( $delimiter, map { "[$_]\: $bad_parameters{$_}" } keys %bad_parameters )
		);
		return undef;
	} else {
		return {%options};
	}
}


sub check_bbox(@)
{
	my @arr = @_;
	unless( @arr == 4 ) {
		set_error( 5, "bbox parameter must have four elements" );
		return;
	}

	foreach( @arr ) {
		unless( $_*1 == $_ ) {
			set_error( 5, "parameter contain non-digit symbols" );
			return;
		}
	}
	my( $min_lon,$min_lat,$max_lon,$max_lat ) = @arr;
#	unless( $min_lon >= -180 && $min_lon <= 180 && $max_lon >= -180 && $max_lon <= 180 ) {
#		set_error( 5, "values of parameters min_lon and max_lon must be in interval [-180:180]" );
#		return;
#	}
	unless( $max_lon >= $min_lon ) {
		set_error( 5, "parameter \"max_lon\" must be more or equal than parameter \"min_lon\"" );
		return;
	};

#	unless( $min_lat >= -90 && $min_lat <= 90 && $max_lat >= -90 && $max_lat <= 90 ) {
#		set_error( 5, "values of parameters min_lat and max_lat must be in interval [-90:90]" );
#		return;
#	}
	unless( $max_lat >= $min_lat ) {
		set_error( 5, "parameter \"max_lat\" must be more or equal than parameter \"min_lat\"" );
		return;
	}
	unless( $max_lon >= $min_lon ) {
		set_error( 5, "parameter \"max_lon\" must be more or equal than parameter \"min_lon\"" );
		return;
	}
	return 1;
}


if(0) {
my $options_ref = get_options(
	{
		dt_from => "2010-01-01",
		dt => "2010-02-01 01:01",
		bbox => "40,20,40,40",
		layers => "first,second,third,",
		plugin => "modis_composites",
	},
	{
		valid => {
			dt_from => "DATE_OR_DATETIME",
			dt => "DATE_OR_DATETIME",
			bbox => "BBOX",
			layers => "CS_WORD_LIST",
			plugin => [qw( modis_composites modis_data )],
		},
		required => [qw( dt_from dt bbox layers) ],
		default => {
			plugin => "modis_composites",
		},
	}
);
if( $options_ref ) {
	print STDERR "\n", Dumper( $options_ref );
} else {
	print STDERR "\n", Dumper get_error();
}



}

1;

