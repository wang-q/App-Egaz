requires 'App::Cmd',         '0.330';
requires 'Bio::Phylo',       'v2.0.1';
requires 'File::Find::Rule', '0.34';
requires 'File::ShareDir',   '1.102';
requires 'IO::Zlib';
requires 'IPC::Cmd';
requires 'List::Util';
requires 'List::MoreUtils',    '0.428';
requires 'MCE',                '1.835';
requires 'JSON',               '2.97001';
requires 'Path::Tiny',         '0.076';
requires 'Set::Scalar',        '1.29';
requires 'Statistics::R',      '0.34';
requires 'String::Similarity', '1.04';
requires 'Template',           '2.26';
requires 'Tie::IxHash',        '1.23';
requires 'YAML::Syck',         '1.29';
requires 'App::Fasops',        '0.5.11';
requires 'perl',               '5.018001';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
