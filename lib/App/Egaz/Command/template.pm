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
        [ "outdir|o=s",   "Output directory",  { default => "." }, ],
        [ "queue=s",      "QUEUE_NAME",        { default => "mpi" }, ],
        [ "separate",     "separate each Target-Query groups", ],
        [ "tmp=s",        "user defined tempdir", ],
        [ "parallel|p=i", "number of threads", { default => 2 }, ],
        [ "verbose|v",    "verbose mode", ],
        [],
        [ "length=i", "minimal length of alignment fragments",  { default => 1000 }, ],
        [ "msa=s",    "aligning program for refine alignments", { default => "mafft" }, ],
        [ "taxon=s",  "taxons in this project", ],
        [ "aligndb",  "create aligndb script", ],
        [],
        [ "multiname=s", "naming multiply alignment", ],
        [ "outgroup=s",  "the name of outgroup", ],
        [ "tree=s",      "a predefined guiding tree for multiz", ],
        [ "rawphylo",    "create guiding tree by joining pairwise alignments", ],
        [],
        [ "noblast", "don't blast against genomes", ],
        [ "circos",  "create circos script", ],
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
* Default --multiname is the basename of --outdir. This option is for more than one aligning combinations
* without --tree and --rawphylo, the order of multiz stitch is the same as the one from command line
* --outgroup uses basename, not full path. *DON'T* set --outgroup to target
* --taxon may also contain unused taxons, for constructing chr_length.csv

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

    if ( $opt->{mode} eq "multi" and @{$args} < 2 ) {
        $self->usage_error("Multiple alignments need at least 2 directories");
    }

    if ( $opt->{tree} ) {
        if ( !Path::Tiny::path( $opt->{tree} )->is_file ) {
            $self->usage_error("The tree file [$opt->{tree}] doesn't exist.");
        }
        else {
            $opt->{tree} = Path::Tiny::path( $opt->{tree} )->absolute()->stringify();
        }
    }

    if ( $opt->{taxon} ) {
        if ( !Path::Tiny::path( $opt->{taxon} )->is_file ) {
            $self->usage_error("The taxon file [$opt->{taxon}] doesn't exist.");
        }
        else {
            $opt->{taxon} = Path::Tiny::path( $opt->{taxon} )->absolute()->stringify();
        }

    }

    $opt->{outdir} = Path::Tiny::path( $opt->{outdir} )->absolute()->stringify();

    if ( !$opt->{multiname} ) {
        $opt->{multiname} = Path::Tiny::path( $opt->{outdir} )->basename();
    }

    $opt->{parallel2} = int( $opt->{parallel} / 2 );
    $opt->{parallel2} = 2 if $opt->{parallel2} < 2;

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

    if ( $opt->{mode} eq "multi" ) {
        Path::Tiny::path( $opt->{outdir}, 'Pairwise' )->mkpath();
        Path::Tiny::path( $opt->{outdir}, 'Results' )->mkpath();
    }
    else {
        Path::Tiny::path( $opt->{outdir}, 'Pairwise' )->mkpath();
        Path::Tiny::path( $opt->{outdir}, 'Processing' )->mkpath();
        Path::Tiny::path( $opt->{outdir}, 'Results' )->mkpath();
    }

    $args = [ map { Path::Tiny::path($_)->absolute()->stringify() } @{$args} ];

    #----------------------------#
    # names and directories
    #----------------------------#
    print STDERR "Associate names and directories\n";
    my @data;
    {
        my %taxon_of;
        if ( $opt->{taxon} ) {
            for my $line ( Path::Tiny::path( $opt->{taxon} )->lines ) {
                my @fields = split /,/, $line;
                if ( $#fields >= 2 ) {
                    $taxon_of{ $fields[0] } = $fields[1];
                }
            }
        }
        @data = map {
            {   dir   => $_,
                name  => Path::Tiny::path($_)->basename(),
                taxon => exists $taxon_of{$_} ? $taxon_of{$_} : 0,
            }
        } @{$args};
    }

    # move $opt->{outgroup} to last
    if ( $opt->{mode} eq "multi" and $opt->{outgroup} ) {
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
    if ( $opt->{mode} eq "multi" and !$opt->{tree} ) {
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
    # multi *.sh files
    #----------------------------#
    $self->gen_pair_cmd( $opt, $args );
    $self->gen_rawphylo( $opt, $args );
    $self->gen_multi_cmd( $opt, $args );

    #----------------------------#
    # self *.sh files
    #----------------------------#
    $self->gen_self_cmd( $opt, $args );
    $self->gen_proc_cmd( $opt, $args );

}

sub gen_pair_cmd {
    my ( $self, $opt, $args ) = @_;

    return unless $opt->{mode} eq "multi";

    my $tt = Template->new( INCLUDE_PATH => [ File::ShareDir::dist_dir('App-Egaz') ], );
    my $template;
    my $sh_name;

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
[% t = opt.data.0.name -%]
[% q = item.name -%]
if [ -e Pairwise/[% t %]vs[% q %] ]; then
    log_info Skip Pairwise/[% t %]vs[% q %]
else
    log_info lastz Pairwise/[% t %]vs[% q %]
    egaz lastz \
        --set set01 -C 0 --parallel [% opt.parallel %] --verbose \
        [% opt.data.0.dir %] [% item.dir %] \
        -o Pairwise/[% t %]vs[% q %]

    log_info lpcnam Pairwise/[% t %]vs[% q %]
    egaz lpcnam \
        --syn --parallel [% opt.parallel %] --verbose \
        [% opt.data.0.dir %] [% item.dir %] Pairwise/[% t %]vs[% q %]
fi

[% END -%]
[% END -%]

exit;

EOF
    $tt->process(
        \$template,
        {   args => $args,
            opt  => $opt,
            sh   => $sh_name,
        },
        Path::Tiny::path( $opt->{outdir}, $sh_name )->stringify
    ) or Carp::croak Template->error;
}

sub gen_rawphylo {
    my ( $self, $opt, $args ) = @_;

    return unless $opt->{mode} eq "multi" and $opt->{rawphylo};

    my $tt = Template->new( INCLUDE_PATH => [ File::ShareDir::dist_dir('App-Egaz') ], );
    my $template;
    my $sh_name;

    $sh_name = "2_rawphylo.sh";
    print STDERR "Create $sh_name\n";
    $template = <<'EOF';
[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

if [ -e Results/[% opt.multiname %].raw.nwk ]; then
    log_info Results/[% opt.multiname %].raw.nwk exists
    exit;
fi

mkdir -p [% opt.multiname %]_raw
mkdir -p Results

#----------------------------#
# maf2fas
#----------------------------#
log_info Convert maf to fas

[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
log_debug "    [% t %]vs[% q %]"
mkdir -p [% opt.multiname %]_raw/[% t %]vs[% q %]

find Pairwise/[% t %]vs[% q %] -name "*.maf" -or -name "*.maf.gz" |
    parallel --no-run-if-empty -j 1 \
        fasops maf2fas {} -o [% opt.multiname %]_raw/[% t %]vs[% q %]/{/}.fas

fasops covers \
    [% opt.multiname %]_raw/[% t %]vs[% q %]/*.fas \
    -n [% t %] -l [% opt.length %] -t 10 \
    -o [% opt.multiname %]_raw/[% t %]vs[% q %].yml

[% END -%]
[% END -%]

[% IF opt.data.size > 2 -%]
#----------------------------#
# Intersect
#----------------------------#
log_info Intersect

runlist compare --op intersect \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
    [% opt.multiname %]_raw/[% t %]vs[% q %].yml \
[% END -%]
[% END -%]
    -o stdout |
    runlist span stdin \
        --op excise -n [% opt.length %] \
        -o [% opt.multiname %]_raw/intersect.yml
[% END -%]

#----------------------------#
# Coverage
#----------------------------#
log_info Coverage

runlist merge [% opt.multiname %]_raw/*.yml \
    -o stdout |
    runlist stat stdin \
        -s [% args.0 %]/chr.sizes \
        --all --mk \
        -o Results/pairwise.coverage.csv

[% IF opt.data.size > 2 -%]
#----------------------------#
# Slicing
#----------------------------#
log_info Slicing with intersect

[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
log_debug "    [% t %]vs[% q %]"
if [ -e [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas ]; then
    rm [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas
fi
find [% opt.multiname %]_raw/[% t %]vs[% q %]/ -name "*.fas" -or -name "*.fas.gz" |
    sort |
    parallel --no-run-if-empty --keep-order -j 1 ' \
        fasops slice {} \
            [% opt.multiname %]_raw/intersect.yml \
            -n [% t %] -l [% opt.length %] -o stdout \
            >> [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas
        '

[% END -%]
[% END -%]

[% END -%]

#----------------------------#
# Joining
#----------------------------#
log_info Joining intersects

log_debug "    fasops join"
fasops join \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
    [% opt.multiname %]_raw/[% t %]vs[% q %].slice.fas \
[% END -%]
[% END -%]
    -n [% opt.data.0.name %] \
    -o [% opt.multiname %]_raw/join.raw.fas

echo [% opt.data.0.name %] > [% opt.multiname %]_raw/names.list
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
echo [% q %] >> [% opt.multiname %]_raw/names.list
[% END -%]
[% END -%]

# Blocks not containing all queries, e.g. Mito, will be omitted
log_debug "    fasops subset"
fasops subset \
    [% opt.multiname %]_raw/join.raw.fas \
    [% opt.multiname %]_raw/names.list \
    --required \
    -o [% opt.multiname %]_raw/join.filter.fas

log_debug "    fasops refine"
fasops refine \
    --msa mafft --parallel [% opt.parallel %] \
    [% opt.multiname %]_raw/join.filter.fas \
    -o [% opt.multiname %]_raw/join.refine.fas

#----------------------------#
# RAxML
#----------------------------#
[% IF opt.data.size > 3 -%]
log_info RAxML

egaz raxml \
    --parallel [% IF opt.parallel > 8 %] 8 [% ELSIF opt.parallel > 3 %] [% opt.parallel - 1 %] [% ELSE %] 2 [% END %] \
[% IF opt.outgroup -%]
    --outgroup [% opt.outgroup %] \
[% END -%]
[% IF opt.verbose -%]
    -v \
[% END -%]
    [% opt.multiname %]_raw/join.refine.fas \
    -o Results/[% opt.multiname %].raw.nwk

egaz plottree Results/[% opt.multiname %].raw.nwk

[% ELSIF opt.data.size == 3 -%]
echo "(([% opt.data.0.name %],[% opt.data.1.name %]),[% opt.data.2.name %]);" > Results/[% opt.multiname %].raw.nwk

[% ELSE -%]
echo "([% opt.data.0.name %],[% opt.data.1.name %]);" > Results/[% opt.multiname %].raw.nwk

[% END -%]

exit;

EOF
    $tt->process(
        \$template,
        {   args => $args,
            opt  => $opt,
            sh   => $sh_name,
        },
        Path::Tiny::path( $opt->{outdir}, $sh_name )->stringify
    ) or Carp::croak Template->error;
}

sub gen_multi_cmd {
    my ( $self, $opt, $args ) = @_;

    return unless $opt->{mode} eq "multi";

    my $tt = Template->new( INCLUDE_PATH => [ File::ShareDir::dist_dir('App-Egaz') ], );
    my $template;
    my $sh_name;

    $sh_name = "3_multi_cmd.sh";
    print STDERR "Create $sh_name\n";
    $template = <<'EOF';
[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

if [ -e Results/[% opt.multiname %].nwk ]; then
    log_info Results/[% opt.multiname %].nwk exists
    exit;
fi

if [ -d [% opt.multiname %]_mz ]; then
    rm -fr [% opt.multiname %]_mz;
fi;
mkdir -p [% opt.multiname %]_mz

if [ -d [% opt.multiname %]_fasta ]; then
    rm -fr [% opt.multiname %]_fasta;
fi;
mkdir -p [% opt.multiname %]_fasta

if [ -d [% opt.multiname %]_refined ]; then
    rm -fr [% opt.multiname %]_refined;
fi;
mkdir -p [% opt.multiname %]_refined

mkdir -p Results

#----------------------------#
# mz
#----------------------------#
log_info multiz

[% IF opt.tree -%]
egaz multiz \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
    Pairwise/[% t %]vs[% q %] \
[% END -%]
[% END -%]
    --tree [% opt.tree %] \
    -o [% opt.multiname %]_mz \
    --parallel [% opt.parallel %]

[% ELSE %]
if [ -f Results/[% opt.multiname %].raw.nwk ]; then
    egaz multiz \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
        Pairwise/[% t %]vs[% q %] \
[% END -%]
[% END -%]
        --tree Results/[% opt.multiname %].raw.nwk \
        -o [% opt.multiname %]_mz \
        --parallel [% opt.parallel %]

else
    egaz multiz \
[% FOREACH item IN opt.data -%]
[% IF not loop.first -%]
[% t = opt.data.0.name -%]
[% q = item.name -%]
        Pairwise/[% t %]vs[% q %] \
[% END -%]
[% END -%]
        --tree fake_tree.nwk \
        -o [% opt.multiname %]_mz \
        --parallel [% opt.parallel %]

fi
[% END -%]

find [% opt.multiname %]_mz -type f -name "*.maf" |
    parallel --no-run-if-empty -j 2 pigz -p [% opt.parallel2 %] {}

#----------------------------#
# maf2fas
#----------------------------#
log_info Convert maf to fas
find [% opt.multiname %]_mz -name "*.maf" -or -name "*.maf.gz" |
    parallel --no-run-if-empty -j [% opt.parallel %] \
        fasops maf2fas {} -o [% opt.multiname %]_fasta/{/}.fas

#----------------------------#
# refine fasta
#----------------------------#
log_info Refine fas
find [% opt.multiname %]_fasta -name "*.fas" -or -name "*.fas.gz" |
    parallel --no-run-if-empty -j 2 '
        fasops refine \
            --msa [% opt.msa %] --parallel [% opt.parallel2 %] \
            --quick --pad 100 --fill 100 \
[% IF opt.outgroup -%]
            --outgroup \
[% END -%]
            {} \
            -o [% opt.multiname %]_refined/{/}
    '

find [% opt.multiname %]_refined -type f -name "*.fas" |
    parallel --no-run-if-empty -j 2 pigz -p [% opt.parallel2 %] {}

#----------------------------#
# RAxML
#----------------------------#
[% IF opt.data.size > 3 -%]
log_info RAxML

egaz raxml \
    --parallel [% IF opt.parallel > 8 %] 8 [% ELSIF opt.parallel > 3 %] [% opt.parallel - 1 %] [% ELSE %] 2 [% END %] \
[% IF opt.outgroup -%]
    --outgroup [% opt.outgroup %] \
[% END -%]
[% IF opt.verbose -%]
    -v \
[% END -%]
    [% opt.multiname %]_refined/*.fas.gz \
    -o Results/[% opt.multiname %].nwk

egaz plottree Results/[% opt.multiname %].nwk

[% ELSIF opt.data.size == 3 -%]
echo "(([% opt.data.0.name %],[% opt.data.1.name %]),[% opt.data.2.name %]);" > Results/[% opt.multiname %].nwk

[% ELSE -%]
echo "([% opt.data.0.name %],[% opt.data.1.name %]);" > Results/[% opt.multiname %].nwk

[% END -%]

exit;

EOF
    $tt->process(
        \$template,
        {   args => $args,
            opt  => $opt,
            sh   => $sh_name,
        },
        Path::Tiny::path( $opt->{outdir}, $sh_name )->stringify
    ) or Carp::croak Template->error;
}

sub gen_self_cmd {
    my ( $self, $opt, $args ) = @_;

    return unless $opt->{mode} eq "self";

    my $tt = Template->new( INCLUDE_PATH => [ File::ShareDir::dist_dir('App-Egaz') ], );
    my $template;
    my $sh_name;

    $sh_name = "1_self_cmd.sh";
    print STDERR "Create $sh_name\n";
    $template = <<'EOF';
[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

mkdir -p Pairwise

[% FOREACH item IN opt.data -%]
if [ -e Pairwise/[% item.name %]vsSelf ]; then
    log_info Skip Pairwise/[% item.name %]vsSelf
else
    log_info lastz Pairwise/[% item.name %]vsSelf
    egaz lastz \
        --isself --set set01 -C 0 --parallel [% opt.parallel %] --verbose \
        [% item.dir %] [% item.dir %] \
        -o Pairwise/[% item.name %]vsSelf

    log_info lpcnam Pairwise/[% item.name %]vsSelf
    egaz lpcnam \
        --parallel [% opt.parallel %] --verbose \
        [% item.dir %] [% item.dir %] Pairwise/[% item.name %]vsSelf
fi

[% END -%]

exit;

EOF
    $tt->process(
        \$template,
        {   args => $args,
            opt  => $opt,
            sh   => $sh_name,
        },
        Path::Tiny::path( $opt->{outdir}, $sh_name )->stringify
    ) or Carp::croak Template->error;
}

sub gen_proc_cmd {
    my ( $self, $opt, $args ) = @_;

    return unless $opt->{mode} eq "self";

    my $tt = Template->new( INCLUDE_PATH => [ File::ShareDir::dist_dir('App-Egaz') ], );
    my $template;
    my $sh_name;

    $sh_name = "3_proc_cmd.sh";
    print STDERR "Create $sh_name\n";
    $template = <<'EOF';
[% INCLUDE header.tt2 %]

#----------------------------#
# [% sh %]
#----------------------------#
log_warn [% sh %]

mkdir -p Processing
mkdir -p Results

#----------------------------#
# genome sequences
#----------------------------#
[% FOREACH item IN opt.data -%]
if [ -d Processing/[% item.name %] ]; then
    log_info Skip Processing/[% item.name %]
else
    log_info Recreate genome.fa for [% item.name %]
    mkdir -p Processing/[% item.name %]

    find [% item.dir %] -type f -name "*.fa" |
        sort |
        xargs cat |
        perl -nl -e "/^>/ or \$_ = uc; print" \
        > Processing/[% item.name %]/genome.fa
    faops size Processing/[% item.name %]/genome.fa > Processing/[% item.name %]/chr.sizes
fi

[% END -%]

#----------------------------#
# parallel
#----------------------------#
parallel --no-run-if-empty --linebuffer -k -j 2 '

if [ -d Results/{} ]; then
    echo >&2 "==> Skip Results/{}";
    exit;
fi

mkdir -p Results/{}
cd Processing/{}

#----------------------------#
# Get exact copies in the genome
#----------------------------#
echo >&2 "==> Get exact copies in the genome"

echo >&2 "    * axt2fas"
fasops axt2fas \
    ../../Pairwise/{}vsSelf/axtNet/*.axt.gz \
    -l [% opt.length %] -s chr.sizes -o stdout > axt.fas
fasops separate axt.fas -o . --nodash -s .sep.fasta

echo >&2 "    * Target positions"
egaz exactmatch target.sep.fasta genome.fa \
    --length 500 --discard 50 -o replace.target.tsv
fasops replace axt.fas replace.target.tsv -o axt.target.fas

echo >&2 "    * Query positions"
egaz exactmatch query.sep.fasta genome.fa \
    --length 500 --discard 50 -o replace.query.tsv
fasops replace axt.target.fas replace.query.tsv -o axt.correct.fas

#----------------------------#
# Coverage stats
#----------------------------#
echo >&2 "==> Coverage stats"
fasops covers axt.correct.fas -o axt.correct.yml
runlist split axt.correct.yml -s .temp.yml
runlist compare --op union target.temp.yml query.temp.yml -o axt.union.yml
runlist stat --size chr.sizes axt.union.yml -o union.csv

# links by lastz-chain
fasops links axt.correct.fas -o stdout |
    perl -nl -e "s/(target|query)\.//g; print;" \
    > links.lastz.tsv

# remove species names
# remove duplicated sequences
# remove sequences with more than 250 Ns
fasops separate axt.correct.fas --nodash --rc -o stdout |
    perl -nl -e "/^>/ and s/^>(target|query)\./\>/; print;" |
    faops filter -u stdin stdout |
    faops filter -n 250 stdin stdout \
    > axt.gl.fasta

[% IF opt.noblast -%]
#----------------------------#
# Lastz paralogs
#----------------------------#
cat axt.gl.fasta > axt.all.fasta
[% ELSE -%]
#----------------------------#
# Get more paralogs
#----------------------------#
echo >&2 "==> Get more paralogs"
egaz blastn axt.gl.fasta genome.fa -o axt.bg.blast --parallel [% opt.parallel2 %]
egaz blastmatch axt.bg.blast -c 0.95 --perchr -o axt.bg.region --parallel [% opt.parallel2 %]
faops region -s genome.fa axt.bg.region axt.bg.fasta

cat axt.gl.fasta axt.bg.fasta |
    faops filter -u stdin stdout |
    faops filter -n 250 stdin stdout \
    > axt.all.fasta
[% END -%]

#----------------------------#
# Link paralogs
#----------------------------#
echo >&2 "==> Link paralogs"
egaz blastn axt.all.fasta axt.all.fasta -o axt.all.blast --parallel [% opt.parallel2 %]
egaz blastlink axt.all.blast -c 0.95 -o links.blast.tsv --parallel [% opt.parallel2 %]

#----------------------------#
# Merge paralogs
#----------------------------#
echo >&2 "==> Merge paralogs"

echo >&2 "    * Sort links"
rangeops sort -o links.sort.tsv \
[% IF opt.noblast -%]
   links.lastz.tsv
[% ELSE -%]
    links.lastz.tsv links.blast.tsv
[% END -%]

echo >&2 "    * Clean links"
[% IF jrange -%]
jrange clean   links.sort.tsv       -o links.sort.clean.tsv
jrange merge   links.sort.clean.tsv -o links.merge.tsv       -c 0.95
jrange clean   links.sort.clean.tsv -o links.clean.tsv       -r links.merge.tsv --bundle 500
[% ELSE -%]
rangeops clean links.sort.tsv       -o links.sort.clean.tsv
rangeops merge links.sort.clean.tsv -o links.merge.tsv       -c 0.95 --parallel [% opt.parallel2 %]
rangeops clean links.sort.clean.tsv -o links.clean.tsv       -r links.merge.tsv --bundle 500
[% END -%]

echo >&2 "    * Connect links"
rangeops connect links.clean.tsv    -o links.connect.tsv     -r 0.9
rangeops filter  links.connect.tsv  -o links.filter.tsv      -r 0.8

echo >&2 "    * recreate links"
rangeops create links.filter.tsv    -o multi.temp.fas       -g genome.fa
fasops   refine multi.temp.fas      -o multi.refine.fas     --msa mafft -p [% opt.parallel2 %] --chop 10
fasops   links  multi.refine.fas    -o stdout |
    rangeops sort stdin -o stdout |
    rangeops filter stdin -n 2-50 -o links.refine.tsv

echo >&2 "    * pairwise links"
fasops   links  multi.refine.fas    -o stdout     --best |
    rangeops sort stdin -o links.best.tsv
rangeops create links.best.tsv      -o pair.temp.fas    -g genome.fa --name {}
fasops   refine pair.temp.fas       -o pair.refine.fas  --msa mafft -p [% opt.parallel2 %]

cat links.refine.tsv |
    perl -nla -F"\t" -e "print for @F" |
    runlist cover stdin -o cover.yml

echo >&2 "==> Stats of links"
echo "key,count" > links.count.csv
for n in 2 3 4 5-50; do
    rangeops filter links.refine.tsv -n ${n} -o stdout \
        > links.copy${n}.tsv

    cat links.copy${n}.tsv |
        perl -nla -F"\t" -e "print for @F" |
        runlist cover stdin -o copy${n}.temp.yml

    wc -l links.copy${n}.tsv |
        perl -nl -e "
            @fields = grep {/\S+/} split /\s+/;
            next unless @fields == 2;
            next unless \$fields[1] =~ /links\.([\w-]+)\.tsv/;
            printf qq{%s,%s\n}, \$1, \$fields[0];
        " \
        >> links.count.csv

    rm links.copy${n}.tsv
done

runlist merge copy2.temp.yml copy3.temp.yml copy4.temp.yml copy5-50.temp.yml -o copy.yml
runlist stat --size chr.sizes copy.yml --mk --all -o links.copy.csv

fasops mergecsv links.copy.csv links.count.csv --concat -o copy.csv

echo >&2 "==> Coverage figure"
runlist stat --size chr.sizes cover.yml
#perl cover_figure.pl --size chr.sizes -f cover.yml

#----------------------------#
# result
#----------------------------#
echo >&2 "==> Results"

cp cover.yml        ../../Results/{}/{}.cover.yml
cp copy.yml         ../../Results/{}/{}.copy.yml
mv cover.yml.csv    ../../Results/{}/{}.cover.csv
mv copy.csv         ../../Results/{}/{}.copy.csv
cp links.refine.tsv ../../Results/{}/{}.links.tsv
#mv cover.png        ../../Results/{}/{}.cover.png
mv multi.refine.fas ../../Results/{}/{}.multi.fas
mv pair.refine.fas  ../../Results/{}/{}.pair.fas

#----------------------------#
# clean
#----------------------------#
echo >&2 "==> Clean up"

find . -type f -name "*genome.fa*"   | parallel --no-run-if-empty rm
find . -type f -name "*all.fasta*"   | parallel --no-run-if-empty rm
find . -type f -name "*.sep.fasta"   | parallel --no-run-if-empty rm
find . -type f -name "axt.*"         | parallel --no-run-if-empty rm
find . -type f -name "replace.*.tsv" | parallel --no-run-if-empty rm
find . -type f -name "*.temp.yml"    | parallel --no-run-if-empty rm
find . -type f -name "*.temp.fas"    | parallel --no-run-if-empty rm

    ' ::: [% FOREACH item IN opt.data %][% item.name %] [% END %]

exit;

EOF
    $tt->process(
        \$template,
        { args     => $args,
            opt    => $opt,
            sh     => $sh_name,
            jrange => IPC::Cmd::can_run('jrange'),
        },
        Path::Tiny::path( $opt->{outdir}, $sh_name )->stringify
    ) or Carp::croak Template->error;
}

1;
