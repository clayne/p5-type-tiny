=pod

=encoding utf-8

=head1 PURPOSE

Basic tests for B<Item> from L<Types::Standard>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2019-2025 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;
use Test::More;
use Test::Fatal;
use Test::TypeTiny;
use Test::Requires qw(boolean);
use Types::Standard qw( Item );

isa_ok(Item, 'Type::Tiny', 'Item');
is(Item->name, 'Item', 'Item has correct name');
is(Item->display_name, 'Item', 'Item has correct display_name');
is(Item->library, 'Types::Standard', 'Item knows it is in the Types::Standard library');
ok(Types::Standard->has_type('Item'), 'Types::Standard knows it has type Item');
ok(!Item->deprecated, 'Item is not deprecated');
ok(!Item->is_anon, 'Item is not anonymous');
ok(Item->can_be_inlined, 'Item can be inlined');
is(exception { Item->inline_check(q/$xyz/) }, undef, "Inlining Item doesn't throw an exception");
ok(!Item->has_coercion, "Item doesn't have a coercion");
ok(!Item->is_parameterizable, "Item isn't parameterizable");
isnt(Item->type_default, undef, "Item has a type_default");
is(Item->type_default->(), undef, "Item type_default is undef");

#
# The @tests array is a list of triples:
#
# 1. Expected result - pass, fail, or xxxx (undefined).
# 2. A description of the value being tested.
# 3. The value being tested.
#

my @tests = (
	pass => 'undef'                    => undef,
	pass => 'false'                    => !!0,
	pass => 'true'                     => !!1,
	pass => 'zero'                     =>  0,
	pass => 'one'                      =>  1,
	pass => 'negative one'             => -1,
	pass => 'non integer'              =>  3.1416,
	pass => 'empty string'             => '',
	pass => 'whitespace'               => ' ',
	pass => 'line break'               => "\n",
	pass => 'random string'            => 'abc123',
	pass => 'loaded package name'      => 'Type::Tiny',
	pass => 'unloaded package name'    => 'This::Has::Probably::Not::Been::Loaded',
	pass => 'a reference to undef'     => do { my $x = undef; \$x },
	pass => 'a reference to false'     => do { my $x = !!0; \$x },
	pass => 'a reference to true'      => do { my $x = !!1; \$x },
	pass => 'a reference to zero'      => do { my $x = 0; \$x },
	pass => 'a reference to one'       => do { my $x = 1; \$x },
	pass => 'a reference to empty string' => do { my $x = ''; \$x },
	pass => 'a reference to random string' => do { my $x = 'abc123'; \$x },
	pass => 'blessed scalarref'        => bless(do { my $x = undef; \$x }, 'SomePkg'),
	pass => 'empty arrayref'           => [],
	pass => 'arrayref with one zero'   => [0],
	pass => 'arrayref of integers'     => [1..10],
	pass => 'arrayref of numbers'      => [1..10, 3.1416],
	pass => 'blessed arrayref'         => bless([], 'SomePkg'),
	pass => 'empty hashref'            => {},
	pass => 'hashref'                  => { foo => 1 },
	pass => 'blessed hashref'          => bless({}, 'SomePkg'),
	pass => 'coderef'                  => sub { 1 },
	pass => 'blessed coderef'          => bless(sub { 1 }, 'SomePkg'),
	pass => 'glob'                     => do { no warnings 'once'; *SOMETHING },
	pass => 'globref'                  => do { no warnings 'once'; my $x = *SOMETHING; \$x },
	pass => 'blessed globref'          => bless(do { no warnings 'once'; my $x = *SOMETHING; \$x }, 'SomePkg'),
	pass => 'regexp'                   => qr/./,
	pass => 'blessed regexp'           => bless(qr/./, 'SomePkg'),
	pass => 'filehandle'               => do { open my $x, '<', $0 or die; $x },
	pass => 'filehandle object'        => do { require IO::File; 'IO::File'->new($0, 'r') },
	pass => 'ref to scalarref'         => do { my $x = undef; my $y = \$x; \$y },
	pass => 'ref to arrayref'          => do { my $x = []; \$x },
	pass => 'ref to hashref'           => do { my $x = {}; \$x },
	pass => 'ref to coderef'           => do { my $x = sub { 1 }; \$x },
	pass => 'ref to blessed hashref'   => do { my $x = bless({}, 'SomePkg'); \$x },
	pass => 'object stringifying to ""' => do { package Local::OL::StringEmpty; use overload q[""] => sub { "" }; bless [] },
	pass => 'object stringifying to "1"' => do { package Local::OL::StringOne; use overload q[""] => sub { "1" }; bless [] },
	pass => 'object numifying to 0'    => do { package Local::OL::NumZero; use overload q[0+] => sub { 0 }; bless [] },
	pass => 'object numifying to 1'    => do { package Local::OL::NumOne; use overload q[0+] => sub { 1 }; bless [] },
	pass => 'object overloading arrayref' => do { package Local::OL::Array; use overload q[@{}] => sub { $_[0]{array} }; bless {array=>[]} },
	pass => 'object overloading hashref' => do { package Local::OL::Hash; use overload q[%{}] => sub { $_[0][0] }; bless [{}] },
	pass => 'object overloading coderef' => do { package Local::OL::Code; use overload q[&{}] => sub { $_[0][0] }; bless [sub { 1 }] },
	pass => 'object booling to false'  => do { package Local::OL::BoolFalse; use overload q[bool] => sub { 0 }; bless [] },
	pass => 'object booling to true'   => do { package Local::OL::BoolTrue;  use overload q[bool] => sub { 1 }; bless [] },
	pass => 'boolean::false'           => boolean::false,
	pass => 'boolean::true'            => boolean::true,
	pass => 'builtin::false'           => do { no warnings; builtin->can('false') ? builtin::false() : !!0 },
	pass => 'builtin::true'            => do { no warnings; builtin->can('true') ? builtin::true() : !!1 },
#TESTS
);

while (@tests) {
	my ($expect, $label, $value) = splice(@tests, 0 , 3);
	if ($expect eq 'xxxx') {
		note("UNDEFINED OUTCOME: $label");
	}
	elsif ($expect eq 'pass') {
		should_pass($value, Item, ucfirst("$label should pass Item"));
	}
	elsif ($expect eq 'fail') {
		should_fail($value, Item, ucfirst("$label should fail Item"));
	}
	else {
		fail("expected '$expect'?!");
	}
}

done_testing;

