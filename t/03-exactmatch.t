use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Egaz;

my $result = test_app( 'App::Egaz' => [qw(help exactmatch)] );
like( $result->stdout, qr{exactmatch}, 'descriptions' );

$result = test_app( 'App::Egaz' => [qw(exactmatch)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Egaz' => [qw(exactmatch t/not_exists t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

$result = test_app( 'App::Egaz' => [qw(exactmatch t/not_exists t/pseudopig.fa)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

SKIP: {
    skip "samtools not installed", 2 unless IPC::Cmd::can_run('samtools');
    skip "mummer of sparsemem not installed", 2
        unless IPC::Cmd::can_run('mummer')
        or IPC::Cmd::can_run('sparsemem');

    $result = test_app( 'App::Egaz' => [qw(exactmatch t/pig2.fa t/pseudopig.fa)] );
    is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 1, 'line count' );
    like( $result->stdout, qr{pig2\(\+\):1\-22929}, 'exact position' );
}

done_testing();
