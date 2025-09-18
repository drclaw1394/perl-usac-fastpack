use uSAC::HTTP;
use uSAC::IO;

use Data::Dumper;

use uSAC::HTTP::Middleware::Websocket;
use uSAC::HTTP::Middleware::Bridge::WS;

my $parent=$uSAC::HTTP::Site;

my $broker=uSAC::FastPack::Broker->new();

##################################################################################################################################
# $parent->add_route(                                                                                                            #
#   "ws",                                                                                                                        #
#   uhm_websocket,                                                                                                               #
#   [sub {                                                                                                                       #
#       my ($next)= $_[0];                                                                                                       #
#       sub {                                                                                                                    #
#         my $bridge=uSAC::FastPack::Broker::Bridge->new(broker=>$broker);                                                       #
#         my $ws=$_[PAYLOAD];                                                                                                    #
#         $ws->on_open=sub {                                                                                                     #
#           # create a new bridge                                                                                                #
#           $bridge->buffer_out_sub=sub { asay $STDERR, "--CALLIND BUFFER OUT on ws $ws"; $ws->send_binary_message($_[0][0]); }; #
#           #$bridge->forward_message_sub; # NOTE: Even through the sub not called, it forces a linking                          #
#                                                                                                                                #
#                                                                                                                                #
#           ## Forward messages form the local broker across the bridge, unless the message originated from the bridge           #
#           #                                                                                                                    #
#           $broker->listen(undef, "test",    $bridge);                                                                          #
#           $broker->listen(undef, "return",  $bridge);                                                                          #
#                                                                                                                                #
#           ###                                                                                                                  #
#                                                                                                                                #
#                                                                                                                                #
#           $broker->listen("$ws",  "test", sub {                                                                                #
#               asay $STDERR, "from broker on ws $ws! ". Dumper @_;                                                              #
#               #$bridge->forward_message_sub->([undef,[[time, "return", pack "D", 1234]]]);                                     #
#               $broker->broadcast(undef, "return", pack "D", 1234);                                                             #
#             });                                                                                                                #
#                                                                                                                                #
#         };                                                                                                                     #
#                                                                                                                                #
#         $ws->on_message=sub {                                                                                                  #
#           asay $STDERR, Dumper $_[1];                                                                                          #
#           $bridge->on_read_handler->([$_[1]]);                                                                                 #
#         };                                                                                                                     #
#                                                                                                                                #
#         $ws->on_close=sub {                                                                                                    #
#           asay $STDERR, "WEBSOCKET CLOSED";                                                                                    #
#           $ws->destroy;                                                                                                        #
#           $bridge->close;                                                                                                      #
#           $broker->ignore("$ws",undef, undef,undef,"sub matcher"); #Remove all entires with client id                          #
#           $ws=undef;                                                                                                           #
#         };                                                                                                                     #
#                                                                                                                                #
#       }                                                                                                                        #
#     }                                                                                                                          #
#   ]                                                                                                                            #
# );                                                                                                                             #
##################################################################################################################################

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
