package Type::Params::Alternatives;

use 5.008001;
use strict;
use warnings;

BEGIN {
	if ( $] < 5.010 ) { require Devel::TypeTiny::Perl58Compat }
}

BEGIN {
	$Type::Params::Alternatives::AUTHORITY  = 'cpan:TOBYINK';
	$Type::Params::Alternatives::VERSION    = '2.007_000';
}

$Type::Params::Alternatives::VERSION =~ tr/_//d;

use B ();
use Eval::TypeTiny::CodeAccumulator;
use Types::Standard qw( -is -types -assert );
use Types::TypeTiny qw( -is -types to_TypeTiny );

require Type::Params::Signature;
our @ISA = 'Type::Params::Signature';

sub new {
	my $class = shift;
	my %self  = @_ == 1 ? %{$_[0]} : @_;
	my $self = bless \%self, $class;
	exists( $self->{$_} ) || ( $self->{$_} = $self->{base_options}{$_} )
		for keys %{ $self->{base_options} };
	$self->{sig_class} ||= 'Type::Params::Signature';
	$self->{message}   ||= 'Parameter validation failed';
	delete $self->{base_options}{$_} for qw/ returns returns_list returns_scalar /;
	$self->_rationalize_returns;
	return $self;
}

sub base_options      { $_[0]{base_options}      ||= {} }
sub alternatives      { $_[0]{alternatives}      ||= [] }
sub sig_class         { $_[0]{sig_class} }
sub meta_alternatives { $_[0]{meta_alternatives} ||= $_[0]->_build_meta_alternatives }
sub parameters        { [] }
sub goto_next         { $_[0]{base_options}{goto_next} }
sub package           { $_[0]{base_options}{package}   }
sub subname           { $_[0]{base_options}{subname}   }

sub _build_meta_alternatives {
	my $self = shift;

	my $index = 0;
	return [
		map {
			my $meta = $self->_build_meta_alternative( $_ );
			$meta->{_index} = $index++;
			$meta;
		} @{ $self->alternatives }
	];
}

sub _build_meta_alternative {
	my ( $self, $alt ) = @_;

	if ( is_CodeRef $alt ) {
		return { closure => $alt };
	}
	elsif ( is_HashRef $alt ) {
		my %opts = (
			%{ $self->base_options },
			goto_next       => !!0, # don't propagate these next few
			returns         => undef,
			returns_scalar  => undef,
			returns_list    => undef,
			%$alt,
			want_source     => !!0,
			want_object     => !!0,
			want_details    => !!1,
		);
		my $sig = $self->sig_class->new_from_v2api( \%opts );
		return $sig->return_wanted;
	}
	elsif ( is_ArrayRef $alt ) {
		my %opts = (
			%{ $self->base_options },
			goto_next       => !!0, # don't propagate these next few
			returns         => undef,
			returns_scalar  => undef,
			returns_list    => undef,
			positional      => $alt,
			want_source     => !!0,
			want_object     => !!0,
			want_details    => !!1,
		);
		my $sig = $self->sig_class->new_from_v2api( \%opts );
		return $sig->return_wanted;
	}
	else {
		$self->_croak( 'Alternative signatures must be CODE, HASH, or ARRAY refs' );
	}
}

sub _coderef_start_extra {
	my ( $self, $coderef ) = ( shift, @_ );
	
	$coderef->add_line( 'my $r;' );
	$coderef->add_line( 'undef ${^_TYPE_PARAMS_MULTISIG};' );
	$coderef->add_gap;

	for my $meta ( @{ $self->meta_alternatives } ) {
		$self->_coderef_meta_alternative( $coderef, $meta );
	}
	
	$self;
}

sub _coderef_meta_alternative {
	my ( $self, $coderef, $meta ) = ( shift, @_ );
	
	my @cond = '! $r';
	push @cond, sprintf( '@_ >= %s', $meta->{min_args} ) if defined $meta->{min_args};
	push @cond, sprintf( '@_ <= %s', $meta->{max_args} ) if defined $meta->{max_args};
	if ( defined $meta->{max_args} and defined $meta->{min_args} ) {
		splice @cond, -2, 2, sprintf( '@_ == %s', $meta->{min_args} )
			if $meta->{max_args} == $meta->{min_args};
	}
	
	# It is sometimes possible to inline $meta->{source} here
	if ( $meta->{source}
	and $meta->{source} !~ /return/
	and ! keys %{ $meta->{environment} } ) {
		
		my $alt_code = $meta->{source};
		$alt_code =~ s/^sub [{]/do {/;
		$coderef->add_line( sprintf(
			'eval { local @_ = @_; $r = [ %s ]; ${^_TYPE_PARAMS_MULTISIG} = %d }%sif ( %s );',
			$alt_code,
			$meta->{_index},
			"\n\t",
			join( ' and ', @cond ),
		) );
		$coderef->add_gap;
	}
	else {
		
		my $callback_var = $coderef->add_variable( '$signature', \$meta->{closure} );
		$coderef->add_line( sprintf(
			'eval { $r = [ %s->(@_) ]; ${^_TYPE_PARAMS_MULTISIG} = %d }%sif ( %s );',
			$callback_var,
			$meta->{_index},
			"\n\t",
			join( ' and ', @cond ),
		) );
		$coderef->add_gap;
	}
	
	return $self;
}

sub _coderef_end_extra {
	my ( $self, $coderef ) = ( shift, @_ );
	
	$coderef->add_line( sprintf(
		'%s unless $r;',
		$self->_make_general_fail( message => B::perlstring( $self->{message} ) ),
	) );
	$coderef->add_gap;
	
	return $self;
}

sub _coderef_check_count {
	shift;
}

sub _make_return_list {
	'@$r';
}

sub make_class_pp_code {
	my $self = shift;
	
	return join(
		qq{\n},
		grep { length $_ }
		map  { $_->{class_definition} || '' }
		@{ $self->meta_alternatives }
	);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Type::Params::Alternatives - subclass of Type::Params::Signature for C<multi> signatures

=head1 STATUS

This module is not covered by the
L<Type-Tiny stability policy|Type::Tiny::Manual::Policies/"STABILITY">.

=head1 DESCRIPTION

This is mostly internal code, but can be used to provide basic introspection
for signatures.

This module is a subclass of L<Type::Parameters::Signature>, so inherits
attributes and methods from that.

=head2 Constructor

=over

=item C<< new(%attributes) >>

=back

=head2 Attributes

All attributes are read-only.

=over

=item C<< base_options >> B<HashRef>

=item C<< alternatives >> B<< ArrayRef[HashRef|ArrayRef|CodeRef] >>

=item C<< sig_class >> B<ClassName>

=item C<< meta_alternatives >> B<ArrayRef[HashRef]>

Automatically built from C<alternatives>; do not set this yourself.

=item C<< parameters >> B<ArrayRef>

Overridden from parent class to always return the empty arrayref.

=item C<< message >> B<Str>

Error message to be thrown when none of the alternatives match.
This is a bare attribute with no accessor method.

=back

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-type-tiny/issues>.

=head1 SEE ALSO

L<Type::Params>, L<Type::Params::Signature>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2023-2024 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
