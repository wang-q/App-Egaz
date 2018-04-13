package App::Egaz::Command::prepseq;
use strict;
use warnings;
use autodie;

use App::Egaz -command;
use App::Egaz::Common;

sub abstract {
    return 'preparing steps for lastz';
}

sub opt_spec {
    return (
        [ "outdir|o=s", "Output directory", ],
        [ "about=i",    "split sequences to chunks about approximate size", ],
        [ "verbose|v",  "verbose mode", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "egaz prepseq [options] <path/seqfile>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= <<'MARKDOWN';

* If <path/seqfile> is a file
    * call `faops filter -N -s to convert IUPAC codes to 'N' and simplify sequence names
    * call `faops split-name` to separate each sequences into `--outdir`
    * with --about, call `faops split-about` to split sequences to chunks about specified size
* If <path/> is a directory
    * --outdir will be omitted and set to <path/>
    * only files with suffix of '.fa' will be processed
* Create chr.sizes via `faops size`
* Create chr.2bit via `faToTwoBit`
* `faops` and `faToTwoBit` should be in $PATH

MARKDOWN

    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 1 ) {
        my $message = "This command need one input file/directory.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        if ( !( Path::Tiny::path($_)->is_file or Path::Tiny::path($_)->is_dir ) ) {
            $self->usage_error("The input file/directory [$_] doesn't exist.");
        }
    }

    # set default --outdir
    if ( Path::Tiny::path( $args->[0] )->is_file ) {
        $opt->{outdir} = "." if ( !$opt->{outdir} );
        printf STDERR "--outdir set to [%s]\n", $opt->{outdir} if $opt->{verbose};
    }
    if ( Path::Tiny::path( $args->[0] )->is_dir ) {
        $opt->{outdir} = $args->[0];
        print STDERR "--outdir set to [$args->[0]]\n" if $opt->{verbose};
    }
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    #@type Path::Tiny
    my $outdir = Path::Tiny::path( $opt->{outdir} );
    $outdir->mkpath();

    #----------------------------#
    # split-name
    #----------------------------#
    if ( Path::Tiny::path( $args->[0] )->is_file ) {
        my $cmd;
        $cmd .= "faops filter -N -s $args->[0] stdout";
        $cmd .= " |";
        if ( $opt->{about} ) {
            $cmd .= " faops split-about stdin $opt->{about} $outdir";
        }
        else {
            $cmd .= " faops split-name stdin $outdir";
        }
        App::Egaz::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
    }

    #----------------------------#
    # chr.sizes
    #----------------------------#
    {
        my $cmd = "faops size $outdir/*.fa > $outdir/chr.sizes";
        App::Egaz::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
    }

    #----------------------------#
    # chr.2bit
    #----------------------------#
    {
        my $cmd = "faToTwoBit $outdir/*.fa $outdir/chr.2bit";
        App::Egaz::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
    }

    return;
}

1;
