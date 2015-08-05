#!/usr/local/bin/perl -w
#
# Copyright (c) SMIS-Andry 1999-2001. All rights reserved.
#
package hash2template;


# Module immplements tied hash for composing dynamic html using
# template files of special format.
#
# Template file format description:
# Template file is ordinary html file with additional section tags, that don't
# prevent viewing it with standard html browser.
# Format of section tag "<!!section_name>". It used to delimiter parts of template.
# Section begins from this tags and ends with other section tag or end of file
# If same section exists in several variants in file, it's used last variant
# The beginning part of template file before any section tag (if it's not empty) is considered as
# section with predefined name "_first".
# HTML text can contain patterns for substituting. Format  of pattern - "%pattern_name%"
# Template file can be used also for storing of text constants, for example
# names of months in other languages. It can be placed in special section and
# delimited some delimiter symbol (eg. ",").
# !! Since format is designed for HTML repeated symbol "\n" is ignored and
# substituted with ordinary "\n"
#
# Synopsis:
# tie %template, 'SDB::hash2template', $template_file, [ \@required_sections ];
# usage:
# print $template{$section}; - print section of template
# @month_names = split( /,/, $template{month_names} );
#
# Class function "substitute" replaces in specified text
# patterns %pattern_name% according to substitute hash
# Format of hash: %hash = ( pattern_name => "substitute text",..  );
# usage:
# print substitute( $template{$section}, \%subst );
# print substitute( $text, \%subst );
#
# 12.02.01
# 24.06.2003 Small bugs fixed

BEGIN {
	use strict;
	use common;
	require Tie::Hash;
	use vars qw( @ISA @EXPORT );
	@ISA = qw(Tie::Hash Exporter);
	@EXPORT = qw( substitute );
}

sub substitute($$)
{
	my $text = shift;
	my $hash_ref = shift;

	check( defined $text, "Substitute failed: first parameter not defined" );

	my $pat;
	foreach $pat ( keys %$hash_ref )	{
		check( defined $hash_ref->{$pat},
			"Illegal substitute hash: element with key \"$pat\" not defined" );
		$sub = $hash_ref->{$pat};
		$text =~ s/%$pat%/$sub/ge;
	}
 	return $text;
}

sub TIEHASH($$$)
{
	my $class = shift;
	my $file = shift;
	my $array_ref = shift;
	my $self = {};
	$self->{file} = $file;
	bless $self, $class;
	$self->_load_template();
	$self->_check_sections( $array_ref );
	return $self;
}

sub _load_template($)
{
	my $self = shift;
	my $file = $self->{file};

	check( open( FILE, "<$file" ), "Cannot open template file \"$file\" " );
	my $buffer = join( '', <FILE> );
	close( FILE );
	# Strip repeated \n
	$buffer =~ s/\n\n+/\n/g;
	# Modify template to simplify parsing
	$buffer = "_first>$buffer<!!";
	# Parse template
	$self->{template} = { ( $buffer =~ / ([^>]*) > (.*?) <!! /gsx ) };
	# Remove "" section
	delete $self->{template}->{""} if exists $self->{template}->{""};
	# Remove _first section if it's empty
	delete $self->{template}->{_first} if $self->{template}->{_first} =~ /^[\n\s\t]*$/;
	$self->{sorted_sections} = [ keys %{$self->{template}} ];
}

sub _check_sections($$)
{
	my $self = shift;
	my $sections_ref = shift;
	my $hash_ref = $self->{template};
	foreach( @$sections_ref ) {
		check( exists $hash_ref->{$_},
			"Section \"$_\" not found in template file \"".$self->{'file'}."\"" );
	}
}

sub FETCH($$)
{
	my $self = shift;
	my $section = shift;
	check( $self->EXISTS( $section ), "Use of undefined section \"$section\"" );
	return $self->{template}->{$section};
}

sub EXISTS($$)
{
	my $self = shift;
	my $section = shift;
	if( exists $self->{template}->{$section} && defined $self->{template}->{$section} ) {
		return 1;
	} else {
		return 0;
	}
}

sub STORE($$$)
{
	my $self = shift;
	my $section = shift;
	my $value = shift;
	check( defined $value, "Cannot store undefined value" );
	$self->{template}->{$section} = $value;
	push @{$self->{sorted_sections}}, $section;
}

sub FIRSTKEY($)
{
	my $self = shift;
	$self->{last} = -1;
	return $self->NEXTKEY;
}

sub NEXTKEY($)
{
	my $self = shift;
	$self->{last}++;
	my $section = ${$self->{sorted_sections}}[$self->{last}];
	return unless defined $section;
	return $section;
}

# unsupported operation:
sub DELETE { unsupported( 'DELETE' ) }
sub CLEAR { unsupported( 'CLEAR' ) }

sub unsupported($)
{
	my $operation  = shift;
	do_exit( $RET_ERR, "Operation \"$operation\" unsupported for tied class \"SDB::hash2config\"" );
}

1;

