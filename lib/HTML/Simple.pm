package HTML::Simple;

use warnings;
use strict;
use Carp;
use Scalar::Util qw(blessed looks_like_number);

use version; our $VERSION = qv( '0.2' );

BEGIN {

    # http://www.w3schools.com/tags/default.asp
    for my $tag (
        qw( a abbr acronym address area b base bdo big blockquote body
        button caption cite code col colgroup dd del div dfn dl dt em
        fieldset form frame frameset h1 h2 h3 h4 h5 h6 head hr html i
        iframe img ins kbd label legend li link map meta noframes
        noscript object ol optgroup option p param pre q samp script
        select small span strong style sub sup table tbody td textarea
        tfoot th thead title tr tt ul var )
      ) {
        no strict 'refs';
        *$tag = sub { shift->tag( $tag, @_ ) };
    }

    for my $tag ( qw( br input ) ) {
        no strict 'refs';
        *$tag = sub { shift->closed( $tag, @_ ) };
    }
}

my %ENT_MAP = (
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
    "'" => '&apos;',
);

my @UNPRINTABLE = qw(
  z    x01  x02  x03  x04  x05  x06  a
  x08  t    n    v    f    r    x0e  x0f
  x10  x11  x12  x13  x14  x15  x16  x17
  x18  x19  x1a  e    x1c  x1d  x1e  x1f
);

sub _hash_re {
    my $hash = shift;
    my $match = join( '|', map quotemeta, sort keys %$hash );
    return qr/($match)/;
}

my $ENT_RE = _hash_re( \%ENT_MAP );

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->_initialize( @_ );
    return $self;
}

sub _initialize {
    my $self = shift;
}

sub _str {
    my $obj = shift;
    # Flatten array refs...
    return join '', @$obj
      if 'ARRAY' eq ref $obj;
    # ...stringify objects...
    return $obj->as_string
      if blessed $obj && $obj->can( 'as_string' );
    # ...default stringification
    return "$obj";
}

# URL encode a string
sub url_encode {
    my $self = shift;
    my $str  = _str( shift );
    $str =~ s/([^A-Za-z0-9_])/$1 eq ' ' ? '+' : sprintf("%%%02x", ord($1))/eg;
    return $str;
}

sub url_decode {
    my $self = shift;
    my $str  = shift;
    $str =~ s/[+]/ /g;
    $str =~ s/%([0-9a-f]{2})/chr(hex($1))/eg;
    return $str;
}

# Turn a hash reference into a query string.
sub query_encode {
    my $self = shift;
    my $hash = shift || {};
    return join '&', map {
        join( '=', map { $self->url_encode( $_ ) } ( $_, $hash->{$_} ) )
    } sort grep { defined $hash->{$_} } keys %$hash;
}

# (X)HTML entity encode a string
sub entity_encode {
    my $self = shift;
    my $str  = _str( shift );
    $str =~ s/$ENT_RE/$ENT_MAP{$1}/eg;
    return $str;
}

sub _tag {
    my $self   = shift;
    my $closed = shift;
    my $name   = shift;

    croak "Attributes must be passed as hash references"
      if grep { 'HASH' ne ref $_ } @_;

    # Merge attribute hashes
    my %attr = map { %$_ } @_;

    # Generate markup
    return "<$name"
      . join( '',
        map { ' ' . $_ . '="' . $self->entity_encode( $attr{$_} ) . '"' }
          sort grep { defined $attr{$_} } keys %attr )
      . ( $closed ? ' />' : '>' );
}

sub tag {
    my $self = shift;
    my $name = shift;

    my %attr = ();
    my @out  = ();

    for my $a ( @_ ) {
        if ( 'HASH' eq ref $a ) {
            # Merge into attributes
            %attr = ( %attr, %$a );
        }
        else {
            # Generate markup
            push @out,
              $self->_tag( 0, $name, \%attr )
              . _str( $a )
              . $self->close( $name );
        }
    }

    return wantarray ? @out : join '', @out;
}

sub open   { shift->_tag( 0, @_ ) }
sub closed { shift->_tag( 1, @_ ) }

# Generate a closing (X)HTML tag
sub close {
    my $self = shift;
    my $name = shift;
    return "</$name>";
}

