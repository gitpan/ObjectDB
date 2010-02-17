package ObjectDB::Meta;

use strict;
use warnings;

use base 'ObjectDB::Base';

require Storable;
require Carp;

__PACKAGE__->attr('table', chained => 1);
__PACKAGE__->attr('auto_increment', chained => 1);
__PACKAGE__->attr('relationships' => (chained => 1, default => sub { {} }));
__PACKAGE__->attr('class', chained => 1);

__PACKAGE__->attr('_primary_keys', default => sub {[]}, chained => 1);
__PACKAGE__->attr('_unique_keys', default => sub {[]}, chained => 1);
__PACKAGE__->attr('_columns', default => sub {{}}, chained => 1);
__PACKAGE__->attr('_columns_array', default => sub {[]}, chained => 1);

use ObjectDB::RelationshipFactory;

our %objects;

sub new {
    my $class     = shift;
    my $for_class = shift;
    my %params    = @_;

    foreach my $parent (_get_parents($for_class)) {
        if (my $parent_meta = $objects{$parent}) {
            my $meta = Storable::dclone($parent_meta);

            $meta->class($for_class);

            return $meta;
        }
    }

    my %values;

    my $columns        = delete $params{columns};
    my $primary_keys   = delete $params{primary_keys};
    my $unique_keys    = delete $params{unique_keys};
    my $table          = delete $params{table};
    my $auto_increment = delete $params{auto_increment};

    Carp::croak("No table in $for_class") unless $table;
    Carp::croak("No columns in $for_class") unless $columns;
    Carp::croak("No primary keys in $for_class") unless $primary_keys;

    my @columns_raw =
      ref $columns ? @{$columns} : ($columns);

    my @columns = ();
    $columns = {};
    my $prev;
    while (my $col = shift @columns_raw) {
        if (ref $col eq 'HASH') {
            $columns->{$prev} = $col;
        } else {
            $columns->{$col} = {};
            push @columns, $col;
        }
        $prev = $col;
    }

    $primary_keys = ref $primary_keys ? $primary_keys : [$primary_keys];
    $unique_keys = ref $unique_keys ? $unique_keys : [$unique_keys];

    my $self = $class->SUPER::new(
        class          => $for_class,
        table          => $table,
        auto_increment => $auto_increment,
        _columns       => $columns,
        _columns_array => \@columns,
        _primary_keys  => $primary_keys,
        _unique_keys   => $unique_keys,
        @_
    );

    # init relationship classes
    if ($self->relationships && %{$self->relationships}) {
        foreach my $rel (keys %{$self->relationships}) {
            $self->relationships->{$rel} =
              ObjectDB::RelationshipFactory->build(
                %{$self->relationships->{$rel}},
                orig_class => $for_class);
        }
    }

    return $self;
}

sub is_column {
    my $self = shift;
    my ($name) = @_;

    return unless $name;

    return exists $self->_columns->{$name};
}

sub is_primary_key {
    my $self = shift;
    my ($name) = @_;

    return 0 unless $name;

    my @rv = grep {$name eq $_} $self->primary_keys;
    return @rv ? 1 : 0;
}

sub is_auto_increment {
    my $self = shift;
    my ($name) = @_;

    return 0 unless $name;

    return 0 unless $self->auto_increment;

    return 0 unless $self->auto_increment eq $name;

    return 1;
}

sub is_unique_key {
    my $self = shift;
    my ($name) = @_;

    return 0 unless $name;

    return 0 unless $self->unique_keys;

    my @rv = grep {$name eq $_} $self->unique_keys;
    return @rv ? 1 : 0;
}

sub columns {
    my $self = shift;

    return @{$self->_columns_array};
}

sub primary_keys {
    my $self = shift;

    return @{$self->_primary_keys};
}

sub unique_keys {
    my $self = shift;

    return () unless defined $self->_unique_keys->[0];

    return @{$self->_unique_keys};
}

sub add_column {
    my $self = shift;
    my ($name, $options) = @_;

    return unless $name;

    $options ||= {};

    $self->_columns->{$name} = $options;
    push @{$self->_columns_array}, $name;
}

sub add_columns {
    my $self = shift;

    my $count = 0;
    while (my ($name, $options) = @_[$count, $count + 1]) {
        last unless $name;

        if (ref $options eq 'HASH') {
            $self->add_column($name, $options);
        }
        else {
            $self->add_column($name);

            $count++;
            next;
        }

        $count += 2;
    }
}

sub add_relationship {
    my $self = shift;
    my ($name, $options) = @_;

    return unless $name && $options;

    $self->relationships->{$name} =
      ObjectDB::RelationshipFactory->build(%$options,
        orig_class => $self->class);
}

sub add_relationships {
    my $self = shift;

    my $count = 0;
    while (my ($name, $options) = @_[$count, $count + 1]) {
        last unless $name && $options;

        $self->add_relationship($name, $options);

        $count += 2;
    }
}

sub del_column {
    my $self = shift;
    my ($name) = @_;

    return unless $name && $self->is_column($name);

    delete $self->_columns->{$name};

    @{$self->_columns_array} = grep { $_ ne $name } $self->columns;
}

sub _get_parents {
    my $class = shift;
    my @parents;

    no strict 'refs';
    # shift our class name
    foreach my $sub_class (@{"${class}::ISA"}) {
        push (@parents, _get_parents($sub_class))
          if ($sub_class->isa('ObjectDB') && $sub_class ne 'ObjectDB');
    }

    return $class, @parents;
}

1;