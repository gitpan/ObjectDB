package ObjectDB::Meta::Relationship::OneToOne;

use strict;
use warnings;

our $VERSION = '3.04';

use base 'ObjectDB::Meta::Relationship::ManyToOne';

sub type { 'one to one' }

1;