# Minimal JSON encoder
sub json_encode {
    my $self = shift;
    my $obj  = shift;
    if ( my $type = ref $obj ) {
        if ( 'HASH' eq $type ) {
            return '{' . join(
                ',',
                map {
                    join( ':',
                        map { $self->json_encode( $_ ) } ( $_, $obj->{$_} ) )
                  } sort keys %$obj
            ) . '}';
        }
        elsif ( 'ARRAY' eq $type ) {
            return '['
              . join( ',', map { $self->json_encode( $_ ) } @$obj ) . ']';
        }
    }

    if ( looks_like_number $obj ) {
        return $obj;
    }

    $obj = _str( $obj );
    $obj =~ s/\\/\\\\/g;
    $obj =~ s/"/\\"/g;
    $obj =~ s/ ( [\x00-\x1f] ) / '\\' . $UNPRINTABLE[ ord($1) ] /gex;

    return qq{"$obj"};
}

1;
__END__

=head1 NAME

HTML::Simple - Simple HTML generation utilities

=head1 VERSION

This document describes HTML::Simple version 0.2

=head1 SYNOPSIS

    use HTML::Simple;

    my $h = HTML::Simple->new;

    # Generate a simple page
    print $h->html(
        [
            $h->head( $h->title( 'Sample page' ) ),
            $h->body(
                [
                    $h->h1( { class => 'main' }, 'Sample page' ),
                    $h->p( 'Hello, World', { class => 'detail' }, 'Second para' )
                ]
            )
        ]
    );

    # Outputs
    <html>
        <head>
            <title>Sample page</title>
        </head>
        <body>
            <h1 class="main">Sample page</h1>
            <p>Hello, World</p>
            <p class="detail">Second para</p>
        </body>
    </html>

=head1 DESCRIPTION

C<< HTML::Simple >> is a simple, dependency free module for
generating HTML (and XML). It concentrates on generating
syntactically correct XHTML using a simple Perl notation.

In addition to the HTML generation functions utility functions are
provided to

=over

=item * encode and decode URL encoded strings

=item * entity encode HTML

=item * build query strings

=item * JSON encode data structures

=back

=head1 INTERFACE

=over

=item C<< new >>

Create a new C<< HTML::Simple >>. No arguments

=back

=head2 HTML Generation

=over

=item C<< tag( $name, ... ) >>

Returns HTML (or XML) that encloses each of the arguments in the specified tag. For example

    print $h->tag('p', 'Hello', 'World');

would print

    <p>Hello</p><p>World</p>

notice that each argument is individually wrapped in the specified tag.
To avoid this multiple arguments can be grouped in an anonymous array:

    print $h->tag('p', ['Hello', 'World']);

would print

    <p>HelloWorld</p>

The [ and ] can be thought of as grouping a number of arguments.

Attributes may be supplied by including an anonymous hash in the
argument list:

    print $h->tag('p', { class => 'normal' }, 'Foo');

would print

    <p class="normal">Foo</p>

Attribute values will be HTML entity encoded as necessary.

Multiple hashes may be supplied in which case they will be merged:

    print $h->tag('p',
        { class => 'normal' }, 'Bar',
        { style => 'color: red' }, 'Bang!'
    );

would print

    <p class="normal">Bar</p><p class="normal" style="color: red">Bang!</p>

Notice that the class="normal" attribute is merged with the style
attribute for the second paragraph.

To remove an attribute set its value to undef:

    print $h->tag('p',
        { class => 'normal' }, 'Bar',
        { class => undef }, 'Bang!'
    );

would print

    <p class="normal">Bar</p><p>Bang!</p>

B<Return Value>

In a scalar context C<< tag >> returns a string. In a list context it
returns an array each element of which corresponds to one of the
original arguments:

    my @html = $h->tag('p', 'this', 'that');

would return

    @html = (
        '<p>this</p>',
        '<p>that</p>'
    );

That means that when you nest calls to tag (or the equivalent HTML
aliases - see below) the individual arguments to the inner call will be
tagged separately by each enclosing call. In practice this means that

    print $h->tag('p', $h->tag('b', 'Foo', 'Bar'));

would print

    <p><b>Foo</b></p><p><b>Bar</b></p>

You can modify this behavior by grouping multiple args in an
anonymous array:

    print $h->tag('p', [ $h->tag('b', 'Foo', 'Bar') ] );

would print

    <p><b>Foo</b><b>Bar</b></p>

This behaviour is powerful but can take a little time to master. If
you imagine '[' and ']' preventing the propagation of the 'tag
individual items' behaviour you might be close to being able to
visualise how it works.

Here's an HTML table (using the tag-name convenience methods - see
below) that demonstrates it in more detail:

    print $h->table(
        [
            $h->tr(
                [ $h->th( 'Name', 'Score', 'Position' ) ],
                [ $h->td( 'Therese',  90, 1 ) ],
                [ $h->td( 'Chrissie', 85, 2 ) ],
                [ $h->td( 'Andy',     50, 3 ) ]
            )
        ]
    );

