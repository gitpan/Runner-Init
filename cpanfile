requires 'Carp';
requires 'Cwd';
requires 'Data::Dumper';
requires 'DateTime';
requires 'DateTime::Format::Duration';
requires 'File::Path';
requires 'File::Temp';
requires 'IO::File';
requires 'IO::Select';
requires 'IPC::Open3';
requires 'Log::Log4perl';
requires 'Moose';
requires 'Moose::Util::TypeConstraints';
requires 'MooseX::Getopt';
requires 'MooseX::SimpleConfig';
requires 'Symbol';
requires 'Template';
requires 'perl', '5.006';

on build => sub {
    requires 'Test::More';
    requires 'Test::Pod';
};
