package MyApp::Schema;
 
use warnings;
use strict;
 
use base qw/DBIx::Class::Schema/;
__PACKAGE__->load_namespaces;
 
sub deploy {
    my $schema = shift;
    $schema->next::method(@_);

    my @artists = ( ['Michael Jackson'], ['Eminem'] );
    $schema->populate( 'Artist', [ [qw/name/], @artists, ] );

    my %albums = (
        'Thriller'                => 'Michael Jackson',
        'Bad'                     => 'Michael Jackson',
        'The Marshall Mathers LP' => 'Eminem',
    );

    my @cds;
    foreach my $lp ( keys %albums ) {
        my $artist =
          $schema->resultset('Artist')->find( { name => $albums{$lp} } );
        push @cds, [ $lp, $artist->id ];
    }

    $schema->populate( 'Cd', [ [qw/title artistid/], @cds, ] );

    my %tracks = (
        'Beat It'         => 'Thriller',
        'Billie Jean'     => 'Thriller',
        'Dirty Diana'     => 'Bad',
        'Smooth Criminal' => 'Bad',
        'Leave Me Alone'  => 'Bad',
        'Stan'            => 'The Marshall Mathers LP',
        'The Way I Am'    => 'The Marshall Mathers LP',
    );

    my @tracks;
    foreach my $track ( keys %tracks ) {
        my $cd =
          $schema->resultset('Cd')->find( { title => $tracks{$track}, } );
        push @tracks, [ $cd->id, $track ];
    }

    $schema->populate( 'Track', [ [qw/cdid title/], @tracks, ] );
}

1;

=pod

Copyright 2015, Peter Mottram <peter@sysnix.com>.

Original copyright and licence for the following files:

t/lib/MyApp/Schema.pm
t/lib/MyApp/Schema/Result/Cd.pm
t/lib/MyApp/Schema/Result/Track.pm
t/lib/MyApp/Schema/Result/Artist.pm

along with code taken from the following L<DBIx::Class> example file:

examples/Schema/insertdb.pl

can be found here: L<https://metacpan.org/pod/DBIx::Class#COPYRIGHT-AND-LICENSE>
and the original text is:

COPYRIGHT AND LICENSE

Copyright (c) 2005 by mst, castaway, ribasushi, and other DBIx::Class "AUTHORS" as listed above and in AUTHORS.

This library is free software and may be distributed under the same terms as perl5 itself. See LICENSE for the complete licensing terms.
