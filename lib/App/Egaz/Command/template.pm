package App::Egaz::Command::template;
use strict;
use warnings;
use autodie;

use App::Egaz -command;
use App::Egaz::Common;

sub abstract {
    return 'create executing bash files';
}

sub opt_spec {
    return (
        [   "mode" => hidden => {
                default => "multi",
                one_of  => [
                    [ "multi" => "multiple genome alignments, orthologs" ],
                    [ "self"  => "self genome alignments, paralogs" ],
                ],
            }
        ],
        [],
        [ "basename=s", "the basename of this genome, default is the working directory", ],
        [ "length=i",     "minimal length of alignment fragments",  { default => 1000 }, ],
        [ "msa=s",        "aligning program for refine alignments", { default => "mafft" }, ],
        [ "queue=s",      "QUEUE_NAME",                             { default => "mpi" }, ],
        [ "separate",     "separate each Target-Query groups", ],
        [ "tmp=s",        "user defined tempdir", ],
        [ "parallel|p=i", "number of threads",                      { default => 2 }, ],
        [ "verbose|v",    "verbose mode", ],
        [],
        [ "multiname=s", "naming multiply alignment", ],
        [ "outgroup=s",  "the name of outgroup", ],
        [ "tree=s",      "a predefined guiding tree for multiz", ],
        [ "rawphylo",    "create guiding tree by joining pairwise alignments", ],
        [ "aligndb",     "create aligndb script", ],
        [],
        [ "circos", "create circos script", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return
        "egaz template [options] <working directory> <path/target> [path/query] [more path/queries]";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= <<'MARKDOWN';

* Default --multiname is --basename. This option is for more than one aligning combinations.
* without --tree and --rawphylo, the order of multiz stitch is the same as the one from command line

MARKDOWN

    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} < 2 ) {
        my $message = "This command need two or more directories.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_dir ) {
            $self->usage_error("The input directory [$_] doesn't exist.");
        }
    }

    if ( $opt->{multi} and @{$args} < 3 ) {
        $self->usage_error("Multiple alignments need at least 1 query.");
    }

    $args->[0] = Path::Tiny::path( $args->[0] )->absolute;

    if ( !$opt->{basename} ) {
        $opt->{basename} = Path::Tiny::path( $args->[0] )->basename();
    }

}

sub execute {
    my ( $self, $opt, $args ) = @_;

    print STDERR "Create templates for [$opt->{mode}] genome alignments\n" if $opt->{verbose};

    # fastqc
    $self->gen_fastqc( $opt, $args );

}

sub gen_fastqc {
    my ( $self, $opt, $args ) = @_;

    my $tt = Template->new( INCLUDE_PATH => [ File::ShareDir::dist_dir('App-Egaz') ], );
    my $template;
    my $sh_name;

    return unless $opt->{fastqc};

    $sh_name = "2_fastqc.sh";
    print "Create $sh_name\n";
    $template = <<'EOF';
[% INCLUDE header.tt2 %]
log_warn [% sh %]

mkdir -p 2_illumina/fastqc
cd 2_illumina/fastqc

for PREFIX in R S T; do
    if [ ! -e ../${PREFIX}1.fq.gz ]; then
        continue;
    fi

    if [ ! -e ${PREFIX}1_fastqc.html ]; then
        fastqc -t [% opt.parallel %] \
            ../${PREFIX}1.fq.gz [% IF not opt.se %]../${PREFIX}2.fq.gz[% END %] \
            -o .
    fi
done

exit;

EOF
    $tt->process(
        \$template,
        {   args => $args,
            opt  => $opt,
            sh   => $sh_name,
        },
        Path::Tiny::path( $args->[0], $sh_name )->stringify
    ) or die Template->error;
}

1;
