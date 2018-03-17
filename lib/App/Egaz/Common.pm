package App::Egaz::Common;
use strict;
use warnings;
use autodie;

use 5.010001;

use Carp qw();
use File::ShareDir qw();
use IO::Zlib;
use IPC::Cmd qw();
use List::Util qw();
use Path::Tiny qw();
use Template;
use YAML::Syck qw();

use App::Fasops::Common;

sub resolve_file {
    my $original = shift;
    my @pathes   = @_;

    my $file = $original;
    if ( !-e $file ) {
        $file = Path::Tiny::path($file)->basename();

        if ( !-e $file ) {
            for my $p (@pathes) {
                $file = Path::Tiny::path($p)->child($file);
                last if -e $file;
            }
        }
    }

    if ( -e $file ) {
        return $file->stringify;
    }
    else {
        Carp::confess "Can't resole file for [$original]\n";
    }
}

1;

