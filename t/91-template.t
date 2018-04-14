#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

#use App::Cmd::Tester;
use App::Cmd::Tester::CaptureExternal;

use App::Egaz;

my $result = test_app( 'App::Egaz' => [qw(help template)] );
like( $result->stdout, qr{template}, 'descriptions' );

$result = test_app( 'App::Egaz' => [qw(template)] );
like( $result->error, qr{need .+ dir}, 'need directory' );

$result = test_app( 'App::Egaz' => [qw(template t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'not exists' );

{
    my $t_path = Path::Tiny::path("t/")->absolute->stringify;
    my $cwd    = Path::Tiny->cwd;

    my $tempdir = Path::Tiny->tempdir;
    chdir $tempdir;

    $result = test_app(
        'App::Egaz' => [ "template", "$t_path/pseudocat", "$t_path/pseudopig", "--verbose", ] );

    is( $result->error, undef, 'threw no exceptions' );
    is( ( scalar grep {/\S/} split( /\n/, $result->stdout ) ), 0, 'no stdout' );
    ok( $tempdir->child("1_pair_cmd.sh")->is_file, '1_pair_cmd.sh exists' );
    like( $result->stderr, qr{name: pseudocat.+name: pseudopig}s, 'names and directories' );

    chdir $cwd;    # Won't keep tempdir
}

done_testing();
