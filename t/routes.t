use Test::More;
use Test::Exception;
use Class::Load qw/try_load_class/;
use File::Spec;
use Dancer qw/:tests !after/;
use Dancer::Plugin::DBIC;

use strict;
use warnings;

use lib File::Spec->catdir( 't', 'lib' );

use TableEdit;
use Dancer::Test;

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

my ( $schema, $rset, $resp );

lives_ok( sub { $schema = schema }, "get schema" );

lives_ok( sub { $schema->deploy() }, "deploy" );
lives_ok( sub { $rset = $schema->resultset('Cd') }, "get Cd resultset" );

cmp_ok( $rset->count, '>', 0, "num Cds: " . $rset->count );

lives_ok( sub { $resp = dancer_response GET => "/" }, "GET /" );

done_testing;

