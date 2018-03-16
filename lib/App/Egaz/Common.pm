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

1;

