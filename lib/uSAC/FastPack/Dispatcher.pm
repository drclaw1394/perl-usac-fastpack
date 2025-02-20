# Dispatcher is an attachment to a broker.
# It contains a sub which dispatches messages to the line
# the line could be a local api
package uSAC::FastPack::Dispatcher;
use v5.36;
#use constat::more qw<

use Object::Pad;

class uSAC::FastPack::Dispatcher;

field $_dispatch_sub;   #Sub which is called by  broker and is use to ID the dispatcher

field $_source_id;  # Source id/ group id for this dispatcher
field $_broker;     # Connected broker object


method make_dispatch {
  $_dispatch_sub//=sub {

  }
}

# Proxy to broker, but fill the source id
method add_listener {
  $_broker

}

method remove_listener {

}

method broadcast {

}
