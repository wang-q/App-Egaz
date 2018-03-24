package App::Egaz::Common;
use strict;
use warnings;
use autodie;

use 5.010001;

use Carp qw();
use File::ShareDir qw();
use IO::Zlib;
use IPC::Cmd qw();
use JSON qw();
use List::Util qw();
use Path::Tiny qw();
use Template;
use YAML::Syck qw();

use App::Fasops::Common;

sub resolve_file {
    my $original = shift;
    my @paths    = @_;

    my $file = $original;
    if ( !-e $file ) {
        $file = Path::Tiny::path($file)->basename();

        if ( !-e $file ) {
            for my $p (@paths) {
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

sub round {
    my $float = shift;

    return int( $float + $float / abs( $float * 2 || 1 ) );
}

# Return a list of 1-based overlapping ranges
sub overlap_ranges {
    my $start   = shift;
    my $end     = shift;
    my $chunk   = shift;
    my $overlap = shift;

    my @ranges;
    for ( my $i = $start - 1; $i < $end; $i += $chunk ) {
        my $j = $i + $chunk + $overlap;
        $j = $end if ( $j > $end );
        push @ranges, [ ( $i + 1 ), $j ];
    }
    return \@ranges;
}

sub run_sparsemem {
    my Path::Tiny $result = shift;
    my $query             = shift;
    my $genome            = shift;
    my $length = shift || 20;

    my $exe;
    if ( IPC::Cmd::can_run('sparsemem') ) {
        $exe = 'sparsemem';
    }
    else {
        $exe = 'mummer';
    }

    # -b    compute forward and reverse complement matches
    # -F    force 4 column output format regardless of the number of reference sequence inputs
    # -n    match only the characters a, c, g, or t
    # -k    sampled suffix positions (one by default)
    my $cmd = sprintf "%s -maxmatch -F -l %d -b -n -k 4 -threads 4 %s %s > %s",
        $exe,
        $length,
        $genome,
        $query,
        $result->stringify;
    system $cmd;
}

sub get_seq_faidx {
    my $file     = shift;
    my $location = shift;    # I:1-100

    my $cmd = sprintf "samtools faidx %s %s", $file, $location;
    open my $fh_pipe, '-|', $cmd;

    my $seq;
    while ( my $line = <$fh_pipe> ) {
        chomp $line;
        if ( $line =~ /^[\w-]+/ ) {
            $seq .= $line;
        }
    }
    close $fh_pipe;

    return $seq;
}

sub get_size {
    my $file = shift;

    tie my %length_of, "Tie::IxHash";

    if ( IPC::Cmd::can_run('faops') ) {
        my $cmd = sprintf "faops size %s", $file;
        my @lines = grep {defined} split /\n/, `$cmd`;

        for (@lines) {
            my ( $key, $value ) = split /\t/;
            $length_of{$key} = $value;
        }
    }
    else {
        my $seq_of = App::Fasops::Common::read_fasta($file);
        my @seq_names = keys %{$seq_of};

        for my $name (@seq_names) {
            $length_of{$name} = length $seq_of->{$name};
        }
    }

    return \%length_of;
}

1;

