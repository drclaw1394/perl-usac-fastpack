use uSAC::HTTP;
use uSAC::IO;

use Data::Dumper;

use uSAC::HTTP::Middleware::Static;
use uSAC::HTTP::Middleware::Bridge::WS;
use uSAC::FastPack::Channel;

my $parent=$uSAC::HTTP::Site;

#my $broker=uSAC::FastPack::Broker->new();

my $broker=$parent->build_broker;
my $clients=[];

uSAC::FastPack::Channel->accept("remote_end_point", $broker, sub {
    asay $STDERR, "ACCEPTED CONNECTION";
    my $client=$_[0];
    push @$clients, $client;
    $client->on_data=sub{
      asay $STDERR, "DATA FROM BROWSER", $_[0];
    };
    $client->on_control=sub{
      asay $STDERR, "CONTROL FROM BROWSER", $_[0];
    };
    $client->send_control("YServer sent control data");
    $client->send_data("YServer sent normal data");

});

$parent->add_route(
  "ws",
  uhm_bridge_ws(), #broker=>$broker),
  sub {
    my $broker = $_[PAYLOAD][0]; 
    my $bridge = $_[PAYLOAD][1]; 
    $broker->broadcast(undef, "bridge_ws", $bridge);

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

$parent->add_route("", uhm_static_root roots=>["site"]);

