package WWW::Wizards::Gatherer;

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
use MooseX::Types::LWP::UserAgent 0.02 qw(UserAgent);
use MooseX::Types::URI qw(Uri);

###########################################################################
# MODULES
use URI::QueryParam ();
use WWW::Wizards::Gatherer::Results ();
use WWW::Wizards::Gatherer::Utils ();

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.10 -except => [qw(meta)];

###########################################################################
# ATTRIBUTES
has card_details_page => (
	is  => 'ro',
	isa => Uri,

	coerce  => 1,
	default => 'http://gatherer.wizards.com/Pages/Card/Details.aspx',
);
has search_page => (
	is  => 'ro',
	isa => Uri,

	coerce    => 1,
	clearer   => '_clear_search_page',
	predicate => 'has_search_page',
);
has user_agent => (
	is  => 'ro',
	isa => UserAgent,

	coerce  => 1,
	default => sub { [] },
);

###########################################################################
# METHODS
sub get_random_card {
	my ($self) = @_;

	# Get the card details page address
	my $random_card_url = $self->card_details_page->clone;

	# To get a random card, just add action=random
	$random_card_url->query_param(action => 'random');

	# Get the card
	my $card = WWW::Wizards::Gatherer::Utils::build_card_from_response(
		$self->user_agent->get($random_card_url),
	);

	# Return the card
	return $card;
}
sub search {
	my ($self, %args) = @_;

	# The arguments for the results object
	my @results_args = (
		user_agent => $self->user_agent->clone,
	);

	if ($self->has_search_page) {
		# Add the search page
		push @results_args, search_page => $self->search_page->clone;
	}

	# XXX: For testing
	push @results_args, search => {
		map { $_ => qq{+["$args{$_}"]} } keys %args
	};

	# Return a new results bulk data stream
	return WWW::Wizards::Gatherer::Results->new(@results_args);
}

###########################################################################
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

WWW::Wizards::Gatherer - Access to Magic the Gathering Gatherer

=head1 VERSION

This documentation refers to version 0.001.

=head1 SYNOPSIS

  use WWW::Wizards::Gatherer ();

  # Get the gatherer
  my $gatherer = WWW::Wizards::Gatherer->new;

  # Find a card by name and expansion
  my $card = $gatherer->search(
      name => 'Ad Nauseam',
      set  => 'Shards of Alara',
  );
