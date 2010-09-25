package WWW::Wizards::Gatherer::Results;

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
# MOOSE ROLES
with 'Data::Stream::Bulk::DoneFlag' => {-version => 0.08};

###########################################################################
# MOOSE TYPES
use MooseX::Types::LWP::UserAgent 0.02 qw(UserAgent);
use MooseX::Types::URI qw(Uri);

###########################################################################
# MODULES
use Encode ();
use HTML::HTML5::Parser 0.101 ();
use URI ();
use URI::QueryParam ();
use WWW::Wizards::Gatherer::Utils ();

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.10 -except => [qw(meta)];

###########################################################################
# ATTRIBUTES
has search => (
	is  => 'ro',
	isa => 'HashRef',

	required => 1,
);
has search_page => (
	is  => 'ro',
	isa => Uri,

	coerce  => 1,
	default => 'http://gatherer.wizards.com/Pages/Search/Default.aspx',
);
has user_agent => (
	is  => 'ro',
	isa => UserAgent,

	coerce   => 1,
	required => 1,
);

###########################################################################
# PRIVATE ATTRIBUTES
has _current_page => (
	is  => 'rw',
	isa => 'Int',

	clearer   => '_clear_current_page',
	init_arg  => undef,
	predicate => '_has_current_page',
);
has _last_page => (
	is  => 'rw',
	isa => 'Int',

	clearer   => '_clear_last_page',
	init_arg  => undef,
	predicate => '_has_last_page',
);
has _pending_card_urls => (
	is     => 'rw',
	isa    => 'ArrayRef[Str]',
	traits => ['Array'],

	default   => sub { [] },
	init_arg  => undef,
	handles   => {
		_add_pending_card_urls     => 'push',
		_get_next_pending_card_url => 'shift',
		_has_pending_card_urls     => 'count',
	},
);

###########################################################################
# METHODS
sub get_more {
	my ($self) = @_;

	my $results;

	if (!$self->_has_pending_card_urls && defined(my $next_page_address = $self->_next_page_address)) {
		$self->_add_pending_card_urls(
			$self->_parse_card_urls_from_search_page($next_page_address)
		);
	}

	if ($self->_has_pending_card_urls) {
		# There are pending card URLs to retrieve
		$results = [WWW::Wizards::Gatherer::Utils::build_card_from_response(
			$self->user_agent->get($self->_get_next_pending_card_url),
		)];
	}

	return $results;
}

###########################################################################
# PRIVATE METHODS
sub _next_page {
	my ($self) = @_;

	# Get the next page
	my $next_page = $self->_has_current_page ? $self->_current_page + 1 : 1;

	if ($self->_has_last_page && $next_page > $self->_last_page) {
		# No more pages
		$next_page = undef;
	}

	return $next_page;
}
sub _next_page_address {
	my ($self) = @_;

	# Get the current search page address
	my $page_address = $self->search_page->clone;

	# Add the search terms to the URL
	for my $key (keys %{$self->search}) {
		# Get the value of the key
		my $value = Encode::encode_utf8($self->search->{$key});

		# Append the value to the query
		$page_address->query_param_append($key => $value);
	}

	# Get the next page
	if (defined(my $next_page = $self->_next_page)) {
		# Add the page to the URL (but the site uses pages with 0-index)
		$page_address->query_param(page => $next_page - 1);
	}
	else {
		# No more pages
		$page_address = undef;
	}

	return $page_address;
}
sub _parse_card_urls_from_search_page {
	my ($self, $search_page_url) = @_;

	# Get the page number of this page
	my $current_page = $self->_next_page;

	# Remember the previous value of max redirect
	my $previous_max_redirect = $self->user_agent->max_redirect;

	# Set to 0 to prevent all redirects
	$self->user_agent->max_redirect(0);
print {*STDERR} "    => url $search_page_url\n";
	# Get the page
	my $response = $self->user_agent->get($search_page_url);

	# Set the redirect value back
	$self->user_agent->max_redirect($previous_max_redirect);

	if (defined $response->header('Location')) {
		# Only one result
		my $card_result = URI->new_abs($response->header('Location'), $response->base);

		# Set the max pages to 1
		$self->_current_page(1);
		$self->_last_page(1);

		return ("$card_result");
	}

	# Create a new HTML parser
	my $parser = HTML::HTML5::Parser->new;

	# Prase the content
	my $document = $parser->parse_string($response->decoded_content);

	# XXX: This should probably be some other function
	if (!$self->_has_last_page) {
		# Get the last page number from this results page
		my ($paging_div) = grep { _element_has_class($_, 'paging') }
			$document->getElementsByTagName('div');

		# We'll say the current page is the last page unless proven otherwise
		my $last_page = $current_page;

		for my $page_link ($paging_div->getChildrenByTagName('a')) {
			if ($page_link->hasAttribute('href')
			    && $page_link->getAttribute('href') =~ m{\b page=(\d+)}msx) {
				my $page_number = $1;

				if ($page_number > $last_page) {
					$last_page = $page_number;
				}
			}
		}

		# Set the last page
		$self->_last_page($last_page);
	}

	# Get the card table from the page
	my ($card_table) = grep { _element_has_class($_, 'cardItemTable') }
		$document->getElementsByTagName('table');

	if (!defined $card_table) {
		# There are no results
		return;
	}

	# Get the card tables
	my @card_tables = $card_table->getChildrenByTagName('tbody')->shift
		->getChildrenByTagName('tr')->shift
		->getChildrenByTagName('td')->shift
		->getChildrenByTagName('table');

	my @card_urls;

	for my $table (@card_tables) {
		# All the links point to the card, so just pick the first one
		my ($card_link) = map { URI->new_abs($_->getAttribute('href'), $response->base) }
			grep { $_->hasAttribute('href') }
			$table->getElementsByTagName('a');

		# Get the card
		push @card_urls, "$card_link";
	}

	# Update current page
	$self->_current_page($current_page);

	return @card_urls;
}

