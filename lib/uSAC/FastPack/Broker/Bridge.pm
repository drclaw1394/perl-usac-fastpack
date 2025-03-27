# Abstract class representing a link between two brokers.  A client always
# connects to a local broker. The local broker, connects to a remote broker on
# a clients behalf.
#
# A client can request a connection to a remote broker. When connected, any
# listen requests at the local broker are forwarded on to any connected
# brokers, if the listen name doesnt already exist. This is repeated and
# propogated to all connected brokers. Saves on bandwith
# 
# Decodes unnamed (0 code) messages as link management.
#
package uSAC::FastPack::Broker::Bridge;
use Sub::Middler;
use uSAC::FastPack;
use Data::FastPack;
use uSAC::IO;
use v5.36;

use Object::Pad;

class uSAC::FastPack::Broker::Bridge;

field $_tx_namespace;
field $_rx_namespace;

field $_reader;
field $_writer;

field $_rfd :param;
field $_wfd :param;

# Local to this host running this code
field $_source_id;
field $_broker :param=undef;
field $_forward_message_sub :reader;

BUILD {
  # create a new source_id, messages coming in on this broker are not sent back out!

  $_source_id= rand 10000;
  $_reader=reader($_rfd);
  $_writer=writer($_wfd);

  # main processing of messages 
  my $_dispatch=$_broker->get_dispatcher;

  # Link the encoder middler to the writer for messages destined for remote end of the bridge
  
  $_forward_message_sub = linker 
    sm_fastpack_encoder(namepsace=>$_tx_namespace)
    => sub { 
      my $next=shift;
      sub {
        asay $STDERR, "FORWARDING MESSAGE==== length ".length $_[0];
        &$next
      }
    }
    =>$_writer->writer;


  # Link the output of reader to decoder middleware
  #

  $_reader->on_read=linker 
      sub { my $next=shift; sub { asay $STDERR, "ON READ......"; &$next}}
      =>sm_fastpack_decoder(namespace=>$_rx_namespace, source_id=>$_source_id, sub=>$_forward_message_sub)
      => $_dispatch;


  # We want meta messages to be forwared
  asay $STDERR, "Bridge id about to listen for meta is: $_source_id";
  $_broker->listen($_source_id, '0', $_forward_message_sub, "exact");

  $_reader->start;
  #$_reader->on_error=sub {$_reader->pause};
  #$_reader->on_eof=sub {$_reader->pause};

}

method close {
  $_reader->pause;
  $_writer->pause;

  IO::FD::close($_rfd);
  IO::FD::close($_wfd);

  # Remove any registered listening....
}


1;
