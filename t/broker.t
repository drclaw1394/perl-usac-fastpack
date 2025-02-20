use v5.36;

use Test::More;
use uSAC::FastPack::Broker;

use Data::Dumper;

my $node=uSAC::FastPack::Broker::Default;#->new;

$node->listen("adf", "test", sub {
  say STDERR "GOT MESSAGE:", Dumper @_;
},
undef);

$node->listen(undef, "test222", sub {
  say STDERR "GOT MESSAGE:", Dumper @_;
},
undef);

#$node->broadcast(undef,"test", "message content");
$node->broadcast("adf", "test", "message content");
#$node->broadcast(undef,"test", "message content");
#$node->broadcast(undef,"tiest", "message content");
#$node->broadcast(undef,"test2", "message 2content");
ok defined $node;
done_testing;
