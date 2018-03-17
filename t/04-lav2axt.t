use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Egaz;

my $result = test_app( 'App::Egaz' => [qw(help lav2axt)] );
like( $result->stdout, qr{lav2axt}, 'descriptions' );

$result = test_app( 'App::Egaz' => [qw(lav2axt)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Egaz' => [qw(lav2axt t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

$result
    = test_app( 'App::Egaz' => [qw(lav2axt t/base_test.default.lav -o stdout)] );
is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 42, 'line count' );
like( $result->stdout, qr{TCTTTGCCGGAGCACTCTATTCTACATGGAA-----AACTATAAG}, 'sequences' );

done_testing();
