package Types::Mojo;

# ABSTRACT: Types related to Mojo

use v5.10;

use strict;
use warnings;

use Type::Library
   -base,
   -declare => qw( MojoCollection MojoFile MojoFileList );

use Type::Utils -all;
use Types::Standard -types;

use Mojo::File;
use Mojo::Collection;
use Scalar::Util qw(blessed);
use List::Util qw(first);

Type::Utils::extends(qw/Types::Standard/);

our $VERSION = '0.02';

my $meta = __PACKAGE__->meta;

$meta->add_type(
    name => 'MojoCollection',
    parent => InstanceOf['Mojo::Collection'],
    constraint_generator => sub {
        return $meta->get_type('MojoCollection') if !@_;

        my $type  = $_[0];
        my $check = $meta->get_type( $_[0] );
        
        return sub {
            return if !blessed $_ and $_->isa('Mojo::Collection');

            my $fail = $_->first( sub {
                !$check->( $_ );
            });

            !$fail;
        };
    },
    coercion_generator => sub {
        my ($parent, $child, $param) = @_;
        return $parent->coercion;
    },
    #inline_generator => sub {},
    #deep_explanation => sub {},
);

coerce MojoCollection,
    from ArrayRef, via { Mojo::Collection->new( @{$_} ) }
;

class_type MojoFile, { class => 'Mojo::File' };

coerce MojoFile,
    from Str, via { Mojo::File->new( $_ ) }
;

declare MojoFileList,
    as MojoCollection[MojoFile];

coerce MojoFileList,
    from MojoCollection[Str],
        via {
            my $new = $_->map( sub { Mojo::File->new($_) } );
            $new;
        },
    from ArrayRef[Str],
        via { 
            my @list = @{$_};
            Mojo::Collection->new( map{ Mojo::File->new( $_ ) } @list );
        },
    from ArrayRef[MojoFile],
        via {
            Mojo::Collection->new( @{ $_ } );
        }
;

__PACKAGE__->meta->make_immutable;

1;

=head1 SYNOPSIS

    package MyClass;
    
    use Moo;
    use Types::Mojo qw(MojoFile MojoCollection);
    
    has file => ( is => 'rw', isa => MojoFile, coerce => 1 );
    has coll => ( is => 'rw', isa => MojoCollection, coerce => 1 );
    has ints => ( is => 'rw', isa => MojoCollection[Int] );
    
    1;

In the script

    use MyClass;
    my $object = MyClass->new( file => __FILE__ ); # will be coerced into a Mojo::File object
    say $object->file->move_to( '/path/to/new/location' );

    my $object2 = MyClass->new( coll => [qw/a b/] );
    $object2->coll->each(sub {
        say $_;
    });

=head1 TYPES

=head2 MojoCollection[`a]

An object of L<Mojo::Collection>. Can be parameterized with an other L<Type::Tiny> type.

    has ints => ( is => 'rw', isa => MojoCollection[Int] );

will accept only a C<Mojo::Collection> of integers.

=head2 MojoFile

An object of L<Mojo::File>

=head2 MojoFileList

A C<MojoCollection> of C<MojoFile>s.

=head1 COERCIONS

These coercions are defined.

=head2 To MojoCollection

=over 4

=item * Array reference to MojoCollection

In a class

    package Test;
    
    use Moo;
    use Types::Mojo qw(MojoCollection);
    
    has 'collection' => ( is => 'ro', isa => MojoCollection, coerce => 1 );
    
    1;

In the script

    use Test;

    use v5.22;
    use feature 'postderef';

    my $obj = Test->new(
        collection => [ 1, 2 ],
    );
    
    my $sqrs = $obj->collection->map( sub { $_ ** 2 } );
    say $_ for $sqrs->to_array->@*;

=back

=head2 To MojoFile

=over 4

=item * String to MojoFile

In a class

    package Test;
    
    use Moo;
    use Types::Mojo qw(MojoFile);
    
    has 'file' => ( is => 'ro', isa => MojoFile, coerce => 1 );
    
    1;

In the script

    use Test;

    use v5.22;

    my $obj = Test->new(
        file => __FILE__,
    );
    
    say $obj->file->slurp;

=back

=head2 To MojoFileList

=over 4

=item * MojoCollection of Strings

In a class

    package Test;
    
    use Moo;
    use Types::Mojo qw(MojoFile);
    
    has 'files' => ( is => 'ro', isa => MojoFileList, coerce => 1 );
    
    1;

In the script

    use Test;

    use v5.22;

    my $obj = Test->new(
        files => Mojo::Collection->(__FILE__),
    );

    for my $file ( @{ $obj->files->to_array } ) {
        say $file->basename;
    }

=item * Array of Strings

In a class

    package Test;
    
    use Moo;
    use Types::Mojo qw(MojoFile);
    
    has 'files' => ( is => 'ro', isa => MojoFileList, coerce => 1 );
    
    1;

In the script

    use Test;

    use v5.22;

    my $obj = Test->new(
        files => [__FILE__],
    );

    for my $file ( @{ $obj->files->to_array } ) {
        say $file->basename;
    }

=item * Array of MojoFile

In a class

    package Test;
    
    use Moo;
    use Types::Mojo qw(MojoFileList);
    
    has 'files' => ( is => 'ro', isa => MojoFileList, coerce => 1 );
    
    1;

In the script

    use Test;

    use v5.22;

    my $obj = Test->new(
        files => [Mojo::File->new(__FILE__)],
    );

    for my $file ( @{ $obj->files->to_array } ) {
        say $file->basename;
    }

=back

