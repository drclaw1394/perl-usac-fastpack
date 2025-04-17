use 5.036003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'uSAC::FastPack',
    VERSION_FROM      => 'lib/uSAC/FastPack.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
      'Data::FastPack'=> v0.2.0,
      'Sub::Midler'   => v0.4.0,
    }, 
    ABSTRACT_FROM     => 'lib/uSAC/FastPack.pm', # retrieve abstract from module
    AUTHOR            => 'Ruben Westerberg <drclaw@local>',
    LICENSE           => 'mit',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);
