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
        [ "outdir|o=s",   "Output directory",                       { default => "." }, ],
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
    return "egaz template [options] <path/seqdir> [more path/seqdir]";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= <<'MARKDOWN';

* <path/seqdir> are directories containing multiple .fa files that represent genomes
* Each .fa files in <path/target> should contain only one sequences, otherwise second or latter sequences will be omitted
* Species/strain names in result files are the basenames of <path/seqdir>
* Default --multiname is the working directory. This option is for more than one aligning combinations
* without --tree and --rawphylo, the order of multiz stitch is the same as the one from command line
* --outgroup uses basename, not full path

MARKDOWN

    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} < 1 ) {
        my $message = "This command need one or more directories.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_dir ) {
            $self->usage_error("The input directory [$_] doesn't exist.");
        }
    }

    if ( $opt->{multi} and @{$args} < 2 ) {
        $self->usage_error("Multiple alignments need at least 2 directories");
    }

    if ( $opt->{tree} ) {
        if ( !Path::Tiny::path( $opt->{tree} )->is_file ) {
            $self->usage_error("The tree file [$opt->{tree}] doesn't exist.");
        }
    }

    if ( !$opt->{multiname} ) {
        $opt->{multiname} = Path::Tiny::path( $args->[0] )->basename();
    }

}

sub execute {
    my ( $self, $opt, $args ) = @_;

    print STDERR "Create templates for [$opt->{mode}] genome alignments\n";

    #----------------------------#
    # prepare working dir
    #----------------------------#
    $opt->{outdir} = Path::Tiny::path( $opt->{outdir} )->absolute();
    $opt->{outdir}->mkpath();
    $opt->{outdir} = $opt->{outdir}->stringify();
    print STDERR "Working directory [$opt->{outdir}]\n";

    if ( $opt->{multi} ) {
        Path::Tiny::path( $opt->{outdir}, 'Pairwise' )->mkpath();
        Path::Tiny::path( $opt->{outdir}, 'Stats' )->mkpath();
    }
    else {
        Path::Tiny::path( $opt->{outdir}, 'Pairwise' )->mkpath();
        Path::Tiny::path( $opt->{outdir}, 'Processing' )->mkpath();
        Path::Tiny::path( $opt->{outdir}, 'Results' )->mkpath();
    }

    #----------------------------#
    # names and directories
    #----------------------------#
    print STDERR "Associate names and directories\n";
    my @data;
    @data = map {
        {   name => Path::Tiny::path($_)->basename(),
            dir  => Path::Tiny::path($_)->absolute()->stringify(),
        }
    } @{$args};

    # move $opt->{outgroup} to last
    if ( $opt->{outgroup} ) {
        my ($exist) = grep { $_->{name} eq $opt->{outgroup} } @data;
        if ( !defined $exist ) {
            Carp::croak "--outgroup [$opt->{outgroup}] does not exist!\n";
        }

        @data = grep { $_->{name} ne $opt->{outgroup} } @data;
        push @data, $exist;
    }
    $opt->{data} = \@data;    # store in $opt

    print STDERR YAML::Syck::Dump( $opt->{data} );

    # If there's no phylo tree, generate a fake one.
    if ( $opt->{multi} and !$opt->{tree} ) {
        print STDERR "Create fake_tree.nwk\n";
        my $fh = Path::Tiny::path( $opt->{outdir}, "fake_tree.nwk" )->openw;
        print {$fh} "(" x ( scalar(@data) - 1 ) . "$data[0]->{name}";
        for my $i ( 1 .. $#data ) {
            print {$fh} ",$data[$i]->{name})";
        }
        print {$fh} ";\n";
        close $fh;
    }

    #----------------------------#
    # *.sh files
    #----------------------------#
    $self->gen_pair_cmd( $opt, );

}

sub gen_pair_cmd {
    my ( $self, $opt, ) = @_;

    my $tt = Template->new( INCLUDE_PATH => [ File::ShareDir::dist_dir('App-Egaz') ], );
    my $template;
    my $sh_name;

    return unless $opt->{multi};

    $sh_name = "1_pair_cmd.sh";
    print STDERR "Create $sh_name\n";
    $template = <<'EOF';
[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

mkdir -p Pairwise

[% FOREACH item IN opt.data -%]
[% IF loop.first -%]
# Target [% item.name %]

[% ELSE -%]
if [ -e Pairwise/[% opt.data.0.name %]vs[% item.name %] ]; then
    log_info Skip Pairwise/[% opt.data.0.name %]vs[% item.name %]
else
    log_info lastz Pairwise/[% opt.data.0.name %]vs[% item.name %]
    egaz lastz \
        --set set01 -C 0 --parallel [% opt.parallel %] --verbose \
        [% opt.data.0.dir %] [% item.dir %] \
        -o Pairwise/[% opt.data.0.name %]vs[% item.name %]

    log_info lpcnam Pairwise/[% opt.data.0.name %]vs[% item.name %]
    egaz lpcnam \
        --parallel [% opt.parallel %] --verbose \
        [% opt.data.0.dir %] [% item.dir %] Pairwise/[% opt.data.0.name %]vs[% item.name %]
fi

[% END -%]
[% END -%]

exit;

EOF
    $tt->process(
        \$template,
        {   opt => $opt,
            sh  => $sh_name,
        },
        Path::Tiny::path( $opt->{outdir}, $sh_name )->stringify
    ) or Carp::croak Template->error;
}

1;
