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
use Data::FastPack::Meta;
use uSAC::IO;
use v5.36;
use Log::OK;
use constant::more DEBUG=>0;


use Object::Pad;

class uSAC::FastPack::Broker::Bridge;

field $_tx_namespace;
field $_rx_namespace;

field $_reader;
field $_writer;

field $_rfd :param;
field $_wfd :param;

# Local to this host running this code
field $_source_id :reader;
field $_broker :param=undef;
field $_forward_message_sub :reader;

field $_on_error :mutator;


BUILD {
  # create a new source_id, messages coming in on this broker are not sent back out!

  $_source_id= rand 10000;
  $_reader=reader($_rfd);
  $_writer=writer($_wfd);


  $_tx_namespace=create_namespace;
  $_rx_namespace=create_namespace;

  # main processing of messages 
  my $dispatch=$_broker->get_dispatcher;

  # Link the encoder middler to the writer for messages destined for remote end of the bridge

  $_forward_message_sub = linker 
  sub {
    my ($next, $index, %options)=@_;
    sub {
      #my $source=$_[0];
      my $source=shift @{$_[0]};
      my $inputs=$_[0][0];

      my $cb=$_[1];
      my $buffer="";

      for(@$inputs){
        $_->[FP_MSG_PAYLOAD] =encode_meta_payload $_->[FP_MSG_PAYLOAD] if $_->[FP_MSG_ID] eq '0';
      }

      Data::FastPack::encode_fastpack $buffer, $inputs, undef, $_tx_namespace;
      #say STDERR "BUFFER  lenght is  ". length $buffer;
      $next->([$buffer], $cb); 

    }


  }
  => sub { 
    my $next=shift;
    sub {
      DEBUG and Log::OK::TRACE and asay $STDERR, "FORWARDING MESSAGE==== length ".length $_[0];
      &$next
    }
  }
  =>$_writer->writer;


  # Link the output of reader to decoder middleware
  #

  use Data::Dumper;
  $_reader->on_read=linker 
  sub { my $next=shift; sub { asay $STDERR, "ON READ......"; &$next}}

  => sub {
    my ($next, $index, %options)=@_;
    sub{
      my $outputs=[];
      my $cb=$_[1];

      Data::FastPack::decode_fastpack $_[0][0], $outputs, undef, $_rx_namespace;

      for(@{$outputs}){
        if($_->[FP_MSG_ID] eq '0' ){
          $_->[FP_MSG_PAYLOAD] =decode_meta_payload $_->[FP_MSG_PAYLOAD];
          for($_->[FP_MSG_PAYLOAD]{listen}){
            $_->{sub}=$_forward_message_sub;
          }
          for($_->[FP_MSG_PAYLOAD]{ignore}){
            $_->{sub}=$_forward_message_sub;
          }
        }
      }
      DEBUG and Log::OK::TRACE and asay $STDERR, "DECODE FASTPACK====";

      $next->([$_source_id, $outputs], $cb);


    }
  }


  => sub { my $next=shift; sub { asay $STDERR, Dumper @_; &$next}}
  => $dispatch;


  # We want meta messages to be forwared
  DEBUG and Log::OK::TRACE and asay $STDERR, "$_source_id: Bridge id about to listen is registering meta";
  $_broker->listen($_source_id, '0', $_forward_message_sub, "exact");

  $_writer->on_error=$_reader->on_error=
  $_reader->on_eof=sub {
    DEBUG and Log::OK::TRACE and asay $STDERR, "CLOSING THE CONNECTION";
    $_reader->pause;
    my $obj={ignore=>{sub=>$_forward_message_sub, bridge_close=>1}};
    $dispatch->([$_source_id, [[time, 0, $obj]]]);
    &$_on_error if $_on_error;
  };

  $_reader->start;

}

method close {
  DEBUG and Log::OK::TRACE and asay $STDERR, "--CONNECTION CLOSED";
  if($_reader){
    $_reader->pause;
    $_reader=undef;
    IO::FD::close($_rfd);
  }
  if($_writer){
    $_writer->pause;
    $_writer=undef;
    IO::FD::close($_wfd);
  }
}


1;
