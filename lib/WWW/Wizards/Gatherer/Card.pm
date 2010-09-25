package WWW::Wizards::Gatherer::Card;

use 5.008003;
use strict;
use warnings 'all';

###########################################################################
# METADATA
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION   = '0.001';

###########################################################################
# MOOSE
use Moose 1.05;
use MooseX::StrictConstructor 0.09;

###########################################################################
# MOOSE TYPES
use MooseX::Types::Common::String qw(NonEmptySimpleStr NonEmptyStr);
use MooseX::Types::Moose qw(ArrayRef Str);

###########################################################################
# MODULES
use Moose::Util::TypeConstraints;

###########################################################################
# ATTRIBUTES
subtype PT =>
	as Str =>
		where { m{\A (?:\-?\d+ (?:[+-] \*)? | \*) \z}msx };

has artist => (
	is  => 'ro',
	isa => NonEmptySimpleStr,

	required => 1,
);
has converted_mana_cost => (
	is  => 'ro',
	isa => 'Int',

	clearer   => '_clear_converted_mana_cost',
	predicate => 'has_converted_mana_cost',
);
has expansion => (
	is  => 'ro',
	isa => NonEmptySimpleStr,

	required => 1,
);
has flavor_text => (
	is  => 'ro',
	isa => NonEmptyStr,

	clearer   => '_clear_flavor_text',
	predicate => 'has_flavor_text',
);
has loyalty => (
	is  => 'ro',
	isa => 'Int',

	clearer   => '_clear_loyalty',
	predicate => 'has_loyalty',
);
has mana_cost => (
	is  => 'ro',
	isa => NonEmptyStr, # XXX: Change this

	clearer   => '_clear_mana_cost',
	predicate => 'has_mana_cost',
);
has multiverse_id => (
	is  => 'ro',
	isa => 'Int',

	required => 1,
);
has name => (
	is  => 'ro',
	isa => NonEmptySimpleStr,

	required => 1,
);
has number => (
	is  => 'ro',
	isa => 'Int',

	clearer   => '_clear_number',
	predicate => 'has_number',
);
has power => (
	is  => 'ro',
	isa => 'PT',

	clearer   => '_clear_power',
	predicate => 'has_power',
);
has rarity => (
	is  => 'ro',
	isa => NonEmptySimpleStr,

	required => 1,
);
has subtypes => (
	is  => 'ro',
	isa => ArrayRef[NonEmptySimpleStr],

	clearer   => '_clear_subtypes',
	predicate => 'has_subtypes',
);
has text_blocks => (
	is  => 'ro',
	isa => ArrayRef[Str],

	clearer   => '_clear_text_blocks',
	predicate => 'has_text_blocks',
);
has toughness => (
	is  => 'ro',
	isa => 'PT',

	clearer   => '_clear_toughness',
	predicate => 'has_toughness',
);
has types => (
	is  => 'ro',
	isa => ArrayRef[NonEmptySimpleStr],

	required => 1,
);

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.10 -except => [qw(meta)];

###########################################################################
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

WWW::Wizards::Gatherer::Card - Magic: The Gathering Card

=head1 VERSION

This documentation refers to version 0.001.
