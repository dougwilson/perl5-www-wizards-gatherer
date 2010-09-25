package WWW::Wizards::Gatherer::Utils;

use 5.008003;
use charnames ':full'; # Used in regexps as \N{}
use strict;
use utf8;
use warnings 'all';

###########################################################################
# METADATA
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION   = '0.001';

###########################################################################
# MODULES
use Carp ();
use List::MoreUtils ();
use HTML::HTML5::Parser 0.101 ();
use WWW::Wizards::Gatherer::Card ();

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.10 -except => [qw(meta)];

###########################################################################
# FUNCTIONS
sub build_card_from_response {
	my ($response) = @_;

	# Create a new HTML parser
	my $parser = HTML::HTML5::Parser->new;

	# Prase the content
	my $document = $parser->parse_string($response->decoded_content);

	# Parse the data from the document
	my %card_args = _parse_card_details_document($document);

	# Build the card
	my $card = WWW::Wizards::Gatherer::Card->new(%card_args);

	return $card;
}

###########################################################################
# PRIVATE VARIABLES
my %card_details_value_transform = (
	flavor_text => \&_card_details_value_transform_flavor_text,
	mana_cost   => \&_card_details_value_transform_mana_cost,
	other_sets  => sub { () }, # XXX: This is ignored for now
	p_t         => \&_card_details_value_transform_power_tough,
	text        => \&_card_details_value_transform_text,
	types       => \&_card_details_value_transform_types,
);

