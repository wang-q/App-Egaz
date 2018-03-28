[![Build Status](https://travis-ci.org/wang-q/App-Egaz.svg?branch=master)](https://travis-ci.org/wang-q/App-Egaz) [![Coverage Status](http://codecov.io/github/wang-q/App-Egaz/coverage.svg?branch=master)](https://codecov.io/github/wang-q/App-Egaz?branch=master)
# NAME

App::Egaz - Backend of **E**asy **G**enome **A**ligner

# SYNOPSIS

    egaz <command> [-?h] [long options...]
            -? -h --help  show help

    Available commands:

        commands: list the application's commands
            help: display a command's help screen

          blastn: blastn wrapper between two fasta files
      exactmatch: partitions fasta files by size
         formats: formats of files use in this project
         lav2axt: convert .lav files to .axt files
         lav2psl: convert .lav files to .psl files
          masked: masked (or gaps) regions in fasta files
       maskfasta: soft/hard-masking sequences in a fasta file
       normalize: normalize lav files
       partition: partitions fasta files by size
        plottree: use the ape package to draw newick trees
           raxml: raxml wrapper to construct phylogenetic trees

Run `egaz help command-name` for usage information.

# DESCRIPTION

App::Egaz is ...

# INSTALLATION

    cpanm --installdeps https://github.com/wang-q/App-Egaz/archive/0.0.11.tar.gz
    cpanm -nq https://github.com/wang-q/App-Egaz/archive/0.0.11.tar.gz
    # cpanm -nq https://github.com/wang-q/App-Egaz.git

# AUTHOR

Qiang Wang <wang-q@outlook.com>

# LICENSE

This software is copyright (c) 2018 by Qiang Wang.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
