package App::Egaz::Command::fas2vcf;
use strict;
use warnings;
use autodie;

use App::Egaz -command;
use App::Egaz::Common;

sub abstract {
    return 'list variations in blocked fasta file';
}

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen", { default => "stdout" }, ],
        [ "verbose|v",   "verbose mode", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "egaz fas2vcf [options] <infile> <chr.sizes>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= <<MARKDOWN;

* infile == stdin means reading from STDIN
* Steps:
    1. split .fas to a temp dir by `fasops split`
    2. convert each fasta files to .vcf by `snp-sites`
    3. concat every .vcf files by `vcf-concat`

MARKDOWN

    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 2 ) {
        my $message = "This command need two input files.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        next if lc $_ eq "stdin";
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $tempdir = Path::Tiny->tempdir( TEMPLATE => "fas2vcf_XXXXXXXX", );
    my $length_of = App::RL::Common::read_sizes( $args->[1] );

    {    # fasops split
        my $cmd = "fasops split $args->[0] --simple -o $tempdir";
        App::Egaz::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
    }

    {    # snp-sites
        my @files = $tempdir->children(qr/\.fas$/);

        for my Path::Tiny $f (@files) {
            my ( $name, $chr_name, $chr_strand, $chr_pos ) = split /\./, $f->basename(".fas");
            my ( $chr_start, $chr_end ) = split /\-/, $chr_pos;
            my $chr_length = $length_of->{$chr_name};

            my $cmd = "snp-sites -v $f";
            my @lines = split /\n/, `$cmd`;

            for my $l (@lines) {
                if ( $l =~ /^\#\#contig\=\<ID\=/ ) {
                    $l = "##contig=<ID=$chr_name,length=$chr_length>";
                }

                # jvarkit/biostar94573.jar uses chrUn; snp-sites uses 1
                if ( $l =~ /^chrUn\t/ or $l =~ /^1\t/ ) {
                    my @fields = split /\t/, $l;
                    $fields[0] = $chr_name;

                    # vcf position is 1-based
                    $fields[1] = $chr_start + $fields[1] - 1;
                    $l = join "\t", @fields;
                }
            }

            Path::Tiny::path( $f . ".vcf" )->spew( map { $_ . "\n" } @lines );
            print STDERR $f . ".vcf" . "\n" if $opt->{verbose};
        }
    }

    {    # vcf-concat
        my $temp_list = Path::Tiny->tempfile( TEMPLATE => "fas2vcf_XXXXXXXX", );
        for my Path::Tiny $f ( $tempdir->children(qr/\.vcf$/) ) {
            $temp_list->append( $f . "\n" );
        }

        my $cmd = "vcf-concat -f $temp_list";
        if ( lc $opt->{outfile} ne "stdout" ) {
            $cmd .= " > $opt->{outfile}";
        }
        App::Egaz::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );
    }

    return;
}

1;
