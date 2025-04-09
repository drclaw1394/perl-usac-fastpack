
use v5.36;
use uSAC::IO;
use uSAC::FastPack::Broker;
use uSAC::FastPack::Broker::Bridge;

use Test::More;

my $node=$uSAC::Main::Default_Broker;

my $bridge=uSAC::FastPack::Broker::Bridge->new(broker=>$node, rfd=>0, wfd=>2);

ok defined $bridge;

$bridge->forward_message_sub->(
  [undef,[[time, "hello",  "there"]]], 
  sub {
    say STDERR "CALLBACK FROM ON WRITE";
    $bridge->close;
    done_testing;
   }
);




1;
