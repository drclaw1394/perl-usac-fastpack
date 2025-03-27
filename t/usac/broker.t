use v5.36;

use Test::More;
use uSAC::IO;
use uSAC::FastPack::Broker;

use Data::Dumper;

my $node=uSAC::FastPack::Broker::Default;#->new;

ok defined $node;

$node->listen("adf", "test", sub {
  say STDERR "GOT MESSAGE:", Dumper @_;
  done_testing;
},
undef);

$node->listen(undef, "test222", sub {
  say STDERR "GOT MESSAGE:", Dumper @_;
},
undef);

$node->broadcast("adddddf", "test", "message content");
