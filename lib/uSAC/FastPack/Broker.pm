package uSAC::FastPack::Broker;

use v5.36;

use uSAC::IO;
use Object::Pad;

use Data::FastPack;
use Data::FastPack::Meta;

use Data::Dumper;
use uSAC::FastPack::Broker::Bridge;

use Hustle::Table;
use constant::more qw<READER=0 WRITER WRITER_SUB>;

use Export::These qw<usac_broadcast usac_listen>;


sub usac_broadcast;
sub usac_listen;
sub usac_ignore;

our $Default;         # Default broker
class uSAC::FastPack::Broker;

no warnings "experimental";
field $_ht;  # Main rule table for published messages
field $_ht_dispatcher;   # The built ht dispature
field $_cache;        # Cache for the ht 
field $_ns;           # Namespace common to all connection sends to brocker
                      # allows encoding only once for multiple subscriptions

field $_bridges :reader;        # list of connected bridges which subscription will be requested

field $_connections;  # Local and remote connections streams
field $_writers;

field $_dispatcher; #
field $_broadcaster_sub;
field $_listener_sub;
field $_ignorer_sub;
field $_meta_handler;
field $_connector_sub;

field $_uuid;         # UUID of this broker/node/client
field $_default_source_id;
field $_default_match_mode;

BUILD {

  # Configure table
  $_ht=Hustle::Table->new();

  $_bridges=[];

  $_uuid=rand 10000;
  $_default_source_id= rand 10000;
  
  $_dispatcher=sub {

    say STDERR "DISPATCH IN BROKER";
    my $source=shift; # The object/id from where these messages 'originated' 
                      # Could be a sub, an number, uuid
                      #
    # Filter the messages to match end points
    # NOTE: restrictions on fast pack requires a named message to not be "0" or "" (Empty string)
    # This allows a logical test only on  numeric 0, which is then detected as a system message
    # Translating it to the UUID of this node, allows for adding listeners
    #
    my @entries=$_ht_dispatcher->(map $_->[FP_MSG_ID], @{$_[0]});

    use Data::Dumper;
    say STDERR "Source: ".$source;
    say STDERR "Message ". Dumper $_[0];
    say STDERR "ENtries matching: ". Dumper @entries;

    for my $msg (@_){  
      for my ($e, $c)(@entries){
        # Call each of the subs on matching entry with this 
        # But only call if the source filter doesnt match
        # messages are not sent back to the source, 
        # psuedo grouping
        for my ($sub, $source_id) ($e->[Hustle::Table::value_]->@*){
          if(!defined($source_id) or $source ne $source_id){
            $sub->($source, $msg); # Dispatch messages to listener
            
          }
        }
      }
    }
  };

  # Create broadcaster sub
  # Takes essentially key value pairs and publishes them in a fast pack message

  $_broadcaster_sub//= sub {
    my $time=time;

    my $client_id=shift;#//$_default_source_id;

    my @msg;
    for my ($name, $val)(@_){
      push @msg, [$time, $name, $val];
    }

    # Send the messages through
    # TODO: make this asap, no syncrhonous
    $_dispatcher->($client_id, \@msg);
  };

  # Create listener sub
  #

  $_listener_sub=sub {
    my $source_id=shift;#//$_default_source_id;
    my $name=shift;
    my $sub=shift;
    my $type=shift//$_default_match_mode;
  
    die 'Cannot listen for an unamed message' unless $name;

    my $object={listen=>{source=>$source_id, matcher=>$name, type=>$type, sub=>$sub}};

    # Add message to the queue 
    $_dispatcher->($source_id, [[time, 0, $object]]);

  };


  # Handler for processing 0 named messages
  #

  $_meta_handler = sub {

    use Data::Dumper;
    say STDERR "META HANDLER", Dumper @_;
    say STDERR "BRidges".@$_bridges;

    my ($source_id, $msgs)=@_;
    
    my $obj;
    my $name;
    my $sub;
    my $type;

          for my $msg (@$msgs){
            for my ($k, $v) ($msg->[FP_MSG_PAYLOAD]->%*){
              if($k eq "listen"){

                $name=$v->{matcher};
                $sub=delete $v->{sub};
                $type=$v->{type};

                my $org_name=$name;

                # Preconvert  to ensure grouping of dispatch entries
                $name=qr{$name} if !$type;
                # Search the hustle table entries for a match against the matcher
                my $found;
                for my $e($_ht->@*){

                  if($e->[Hustle::Table::matcher_] eq $name and $e->[Hustle::Table::type_] eq $type){
                    push $e->[Hustle::Table::value_]->@*, $sub, $source_id;
                    $found=1;
                    last;
                  }
                }

                unless($found){
                  # Register an new entry with a 
                  $_ht->add([$name, [$sub, $source_id], $type]);

                  # rebuild the dispatcher
                  $_cache={}; 
                  $_ht_dispatcher=$_ht->prepare_dispatcher(cache=>$_cache);
                }

              }

              elsif($k eq "ignore"){
                # Search the hustle table entries for a match against the matcher

                $name=$v->{matcher};
                $sub=$v->{sub};
                $type=$v->{type};

                my $found;
                for my $e($_ht->@*){
                  if($e->[Hustle::Table::matcher_] eq $name and $e->[Hustle::Table::type_] eq $type){

                    # Remove sub from list
                    for my ($j,$i) (reverse 0..$e->[Hustle::Table::value_]->@*-1){
                      if($e->[Hustle::Table::value_][$i] == $sub and
                        $e->[Hustle::Table::value_][$j] eq $source_id){
                        splice $e->[Hustle::Table::value_]->@*, $i, 2;
                        $found=1;
                      }
                    }

                    last;
                  }
                }
              }

              say STDERR "FORWARD MESSAGE=========";
              # No need to forward the meta to all bridges
              for(@$_bridges){
                $_->forward_message_sub->([$msg], sub {
                    say STDERR "BRIGE WRITE COMPLTE";
                  }
                )
              }
            }
          }
  };

  # Create ingorer sub
  # 

  $_ignorer_sub=sub {
    my $source_id=shift//$_default_source_id;
    my $name=shift;
    my $sub=shift;
    my $type=shift//$_default_match_mode;
  
    die 'Cannot listen for an unamed message' unless $name;
    my $object={ignore=>{source=>$source_id, matcher=>$name, type=>$type, sub=>$sub}};

    # Add message to the queue 
    $_dispatcher->($source_id, [[time, 0, $object]]);

  };



  # Connector sub
  $_connector_sub= sub {
      # takes Socket::more specifiction for connecting
      my $c=shift;
      my $cb=shift;

      uSAC::IO::socket_stage($c, sub {
        $_[1]{data}={
          on_connect=> sub {
            say "CONNECTED TO HOST @_";
            push $_bridges->@*, uSAC::FastPack::Broker::Bridge->new(broker=>$self, rfd=>$_[0], wfd=>$_[0]);
            $cb->(1);
          },

          on_error=>sub {
            say "GOT ERROR";
            $cb->(undef);
          }

        };
        say STDERR "calling usacCONNECT";
        &uSAC::IO::connect;
      });
  };



  # Bootstrap with meta handler for 'unamed' 0 id
  #
  
  $_ht->add([0, [$_meta_handler, $_uuid], "exact"]);
  $_cache={};
  $_ht_dispatcher=$_ht->prepare_dispatcher(cache=>$_cache);

}

