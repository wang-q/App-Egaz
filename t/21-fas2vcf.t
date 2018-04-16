use strict;
use warnings;
use Test::More;
use App::Cmd::Tester;

use App::Egaz;

my $result = test_app( 'App::Egaz' => [qw(help fas2vcf)] );
like( $result->stdout, qr{fas2vcf}, 'descriptions' );

$result = test_app( 'App::Egaz' => [qw(fas2vcf)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Egaz' => [qw(fas2vcf t/not_exists)] );
like( $result->error, qr{need .+input file}, 'need infile' );

$result = test_app( 'App::Egaz' => [qw(fas2vcf t/not_exists t/not_exists)] );
like( $result->error, qr{doesn't exist}, 'infile not exists' );

SKIP: {
    skip "snp-sites or vcf-concat not installed", 4
        unless IPC::Cmd::can_run('snp-sites')
        and IPC::Cmd::can_run('vcf-concat');

    my $t_path = Path::Tiny::path("t/")->absolute->stringify;
    my $cwd    = Path::Tiny->cwd;

    my $tempdir = Path::Tiny->tempdir;
    chdir $tempdir;

    $result = test_app(
        'App::Egaz' => [
            "fas2vcf", "$t_path/YDL184C.fas", "$t_path/S288c.chr.sizes", "-o", "YDL184C.vcf", "-v",
        ]
    );
    is( ( scalar grep {/\S/} split( /\n/, $result->stderr ) ), 3, 'stderr line count' );
    ok( $tempdir->child("YDL184C.vcf")->is_file, 'YDL184C.vcf exists' );

    # can't capture stdout
    $result
        = test_app( 'App::Egaz' =>
            [ "fas2vcf", "$t_path/example.fas", "$t_path/S288c.chr.sizes", "-o", "example.vcf","-v",  ]
        );
    is( ( scalar grep {/\S/} split( /\n/, $result->stderr ) ), 5, 'stderr line count' );
    is( ( scalar grep {/^CMD/} grep {/\S/} split( /\n/, $result->stderr ) ), 2, 'CMD count' );

    my $content = $tempdir->child("example.vcf")->slurp;
    like( $content, qr{ID=I,length=230218}, '##contig exists' );
    is( ( scalar grep {!/^#/} grep {/\S/} split( /\n/, $content ) ), 82, 'SNP count' );

    chdir $cwd;    # Won't keep tempdir
}

done_testing();
