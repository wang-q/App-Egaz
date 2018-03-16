requires 'App::Cmd',       '0.330';
requires 'File::ShareDir', '1.102';
requires 'List::Util';
requires 'IO::Zlib';
requires 'IPC::Cmd';
requires 'Path::Tiny', '0.076';
requires 'Template',   '2.26';
requires 'YAML::Syck', '1.29';
requires 'perl',       '5.010001';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
