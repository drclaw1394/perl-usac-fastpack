use 5.036003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'uSAC::FastPack',
    VERSION_FROM      => 'lib/uSAC/FastPack/Broker.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
      'Data::FastPack'=> v0.2.0,
      'Sub::Middler'  => v0.4.0,
      'Hustle::Table' => v0.7.1,
    }, 
    ABSTRACT_FROM     => 'lib/uSAC/FastPack/Broker.pod', # retrieve abstract from module
    AUTHOR            => 'Ruben Westerberg <drclaw@mac.com>',
    LICENSE           => 'mit',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);
