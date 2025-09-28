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
#use uSAC::FastPack;
use Data::FastPack;
use Data::FastPack::Meta;
use UUID qw<uuid4>;
use uSAC::IO;
use v5.36;
use uSAC::Log;
use Log::OK;
use constant::more DEBUG=>0;

no warnings "experimental";
#use Data::Dumper;
sub Dumper{};

use Object::Pad;

class uSAC::FastPack::Broker::Bridge;
no warnings "experimental";

field $_tx_namespace;
field $_rx_namespace;


# Local to this host running this code
field $_source_id :reader;
field $_broker :reader :param=undef;

# Call this with message objecst to forward across the bridge the peer
field $_forward_message_sub;# :reader;

# The sub to call with a buffer of serialized data,
field $_buffer_out_sub :mutator;
#field $_buffer_out_wrapper;

# The sub which is called with new data to parse
field $_on_read_handler :mutator;


field $_pass_through :param = [];

# List of matchers/type pairs to forward  by default
field $_forward      :param = undef;

BUILD {
  #say "BUILD IN BASE";
  # create a new source_id, messages coming in on this broker are not sent back out!

  $_source_id= uuid4;#rand 10000;


  $_tx_namespace=create_namespace;
  $_rx_namespace=create_namespace;

  # main processing of messages 
  my $dispatch=$_broker->get_dispatcher;

  # Link the encoder middler to the writer for messages destined for remote end of the bridge


  # Link the output of reader to decoder middleware
  #

  #asay $STDERR, " ABOUT TO SET ON READE FOR READER";
  $_on_read_handler=linker 
  sub { my $next=shift; sub { DEBUG and asay $STDERR, "$$ ON READ......". length $_[0][0];DEBUG and asay $STDERR, "$$ Dump".$_[0][0]; ; &$next}}

  #=> 
  => sub {
    my ($next, $index, %options)=@_;
    sub{
      my $outputs=[];
      my $cb=$_[1];

      DEBUG and asay $STDERR,"$$ Decoding messages in comming bridge packet length". length $_[0][0];
      Data::FastPack::decode_fastpack $_[0][0], $outputs, undef, $_rx_namespace;
      #asay $STDERR, "BUffer is ". $_[0];

      DEBUG and asay $STDERR,"$$ Decoding messages in comming bridge packet length after". length $_[0][0];
      for(@{$outputs}){
        DEBUG and asay $STDERR, "$$ OUTPUT ". Dumper $_;
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
      #DEBUG and Log::OK::TRACE and asay $STDERR, "DECODE FASTPACK====";

      $next->([$_source_id, $outputs], $cb);

    }
  }


  #=> sub { my $next=shift; sub { asay $STDERR, Dumper @_; &$next}}
  => $dispatch;


  # We want meta messages to be forwared
  DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_source_id: Bridge id about to listen is registering meta";
  #$_broker->listen($_source_id, '0', $_forward_message_sub, "exact");

  if($_forward){
    for my ($m, $t)($_forward->@*){
      $_broker->listen(undef, $m, $self, $t);
    }
  }
  else {
    # Forward everything?
  }

}

#  Must have the output_buffer_sub set before calling this
method forward_message_sub {
  die "Now output_buffer_set. Cannot make forward_message_sub" unless ref $_buffer_out_sub eq "CODE";
  #$_buffer_out_wrapper= sub {goto $_buffer_out_sub};
  $_forward_message_sub //= linker 
  sub {
    my ($next, $index, %options)=@_;
    sub {
      #my $source=$_[0];
      my $source=shift @{$_[0]};
      my $inputs=$_[0][0];

      my $cb=$_[1];
      my $buffer="";
      #DEBUG and 
      #asay $STDERR, "$$ OUT GOING MESSAGES ARE ". Dumper $inputs;
      my @ins;
      for my ($msg, $cap)(@$inputs){
        $msg->[FP_MSG_PAYLOAD] =encode_meta_payload $msg->[FP_MSG_PAYLOAD] if $msg->[FP_MSG_ID] eq '0';
        #asay $STDERR, "Payload out is $msg->[FP_MSG_PAYLOAD]";
        push @ins, $msg;
      }
      Data::FastPack::encode_fastpack $buffer, \@ins, undef, $_tx_namespace;

      DEBUG and asay $STDERR, "$$ BUFFER  length is  ". length $buffer;
      $next->([$buffer], $cb); 

    }


  }
  => sub { 
    my $next=shift;
    use Scalar::Util qw<weaken>;
    weaken($next);
    sub {
      DEBUG and Log::OK::TRACE and asay $STDERR, "$$ FORWARDING MESSAGE==== length ".length $_[0][0];
      &$next
    }
  }
  #=>$_writer->writer;
  =>$_buffer_out_sub;
  #=>$_buffer_out_wrapper;

}


method close {
  #asay $STDERR, "CLOSE BRIDGE CALLED";
  # here we attempt to remove the matching entires from the broker,
  # They may never exisisted, but we attempt to remove anyway
  # The force flag means the broker will only compare the sub, not the source, or matcher
    my $dispatch=$_broker->get_dispatcher;
    my $obj={ignore=>{source=> $_source_id, sub=>$_forward_message_sub, force=>"matcher source"}};
    $dispatch->([$_source_id, [[time, 0, $obj]]]);
}




1;
