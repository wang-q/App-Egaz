package App::Egaz::Command::lastz;
use strict;
use warnings;
use autodie;

use App::Egaz -command;
use App::Egaz::Common;

sub abstract {
    return 'lastz wrapper for two genomes or self alignments';
}

sub opt_spec {
    return (
        [ "outdir|o=s",   "Output directory",  { default => "." }, ],
        [ "tmp=s",        "user defined tempdir", ],
        [ "tp",           "target sequences are partitioned", ],
        [ "qp",           "query sequences are partitioned", ],
        [ "paired",       "relationships between target and query are one-to-one", ],
        [ "isself",       "self-alignment", ],
        [ "set|s=s",      "use a predefined lastz parameter set", ],
        [ "O=i",          "Scoring: gap-open penalty", ],
        [ "E=i",          "Scoring: gap-extension penalty", ],
        [ "Q=s",          "Scoring: matrix file", ],
        [ "C=i",          "Aligning: chain option", ],
        [ "T=i",          "Aligning: words option", ],
        [ "M=i",          "Aligning: mask any base in seq1 hit this many times", ],
        [ "K=i",          "Dropping hsp: threshold for MSPs for the first pass", ],
        [ "L=i",          "Dropping hsp: threshold for gapped alignments for the second pass", ],
        [ "H=i",          "Dropping hsp: threshold to be interpolated between alignments", ],
        [ "Y=i",          "Dropping hsp: X-drop parameter for gapped extension", ],
        [ "Z=i",          "Speedup: increment between successive words", ],
        [ "parallel|p=i", "number of threads", { default => 2 }, ],
        [ "verbose|v",    "verbose mode", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "egaz lastz [options] <path/target> <path/query>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= <<'MARKDOWN';

* <path/target> or <path/query> can be .fa files or directory containing multiple .fa files
* Lastz will take the first sequence in target fasta file and all sequences in query fasta file.
* For less confusions, each fasta files should contain only one sequence. `faops split-name` can be use to do this.
* Fasta file naming rules: "seqfile.fa" or "seqfile.fa[from,to]"
* Lav file naming rules: "[target]vs[query].N.lav"
* Predefined parameter sets and scoring matrix can be found in `share/`
* `lastz` should be in $PATH
* [`lastz` help](http://www.bx.psu.edu/~rsharris/lastz/README.lastz-1.04.00.html)
* [`--isself`](http://www.bx.psu.edu/~rsharris/lastz/README.lastz-1.04.00.html#ex_self)

MARKDOWN

    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 2 ) {
        my $message = "This command need two input files/directories.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        if ( !( Path::Tiny::path($_)->is_file or Path::Tiny::path($_)->is_dir ) ) {
            $self->usage_error("The input file/directory [$_] doesn't exist.");
        }
    }

    # load parameter sets
    if ( $opt->{set} ) {
        printf STDERR "* Use parameter set $opt->{set}\n";
        my $yml_file = File::ShareDir::dist_file( 'App-Egaz', 'parameters.yml' );
        my $yml = YAML::Syck::LoadFile($yml_file);

        if ( !exists $yml->{ $opt->{set} } ) {
            $self->usage_error("--set [$opt->{set}] doesn't exist.");
        }

        # Getopt::Long::Descriptive store opts in small cases
        my $para_set = $yml->{ $opt->{set} };
        for my $key ( map {lc} keys %{$para_set} ) {
            next if $key eq "comment";
            next if defined $opt->{$key};
            $opt->{$key} = $para_set->{uc $key};
        }
    }

    # scoring matrix
    if ( $opt->{q} ) {
        if ( $opt->{q} eq "default" ) {
            $opt->{q} = File::ShareDir::dist_file( 'App-Egaz', 'matrix/default' );
        }
        elsif ( $opt->{q} eq "distant" ) {
            $opt->{q} = File::ShareDir::dist_file( 'App-Egaz', 'matrix/distant' );
        }
        elsif ( $opt->{q} eq "similar" ) {
            $opt->{q} = File::ShareDir::dist_file( 'App-Egaz', 'matrix/similar' );
        }
        elsif ( $opt->{q} eq "similar2" ) {
            $opt->{q} = File::ShareDir::dist_file( 'App-Egaz', 'matrix/similar2' );
        }
        elsif ( !Path::Tiny::path( $opt->{q} )->is_file ) {
            $self->usage_error("The matrix file [$opt->{q}] doesn't exist.\n");
        }
    }

}

sub execute {
    my ( $self, $opt, $args ) = @_;

    #@type Path::Tiny
    my $outdir = Path::Tiny::path( $opt->{outdir} );
    $outdir->mkpath();

    print YAML::Syck::Dump $opt;
}

1;
