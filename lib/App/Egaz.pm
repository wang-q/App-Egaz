package App::Egaz;

our $VERSION = "0.0.13";

use strict;
use warnings;
use App::Cmd::Setup -app;

=pod

=encoding utf-8

=head1 NAME

App::Egaz - Backend of B<E>asy B<G>enome B<A>ligner

=head1 SYNOPSIS

    egaz <command> [-?h] [long options...]
            -? -h --help  show help

    Available commands:

        commands: list the application's commands
            help: display a command's help screen

          blastn: blastn wrapper between two fasta files
      exactmatch: exact matched positions in genome sequences
         formats: formats of files use in this project
           lastz: lastz wrapper for two genomes or self alignments
         lav2axt: convert .lav files to .axt files
         lav2psl: convert .lav files to .psl files
          lpcnam: the pipeline of pairwise lav-psl-chain-net-axt-maf
          masked: masked (or gaps) regions in fasta files
       maskfasta: soft/hard-masking sequences in a fasta file
       normalize: normalize lav files
       partition: partitions fasta files by size
        plottree: use the ape package to draw newick trees
         prepseq: preparing steps for lastz
           raxml: raxml wrapper to construct phylogenetic trees

Run C<egaz help command-name> for usage information.

=head1 DESCRIPTION

App::Egaz is the backend of B<E>asy B<G>enome B<A>ligner.

=head1 INSTALLATION

    cpanm --installdeps https://github.com/wang-q/App-Egaz/archive/0.0.11.tar.gz
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Egaz/master/share/check_dep.sh | bash
    cpanm -nq https://github.com/wang-q/App-Egaz/archive/0.0.11.tar.gz
    # cpanm -nq https://github.com/wang-q/App-Egaz.git

=head1 AUTHOR

Qiang Wang E<lt>wang-q@outlook.comE<gt>

=head1 LICENSE

This software is copyright (c) 2018 by Qiang Wang.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

__END__
