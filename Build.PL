
# This file was automatically generated by Dist::Zilla::Plugin::ModuleBuild v5.027.
use strict;
use warnings;

use Module::Build 0.28;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.28",
    "Test::More" => 0,
    "Test::Pod" => 0
  },
  "configure_requires" => {
    "Module::Build" => "0.28"
  },
  "dist_abstract" => "HPC Runner::Slurm, Runner::MCE and Runner::Threads base class ",
  "dist_author" => [
    "Jillian Rowe, C<< <jillian.e.rowe at gmail.com> >>"
  ],
  "dist_name" => "Runner-Init",
  "dist_version" => "2.27",
  "license" => "perl",
  "module_name" => "Runner::Init",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "Carp" => 0,
    "Cwd" => 0,
    "Data::Dumper" => 0,
    "DateTime" => 0,
    "DateTime::Format::Duration" => 0,
    "File::Path" => 0,
    "File::Temp" => 0,
    "IO::File" => 0,
    "IO::Select" => 0,
    "IPC::Open3" => 0,
    "Log::Log4perl" => 0,
    "Moose" => 0,
    "Moose::Util::TypeConstraints" => 0,
    "MooseX::Getopt" => 0,
    "MooseX::SimpleConfig" => 0,
    "Symbol" => 0,
    "Template" => 0,
    "perl" => "5.006"
  },
  "script_files" => [
    "script/mcerunner.pl",
    "script/parallelrunner.pl",
    "script/slurmrunner.pl",
    "script/slurmrunnerbasic.pl"
  ],
  "test_requires" => {}
);


my %fallback_build_requires = (
  "Module::Build" => "0.28",
  "Test::More" => 0,
  "Test::Pod" => 0
);


unless ( eval { Module::Build->VERSION(0.4004) } ) {
  delete $module_build_args{test_requires};
  $module_build_args{build_requires} = \%fallback_build_requires;
}

my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