###########################################################################
# PRIVATE FUNCTIONS
sub _card_details_value_transform_flavor_text {
	# Return the blocks joined with new lines
	return join qq{\n}, _parse_card_text_boxes($_[0]);
}
sub _card_details_value_transform_mana_cost {
	my ($element) = @_;

	# Get the mana costs from the images
	my @mana_costs = map { $_->getAttribute('alt') }
		$element->getElementsByTagName('img');

	# XXX: This should eventually be an object
	return join q{}, map { "{$_}" } @mana_costs;
}
sub _card_details_value_transform_power_tough {
	my ($element) = @_;

	# Get the power and toughness
	my ($power, $toughness) = $element->textContent =~ m{(\S+) \s* / \s* (\S+)}msx;

	return (
		power     => $power,
		toughness => $toughness,
	);
}
sub _card_details_value_transform_types {
	my ($element) = @_;

	my %details;

	# Get and trim the text content
	my $value = $element->textContent;
	$value =~ s{\A \s+}{}msx;
	$value =~ s{\s+ \z}{}msx;

	# Split the text content into type and subtypes
	my ($types, $subtypes) = split m{\s* \N{EM DASH} \s*}msx, $value;

	if (defined $types) {
		# Split the types
		my @type = split m{\s+}msx, $types;

		# Store the type in the details
		$details{types} = \@type;
	}

	if (defined $subtypes) {
		# Split the subtypes
		my @subtype = split m{\s+}msx, $subtypes;

		# Store them in the details
		$details{subtypes} = \@subtype;
	}

	return %details;
}
sub _card_details_value_transform_text {
	# Change the name to text_blocks and return reference of blocks
	return (text_blocks => [_parse_card_text_boxes($_[0])]);
}
sub _element_has_class {
	my ($element, $class_name) = @_;

	# No if element has no classes at all
	return !1 if !$element->hasAttribute('class');

	# Get the class names
	my @class = split m{\s+}msx, $element->getAttribute('class');

	# Return if any of the class names match
	return List::MoreUtils::any { $_ eq $class_name } @class;
}
sub _label_transform {
	my ($label) = @_;

	# Lower case
	$label = lc $label;

	# Trim leading whitespace
	$label =~ s{\A \s+}{}mosx;

	# Trim following whitespace and colon
	$label =~ s{:? \s* \z}{}mosx;

	# Change octothorpe to number
	$label =~ s{\#}{number}gmosx;

	# Change spaces and other non-alphanumeric into an underscore
	$label =~ s{\s+|\W}{_}gmosx;

	if ('card_' eq substr $label, 0, 5) {
		# Since this is a card, there is no need to have labels starting with card
		$label = substr $label, 5;
	}

	return $label;
}
sub _nvp_transform {
	my ($name, $value_element) = @_;

	# Name-value pairs to return
	my @nvp;

	if (exists $card_details_value_transform{$name}) {
		# Get the transform function
		my $transform = $card_details_value_transform{$name};

		# Get the value after being transformed
		my @value = $transform->($value_element);

		if (@value == 1) {
			# The transform function simply returned the value
			@nvp = ($name, $value[0]);
		}
		elsif (@value % 2 == 0) {
			# The transform function returned name-value pair(s)
			@nvp = @value;
		}
		else {
			# Something went wrong
			Carp::croak "Reading $name from the card details page failed";
		}
	}
	else {
		# Standard text transformation
		my $value = $value_element->textContent;
		$value =~ s{\A \s+}{}msx;
		$value =~ s{\s+ \z}{}msx;

		@nvp = ($name, $value);
	}

	return @nvp;
}
sub _parse_card_details_document {
	my ($document) = @_;

	# Get the card details tables
	my @tables = grep { _element_has_class($_, 'cardDetails') }
		$document->getElementsByTagName('table');

	if (!@tables) {
		Carp::croak 'No card details tables found in the document';
	}

	# For now, just use the first table
	my $card_details_table = shift @tables;

	# Get the right column
	my ($right_column) = grep { _element_has_class($_, 'rightCol') }
		map { $_->getChildrenByTagName('td') }
		$card_details_table->getChildrenByTagName('tbody')
		->shift->getChildrenByTagName('tr');

	my $pairs_div = $right_column->getChildrenByTagName('div')
		->get_node(2);

	# Get the multiverse ID from the first a element to have it
	my ($multiverse_id) = map { my ($id) = $_->getAttribute('href') =~ m{multiverseid=(\d+)}msx; defined $id ? $id : (); }
		$right_column->getChildrenByTagName('div')->get_node(1)->getElementsByTagName('a');

	# Start off the card arguments with the multiverse ID
	my @card_args = (multiverse_id => $multiverse_id);

	my @rows = grep { _element_has_class($_, 'row') }
		$pairs_div->getChildrenByTagName('div');

	for my $row (@rows) {
		my @div = $row->getChildrenByTagName('div');
		my $label = [grep { _element_has_class($_, 'label') } @div]->[0];
		my $value = [grep { _element_has_class($_, 'value') } @div]->[0];

		$label = _label_transform($label->textContent);

		push @card_args, _nvp_transform($label, $value);
	}

	return @card_args;
}
sub _parse_card_text_boxes {
	my ($element) = @_;

	# Get the text blocks
	my @text_blocks = grep { _element_has_class($_, 'cardtextbox') }
		$element->getChildrenByTagName('div');

	# Get the text of the blocks
	@text_blocks = map { _process_card_text_block($_) } @text_blocks;

	return @text_blocks;
}
sub _process_card_text_block {
	my ($text_block) = @_;

	my @text = map { $_->isa('XML::LibXML::Element') && $_->localname eq 'img' ? '{' . $_->getAttribute('alt') . '}' : $_->textContent } $text_block->childNodes;

	return join q{}, @text;
}

1;

__END__

=head1 NAME

WWW::Wizards::Gatherer::Utils - Utilities

=head1 VERSION

This documentation refers to version 0.001.

=head1 SYNOPSIS

  # TODO: Write this

=head1 DESCRIPTION

This provides common utility functions for WWW::Wizards::Gatherer.

=head1 FUNCTIONS

=head2 build_card_from_page

This function takes a single argument which is a URL of a card and will
parse the page and return a
L<WWW::Wizards::Gatherer::Card|WWW::Wizards::Gatherer::Card> object.

=head1 DEPENDENCIES

=over

=item * L<Carp|Carp>

=item * L<HTML::HTML5::Parser|HTML::HTML5::Parser> 0.101

=item * L<List::MoreUtils|List::MoreUtils>

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
