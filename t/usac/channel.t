use feature ":all";
use Test::More;

use uSAC::IO;
use Data::Dumper;
use uSAC::FastPack::Broker;


use uSAC::FastPack::Channel;

my $broker=uSAC::FastPack::Broker->new();

ok $broker isa uSAC::FastPack::Broker, "Broker OK";

my $slave=uSAC::FastPack::Channel->new(broker=>$broker, mode=>"slave");

ok $slave isa uSAC::FastPack::Channel, "Channel Slave OK";

my $master;

uSAC::FastPack::Channel->accept("my_end_point", $broker, sub {
    asay $STDERR, "ON connect in master";
    $master= $_[0];
    ok $master isa uSAC::FastPack::Channel, "Channel Master OK";

    $master->on_data=sub {
      asay $STDERR, "MASTER GOT DATA @_";
      ok $_[0] eq "MISO", "MISO data ok";
    };

    $master->on_control=sub {
      asay $STDERR, "MASTER GOT CONTROL @_";
      ok $_[0] eq "MISO", "MISO control ok";
    };

    $master->send_data("MOSI");
    $master->send_control("MOSI");

});

$slave->on_data=sub {
  asay $STDERR, "SLAVE GOT DATA @_";
  ok $_[0] eq "MOSI", "MOSI data ok";

};

$slave->on_control=sub {
  asay $STDERR, "SLAVE GOT CONTROL @_";
  ok $_[0] eq "MOSI", "MOSI control ok";

  done_testing;
};

$slave->connect("my_end_point", sub {
    asay $STDERR, "ON connect slave";
    $slave->send_data("MISO");
    $slave->send_control("MISO");
});

