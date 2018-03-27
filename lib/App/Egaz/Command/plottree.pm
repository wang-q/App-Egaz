package App::Egaz::Command::plottree;
use strict;
use warnings;
use autodie;

use App::Egaz -command;
use App::Egaz::Common;

use constant abstract => 'use the ape package to draw newick trees';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename", ],
        [ "verbose|v",   "verbose mode", ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "egaz plottree [options] <infile>";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= <<'MARKDOWN';

* <infile> should be a newick file (*.nwk)
* --outfile can't be stdout
* Two R packages are needed, `getopt` and `ape`
* .travis.yml contains the installation guide

MARKDOWN

    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} != 1 ) {
        my $message = "This command need one input file.\n\tIt found";
        $message .= sprintf " [%s]", $_ for @{$args};
        $message .= ".\n";
        $self->usage_error($message);
    }
    for ( @{$args} ) {
        if ( !Path::Tiny::path($_)->is_file ) {
            $self->usage_error("The input file [$_] doesn't exist.");
        }
    }

}

sub execute {
    my ( $self, $opt, $args ) = @_;

    my $r_file = File::ShareDir::dist_file( 'App-Egaz', 'plot_tree.R' );
    my $cmd = "Rscript $r_file";
    $cmd .= " -i $args->[0]";
    $cmd .= " -o $opt->{outfile}" if $opt->{outfile};

    App::Egaz::Common::exec_cmd( $cmd, { verbose => $opt->{verbose}, } );

}

1;
