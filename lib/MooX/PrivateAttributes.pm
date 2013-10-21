#
# This file is part of MooX-PrivateAttributes
#
# This software is copyright (c) 2013 by celogeek <me@celogeek.com>.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
package MooX::PrivateAttributes;

# ABSTRACT: Create attribute only usable inside your package

use strict;
use warnings;
our $VERSION = '0.01';    # VERSION
use Carp;

sub import {
    my $target = caller;

    return
        if $target->can('private_has')
        && $target->can('private_with_deprecated_has');

    my $around = $target->can('around');
    my $has    = $target->can('has');

    my $ensure_call_in_target = sub {
        my ( $name, $deprecated_mode, $unless_method ) = @_;
        return sub {
            my $orig   = shift;
            my $self   = shift;
            my @params = @_;

            return $self->$orig(@params) if @params;    #write is permitted
            if ( defined $unless_method ) {
                return $self->$orig(@params) if $unless_method->();
            }

            my $caller = caller(2);

            return $self->$orig if $caller eq $target;

            if ($deprecated_mode) {
                carp
                    "DEPRECATED: You can't use the attribute <$name> outside the package <$target> !";
                return $self->$orig;
            }
            else {
                croak
                    "You can't use the attribute <$name> outside the package <$target> !";
            }
            }
    };

    my $private_has = sub {
        my ( $name, %attributes ) = @_;
        my $unless_method = delete $attributes{'unless'};
        croak "unless option should be a CODE REF"
            if defined $unless_method && ref $unless_method ne 'CODE';
        $has->( $name, %attributes );
        $around->(
            $name, $ensure_call_in_target->( $name, 0, $unless_method )
        );
    };

    my $private_with_deprecated_has = sub {
        my ( $name, %attributes ) = @_;
        my $unless_method = delete $attributes{'unless'};
        croak "unless option should be a CODE REF"
            if defined $unless_method && ref $unless_method ne 'CODE';
        $has->( $name, %attributes );
        $around->(
            $name, $ensure_call_in_target->( $name, 1, $unless_method )
        );
    };

    if ( my $info = $Role::Tiny::INFO{$target} ) {
        $info->{not_methods}{$private_has} = $private_has;
        $info->{not_methods}{$private_with_deprecated_has}
            = $private_with_deprecated_has;
    }

    { no strict 'refs'; *{"${target}::private_has"} = $private_has }
    {
        no strict 'refs';
        *{"${target}::private_with_deprecated_has"}
            = $private_with_deprecated_has
    }

    return;
}

1;

__END__

=pod

=head1 NAME

MooX::PrivateAttributes - Create attribute only usable inside your package

=head1 VERSION

version 0.01

=head1 SYNOPSIS

You can use it in a role (Moo, Moose, Mo with a trick)

  package myRole;
  use Moo::Role;
  use MooX::PrivateAttributes;

  private_has 'foo' => (is => 'ro');

  sub display_foo { print shift->foo, "\n" }

  1;

Or also directly in you class

  package myApp;
  use Moo;
  use MooX::PrivateAttributes;

  private_has 'bar' => (is => 'ro');

  sub display_bar { print shift->bar, "\n" }

  1;

Then

  myApp->bar("123");
  myApp->bar         # croak
  myApp->display_bar # 123

=head1 DESCRIPTION

It happend that you may want to create a class with private attributes that can't be used outside this package.

For example, you want to create in lazy, a DB connection, but you want to handle it in your class in a specific way (with possible handle of errors ....).
You really want, even with the "_" before your attribute (which mean private), to avoid access of this attribute by any other packages.

The goal of this package is to allow the init of the private attribute, but forbid reading from outside the package.

With a private attribute named "foo" for example, you can't do this outside the current package :

  my $foo = $myObj->foo;

or

  $myObj->foo->stuff();

But this method is allowed inside the package where it has been declared.

=head1 METHODS

=head2 import

The method provide 2 methods :

=over

=item private_has

Like a "has", disable read access outside the current class.

=item private_with_deprecated_has

Instead of dying, it will display a DEPRECATED message and run as usual.
This allow you to alert user of the private method to fix their program before you forbid the access to the attribute.

=item unless attribute option

You can use the "unless" => sub { $condition } option to your attribute.

If the condition match, the attribute will not generate any warnings or die

  protect_has "foo" => (is => 'ro'), unless => sub { $ENV{SKIP_WARNING} };

  $myObj->foo # croak
  
  {
	local $ENV{SKIP_WARNING} = 1;
    $myObj->foo # works
  }

You can use it for your test, or may be to match some condition like 'OK if it is call from this package'

=back

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
https://tasks.celogeek.com/projects/moox-privateattributes

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

celogeek <me@celogeek.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by celogeek <me@celogeek.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
