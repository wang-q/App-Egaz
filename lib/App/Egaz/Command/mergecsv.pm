package App::Egaz::Command::mergecsv;
use strict;
use warnings;
use autodie;

use App::Egaz -command;
use App::Egaz::Common;

use constant abstract => 'merge csv files based on @fields';

sub opt_spec {
    return (
        [ "outfile|o=s", "Output filename. [stdout] for screen",    { default => "stdout" }, ],
        [ 'fields|f=i@', 'fields as identifies, 0 as first column', { default => [0] }, ],
        [ 'concat|c', ' do concat other than merge. Keep first ID fields', ],
        { show_defaults => 1, }
    );
}

sub usage_desc {
    return "fasops check [options] <infile> [more files]";
}

sub description {
    my $desc;
    $desc .= ucfirst(abstract) . ".\n";
    $desc .= "\tAccept one or more csv files.\n";
    $desc .= "\tinfile == stdin means reading from STDIN\n";
    $desc .= "\n";
    $desc .= "\tcat 1.csv 2.csv | egaz mergecsv -f 0 -f 1\n";
    $desc .= "\tegaz mergecsv -f 0 -f 1 1.csv 2.csv\n";
    $desc .= "\n";
    return $desc;
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    if ( @{$args} < 1 ) {
        my $message = "This command need one or more input files.\n\tIt found";
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

    # make array splicing happier
    $opt->{fields} = [ sort @{ $opt->{fields} } ];
}

1;
