use uSAC::HTTP;
use uSAC::IO;

use Data::Dumper;

use uSAC::HTTP::Middleware::Websocket;

my $parent=$uSAC::HTTP::Site;

my $broker=uSAC::FastPack::Broker->new();
$parent->add_route(
  "ws",
  uhm_websocket,
  [sub {
      my ($next)= $_[0];
      sub {
        my $bridge=uSAC::FastPack::Broker::Bridge->new(broker=>$broker);
        my $ws=$_[PAYLOAD];
        $ws->on_open=sub {
          # create a new bridge
          $bridge->buffer_out_sub=sub { asay $STDERR, "--CALLIND BUFFER OUT on ws $ws"; $ws->send_binary_message($_[0][0]); };
          $bridge->forward_message_sub; # NOTE: Even through the sub not called, it forces a linking
          
          $broker->listen("$ws","test", sub {
              asay $STDERR, "from broker on ws $ws! ". Dumper @_;
              $bridge->forward_message_sub->([undef,[[time, "return", pack "D", 1234]]]);
            });

        };

        $ws->on_message=sub {
          asay $STDERR, Dumper $_[1];
          $bridge->on_read_handler->([$_[1]]);


        };
        $ws->on_close=sub {
          asay $STDERR, "WEBSOCKET CLOSED";
          $ws->destroy;
          $bridge->close;
          $broker->ignore("$ws",undef, undef,undef,"sub matcher"); #Remove all entires with client id 
          $ws=undef;
        };

      }
    }
  ]
);
