use 5.008003;
use strict;
use warnings 'all';

use Module::Build 0.31;

my $build = Module::Build->new(
	module_name => 'WWW::Wizards::Gatherer',
	license     => 'perl',
	dist_author => 'Douglas Christopher Wilson <doug@somethingdoug.com>',

	meta_merge => {
		resources => {
			homepage   => 'http://github.com/dougwilson/perl5-www-wizards-gatherer/',
			repository => 'git://github.com/dougwilson/perl5-www-wizards-gatherer.git',
		},
		no_index => {
			directory => [qw/inc t xt/],
		},
	},

	# Module that are required for tests in t/
	build_requires => {
#		'Test::Exception'           => '0.03',
#		'Test::More'                => 0,
	},

	# Module that are required
	requires => {
		'perl'                          => '5.008003',
		'Carp'                          => 0,
		'Data::Stream::Bulk::DoneFlag'  => '0.08',
		'Encode'                        => 0,
		'HTML::HTML5::Parser'           => '0.101',
		'List::MoreUtils'               => 0,
		'Moose'                         => '1.05',
		'Moose::Util::TypeConstraints'  => 0,
		'MooseX::StrictConstructor'     => '0.09',
		'MooseX::Types::Common::String' => 0,
		'MooseX::Types::LWP::UserAgent' => '0.02',
		'MooseX::Types::Moose'          => 0,
		'MooseX::Types::URI'            => 0,
		'URI'                           => 0,
		'URI::QueryParam'               => 0,
		'namespace::clean'              => '0.10',
	},

	# Enable tests to be in multi-level directories
	recursive_test_files => 1,

	# Create a LICENSE file
	create_license => 1,

	test_files => 't/*.t xt/*.t',
);

$build->create_build_script;
