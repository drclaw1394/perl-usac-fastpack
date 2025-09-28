use uSAC::HTTP;
use uSAC::IO;

use Data::Dumper;

use uSAC::HTTP::Middleware::Bridge::WS;

my $parent=$uSAC::HTTP::Site;

my $broker=uSAC::FastPack::Broker->new();


$parent->add_route(
  "ws",
  uhm_bridge_ws(broker=>$broker),
  sub {
    my $broker = $_[PAYLOAD][0]; 
    my $bridge = $_[PAYLOAD][1]; 

    asay $STDERR, "CREATED BRIDGE TO CLIENT VIA WEBSOCKET broker: $broker  with bridge $bridge";

    # Forward local generated messages that match this to the client
    $broker->listen(undef, "test",    $bridge);
    $broker->listen(undef, "return",  $bridge);

    $broker->listen(undef,  "test", sub {
        asay $STDERR, "from broker on ws $bridge! ". Dumper @_;
        #$bridge->forward_message_sub->([undef,[[time, "return", pack "D", 1234]]]);
        $broker->broadcast(undef, "return", pack "D", 1234);
      }
    );                                                                                                               #
    undef;
  }
);