###########################################################################
# PRIVATE FUNCTIONS
sub _element_has_class {
	my ($element, $class_name) = @_;

	# No if element has no classes at all
	return !1 if !$element->hasAttribute('class');

	# Get the class names
	my @class = split m{\s+}msx, $element->getAttribute('class');

	# Return if any of the class names match
	return List::MoreUtils::any { $_ eq $class_name } @class;
}

###########################################################################
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

WWW::Wizards::Gatherer::Results - Search results

=head1 VERSION

This documentation refers to version 0.001.

=head1 SYNOPSIS

  my $results = ...; # This object

  BLOCK:
  while (defined(my $block = $results->next)) {
      RESULT:
      for my $result (@{$block}) {
          # ... do something with the result
      }
  }

=head1 DESCRIPTION

This represents results from a search on Gatherer.

=head1 ROLES

This object is composed of these L<Moose|Moose> roles:

=over

=item * L<Data::Stream::Bulk|Data::Stream::Bulk> 0.08

=item * L<Data::Stream::Bulk::DoneFlag|Data::Stream::Bulk::DoneFlag> 0.08

=back

=head1 CONSTRUCTOR

This is fully object-oriented, and as such before any method can be used,
the constructor needs to be called to create an object to work with.

=head2 new

This will construct a new object. During object construction, no requests
are made.

=over

=item new(%attributes)

C<%attributes> is a HASH where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=item new($attributes)

C<$attributes> is a HASHREF where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=back

=head1 ATTRIBUTES

  # Get an attribute
  my $value = $object->attribute_name;

=head2 user_agent

B<Required>.

This is a user agent that will be used to make the page requests. This is a
C<UserAgent> as defined by
L<MooseX::Types::LWP::UserAgent|MooseX::Types::LWP::UserAgent>.

=head1 METHODS

=head2 next

Returns the next block as an array reference or C<undef> when there is no
data blocks left. See L<Data::Stream::Bulk|Data::Stream::Bulk> for the full
documentation.

The definition of a block in this module is the number of cards that can be
retrieved in the least number of requests. This means if getting each card
requires a request, then each block will probably only have one card. A
waste of a double-loop, you say? It could change at any time in the future
and this L<Data::Stream::Bulk|Data::Stream::Bulk> interface is the most
flexable (and will fit in with your logic if you use L<KiokuDB|KiokuDB>.

=head1 DEPENDENCIES

=over

=item * L<Data::Stream::Bulk::DoneFlag|Data::Stream::Bulk::DoneFlag> 0.08

=item * L<Moose|Moose> 1.05

=item * L<MooseX::StrictConstructor|MooseX::StrictConstructor> 0.09

=item * L<namespace::clean|namespace::clean> 0.10

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to C<bug-www-wizards-gatherer at rt.cpan.org>,
or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Wizards-Gatherer>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

I highly encourage the submission of bugs and enhancements to my modules.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc WWW::Wizards::Gatherer

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Wizards-Gatherer>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Wizards-Gatherer>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Wizards-Gatherer>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Wizards-Gatherer/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Douglas Christopher Wilson.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back