#  Returns the a sub which will process incomming messages from a connection
#  
#
method get_dispatcher{
      $_dispatcher;
}


# Adds a sub to matching a entry in the table or creates a new entry if need be
#  same form as hustle table entries
#  matcher/name, value, type
#
method get_listener{
  $_listener_sub;
}

method get_ignorer{
  $_ignorer_sub;
}

# Sends a message with the curent time
# arguments are k v pairs

method get_broadcaster {
  $_broadcaster_sub;
}

method broadcast {
  &$_broadcaster_sub;
}


# OO wrapper around dispatcher.
# First argument is source id/client id, remaining arguments are expected to be fastpack messages [time, id, payload]
method dispatch {

  &$_dispatcher;
}

method listen {
  &$_listener_sub;
}
method ignore {
  &$_ignorer_sub;
}

method connect {
  &$_connector_sub;
}

method server {
  my $l=shift;
  my $cb=shift;

  uSAC::IO::socket_stage($l, sub {
      $_[1]{data}={
        reuse_port=>1,
        reuse_addr=>1,
        on_bind=>\&uSAC::IO::listen,
        on_listen=>sub { &uSAC::IO::accept; $cb->()},
        on_accept=>sub {
          say STDERR  "ADDING CLIENT=====";
          my $clients=$_[0];
          push $_bridges->@*, uSAC::FastPack::Broker::Bridge->new(broker=>$self, rfd=>$_, wfd=>$_) for @$clients;
        },
        on_error=>sub {
          say STDERR "OIJSDF";
        }
        ,
      };
      &uSAC::IO::bind;
    });

}

method add_bridge {
  
  my ($rfd, $wfd)=@_;
  
  push $_bridges->@*, uSAC::FastPack::Broker::Bridge->new(broker=>$self, rfd=>$rfd, wfd=>$wfd);


}

# A peer is a broker/client on the other end of the the connection
# assign an id internally
# This method is called by a stub client and connection creation to allow
# system configuration (from both ends)
method add_peer_listener {

  my $sub=shift;
  my $uuid;

  $uuid;


  # Go through the matchting table and sub scribe to the peer for all matchers
  # both ends do this, which propagates the listing throughout the entire system!

}

sub Default {
  $Default;
}

# Create Setup the default broker entry points
#
unless($Default){
  $Default=uSAC::FastPack::Broker->new;
  *usac_broadcast=$Default->get_broadcaster;
  *usac_listen=$Default->get_listener;
  *usac_ignore=$Default->get_ignorer;
}
1;
