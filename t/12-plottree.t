use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Egaz;

my $result = test_app( 'App::Egaz' => [qw(help plottree)] );
like( $result->stdout, qr{plottree}, 'descriptions' );

$result = test_app( 'App::Egaz' => [qw(plottree)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Egaz' => [qw(plottree t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

SKIP: {
    skip "R not installed", 2
        unless IPC::Cmd::can_run('Rscript');

    my $t_path = Path::Tiny::path("t/")->absolute->stringify;
    my $cwd    = Path::Tiny->cwd;

    my $tempdir = Path::Tiny->tempdir;
    chdir $tempdir;

    test_app( 'App::Egaz' => [ "plottree", "$t_path/YDL184C.nwk", "-o", "YDL184C.pdf", ] );
    ok( $tempdir->child("YDL184C.pdf")->is_file, 'pdf created' );

    Path::Tiny::path("$t_path/YDL184C.nwk")->copy("temp.nwk");
    test_app( 'App::Egaz' => [ "plottree", "temp.nwk", ] );
    ok( $tempdir->child("temp.nwk.pdf")->is_file, 'pdf with default name' );

    chdir $cwd;    # Won't keep tempdir
}

done_testing();