which would print the unformatted version of:

    <table>
        <tr><th>Name</th><th>Score</th><th>Position</th></tr>
        <tr><td>Therese</td><td>90</td><td>1</td></tr>
        <tr><td>Chrissie</td><td>85</td><td>2</td></tr>
        <tr><td>Andy</td><td>50</td><td>3</td></tr>
    </table>

Note how you don't need a td() for every cell or a tr() for every row.
Notice also how the square brackets around the rows prevent tr() from
wrapping each individual cell.

=item C<< open( $name, ... ) >>

Generate an opening HTML or XML tag. For example:

    print $h->open('marker');

would print

    <marker>

Attributes can be provided in the form of anonymous hashes in the same way as for C<< tag >>. For example:

    print $h->open('marker', { lat => 57.0, lon => -2 });

would print

    <marker lat="57.0" lon="-2">

As for C<< tag >> multiple attribute hash references will be merged. The example above could be written:

    print $h->open('marker', { lat => 57.0 }, { lon => -2 });

=item C<< close( $name ) >>

Generate a closing HTML or XML tag. For example:

    print $h->close('marker');

would print:

    </marker>

=item C<< closed( $name, ... ) >>

Generate a closed HTML or XML tag. For example

    print $h->closed('marker');

would print:

    <marker />

As for C<< tag >> and C<< open >> attributes may be provided as hash references:

    print $h->closed('marker', { lat => 57.0 }, { lon => -2 });

would print:

    <marker lat="57.0" lon="-2" />

=item Methods named after tags

In addition to the methods described above C<< HTML::Simple >> provides
all of the following HTML generation methods:

    a abbr acronym address area b base bdo big blockquote body br
    button caption cite code col colgroup dd del div dfn dl dt em
    fieldset form frame frameset h1 h2 h3 h4 h5 h6 head hr html i
    iframe img input ins kbd label legend li link map meta noframes
    noscript object ol optgroup option p param pre q samp script select
    small span strong style sub sup table tbody td textarea tfoot th
    thead title tr tt ul var

With the exception of C<< br >> and C<< input >> they are all called in
the same way as C<< tag >> above - but with the tag name missing.

So the following are equivalent:

    print $h->a({ href => 'http://hexten.net' }, 'Hexten');

and

    print $h->tag('a', { href => 'http://hexten.net' }, 'Hexten');

C<< br >> and C<< input >> always generate closed XML style tags (in
fact they called C<< closed >>).

    print $h->br;   # prints <br />
    print $h->input({ name => 'field1' });
                    # prints <input name="field1" />

There's no way to override this default behaviour. If you need finer
control over whether the tag is open or closed call C<tag>, C<open>,
C<close> and C<closed> directly.

=back

=head2 Utility Methods

=over

=item C<< url_encode( $str ) >>

URL encode a string. Spaces become '+' and unprintable characters are
encoded as '%' + their hexadecimal character code.

    $h->url_encode( ' <hello> ' )   # returns '+%3chello%3e+'

=item C<< url_decode( $str ) >>

URL decode a string. Reverses the effect of C<< url_encode >>.

    $h->url_decode( '+%3chello%3e+' )   # returns ' <hello> '

=item C<< query_encode( $hash_ref ) >>

Generate a query string from an anonymous hash of key, value pairs:

    print $h->query_encode({ a => 1, b => 2 })

would print

    a=1&b=2

=item C<< entity_encode( $str ) >>

Encode the characters '<', '>', '&', '\'' and '"' as their HTML entity
equivalents:

    print $h->entity_encode( '<>\'"&' );

would print:

    &lt;&gt;&apos;&quot;&amp;

=item C<< json_encode >>

Encode a data structure in JSON (Javascript) format:

    print $h->json_encode( { ar => [ 1, 2, 3, { a => 1, b => 2 } ] } )

would print:
    
    {"ar":[1,2,3,{"a":1,"b":2}]}

Because JSON is valid Javascript this method can be useful when generating ad-hoc Javascript. For example

    my $some_perl_data = {
        score   => 45,
        name    => 'Fred',
        history => [ 32, 37, 41, 45 ]
    };

    # Transfer value to Javascript
    print $h->script( { type => 'text/javascript' },
        "\nvar someVar = " . $h->json_encode( $some_perl_data ) . ";\n " );

    # Prints
    # <script type="text/javascript">
    # var someVar = {"history":[32,37,41,45],"name":"Fred","score":45};
    # </script>

=back

=head1 CONFIGURATION AND ENVIRONMENT

HTML::Simple requires no configuration files or environment variables.

=head1 DEPENDENCIES

By design HTML::Simple has no non-core dependencies.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-html-simple@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Andy Armstrong  C<< <andy@hexten.net> >>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Andy Armstrong C<< <andy@hexten.net> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.