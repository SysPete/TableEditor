use Test::More;
use Test::Exception;
use Class::Load qw/try_load_class/;
use File::Spec;
use Dancer qw/:tests !after/;
use Dancer::Plugin::DBIC;

use lib File::Spec->catdir( 't', 'lib' );

set logger => "console";
set log => "debug";
set plugins => {
    DBIC => {
        default => {
            dsn => "dbi:SQLite:dbname=:memory:",
            schema_class => 'MyApp::Schema',
            options => {
                sqlite_unicode  => 1,
                on_connect_call => 'use_foreign_keys',
                quote_names     => 1,
            }
        }
    }
};

use TableEdit;
use Dancer::Test;

use strict;
use warnings;

my ( $schema, $rset, $result );

lives_ok( sub { $schema = schema }, "get schema" );

lives_ok( sub { $schema->deploy() }, "deploy" );
lives_ok( sub { $rset = $schema->resultset('Cd') }, "get Cd resultset" );

cmp_ok( $rset->count, '>', 0, "num Cds: " . $rset->count );

done_testing;

