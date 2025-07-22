package uSAC::FastPack::Broker;

our $VERSION = 'v0.2.0';
use v5.36;
use Time::HiRes qw<time>;

use Log::OK;

use constant::more DEBUG=>0;

use uSAC::IO qw(asay adump socket_stage);
use Object::Pad;

use Data::FastPack;
use Data::FastPack::Meta;


use uSAC::FastPack::Broker::Bridge;

use Hustle::Table;
use constant::more qw<READER=0 WRITER WRITER_SUB>;

use Data::Dumper;

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

field $_uuid;               # UUID of this broker/node/client
field $_default_source_id;
field $_default_match_mode;

field $_on_bridge :mutator;
field $_on_ready :mutator;
field $_on_error :mutator;

BUILD {

  # Configure table
  $_ht=Hustle::Table->new();

  $_bridges={};

  $_uuid=rand 10000;
  $_default_source_id= rand 10000;
  
  $_dispatcher=sub {
    DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid : In dispatcher";
    DEBUG and asay $STDERR, Dumper @_;
    my $source=shift @{$_[0]}; # The object/id from where these messages 'originated' 
                      # Could be a sub, an number, uuid
                      #
    # Filter the messages to match end points
    # NOTE: restrictions on fast pack requires a named message to not be "0" or "" (Empty string)
    # This allows a logical test only on  numeric 0, which is then detected as a system message
    # Translating it to the UUID of this node, allows for adding listeners
    #
    #my @entries=$_ht_dispatcher->(map $_->[FP_MSG_ID], @{$_[0][0]});
    for my $msg (@{$_[0][0]}){  
      DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid : Searching table for $msg->[FP_MSG_ID]";
      my @entries=$_ht_dispatcher->($msg->[FP_MSG_ID]);#map $_->[FP_MSG_ID], @{$_[0]});


      DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid : Found ".@entries." items in table";
      for my ($e, $c)(@entries){
        # Call each of the subs on matching entry with this 
        # But only call if the source filter doesnt match
        # messages are not sent back to the source, 
        # psuedo grouping
        DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid : -- entry has ".($e->[Hustle::Table::value_]->@*)/2 ." callbacks";
        for my ($sub, $source_id) ($e->[Hustle::Table::value_]->@*){
          no warnings "uninitialized";
          if(!defined($source_id) or $source ne $source_id){
            DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid : executing callback";
            $sub->([$source, [$msg, $c]]); # Dispatch messages to listener
            #uSAC::IO::asap $sub,[$source, [$msg]];
        
          }
          else {

          }
        }
      }
    }
  };

  # Create broadcaster sub
  # Takes essentially key value pairs and publishes them in a fast pack message

  $_broadcaster_sub//= sub {
    # Only key and sub pair, add source filter
    if(@_==2){
      unshift @_, undef;
    }
    my $time=time;

    my $client_id=shift;#//$_default_source_id;

    my @msg;
    for my ($name, $val)(@_){
      push @msg, [$time, $name, $val];
    }

    # Send the messages through
    # TODO: make this asap, no syncrhonous
    $_dispatcher->([$client_id, \@msg]);
    $self;
  };

  # Create listener sub
  #

  $_listener_sub=sub {
    # if called with two arguments, assume simple kv pair with anonymous source
    if(@_==2){
      unshift @_, undef;
    }
    my $source_id=shift;#//$_default_source_id;
    my $name=shift;
    my $sub=shift;
    my $type=shift//$_default_match_mode;
  
    #die 'Cannot listen for an unamed message' unless $name;

    my $object={listen=>{source=>$source_id, matcher=>$name, type=>$type, sub=>$sub}};

    # Add message to the queue 
    $_dispatcher->([$source_id, [[time, '0', $object]]]);
    $self;

  };


  # Handler for processing 0 named messages
  #

  $_meta_handler = sub {

    DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid: In meta handler";

    #my ($source_id, $msgs)=@_;
    my $source_id= shift @{$_[0]};
    my $msgs=$_[0][0];

    
    my $obj;
    my $name;
    my $sub;
    my $type;

          for my $msg (@$msgs){
            for my ($k, $v) ($msg->[FP_MSG_PAYLOAD]->%*){
              if($k eq "listen"){

                DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid: Listen message processing";
                $name=$v->{matcher};
                $sub=delete $v->{sub};
                $type=$v->{type};

                my $org_name=$name;

                # Preconvert  to ensure grouping of dispatch entries
                $name=qr{$name} if !$type;
                # Search the hustle table entries for a match against the matcher
                my $found;
                for my $e($_ht->@*){

                  no warnings "uninitialized";
                  if($e->[Hustle::Table::matcher_] eq $name and $e->[Hustle::Table::type_] eq $type){
                    push $e->[Hustle::Table::value_]->@*, $sub, $source_id;
                    $found=1;

                  DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid: $name Found existing ht entry created";
                    last;
                  }
                }

                unless($found){
                  DEBUG and Log::OK::TRACE and asay $STDERR, "$$ $_uuid: $name Could not find existing ht entry created a new one";
                  # Register an new entry with a 
                  DEBUG and asay $STDERR, "$$ ADDING name $name with type $type";
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
                my $force=$v->{bridge_close};

                my $found;
                my $pos=0;
                for my $e(reverse 0..$_ht->@*-2){
                  if($force or ($_ht->[$e][Hustle::Table::matcher_] eq $name and $_ht->[$e]->[Hustle::Table::type_] eq $type)){

                    # Remove sub from list
                    for my ($j, $i) (reverse 0..$_ht->[$e]->[Hustle::Table::value_]->@*-1){
                      DEBUG and Log::OK::TRACE and asay $STDERR,  "$$ -- j is $j  and i is $i";
                      DEBUG and Log::OK::TRACE and asay $STDERR,  "$$ -----serching $_ht->[$e]->[Hustle::Table::matcher_] with $sub == $_ht->[$e]->[Hustle::Table::value_][$i] and $source_id $_ht->[$e]->[Hustle::Table::value_][$j]?";
                      
                      if($_ht->[$e]->[Hustle::Table::value_][$i] == $sub and
                        $_ht->[$e]->[Hustle::Table::value_][$j] eq $source_id){
                      DEBUG and Log::OK::TRACE and asay $STDERR,  "$$ -----unregister $_ht->[$e]->[Hustle::Table::matcher_] with $sub == $_ht->[$e]->[Hustle::Table::value_][$i] and $source_id $_ht->[$e]->[Hustle::Table::value_][$j]?";
                        splice $_ht->[$e]->[Hustle::Table::value_]->@*, $i, 2;
                        $found=1;

                      }
                    }
                    unless($_ht->[$e][Hustle::Table::value_]->@*){
                      DEBUG and Log::OK::TRACE and asay $STDERR,  "$$ __REMOVING FROM HUSTLE TABLE at post $e----";
                      # all entries have been removed so remove from table
                      splice $_ht->@*, $e, 1;
                    }

                    #last;
                  }
                  $pos++;
                }
                $_cache={}; 
                $_ht_dispatcher=$_ht->prepare_dispatcher(cache=>$_cache);

                if($force){
                  DEBUG and Log::OK::TRACE and asay $STDERR,  "$$ Looking for bidge  $source_id";
                  my $b=delete $_bridges->{$source_id};
                  DEBUG and Log::OK::TRACE and asay $STDERR,  "$$ found  bidge  $b";
                  $b->close if $b;
                }
              }

            }
          }
  };

  # Create ingorer sub
  # 

  $_ignorer_sub=sub {
    
    if(@_==2){
      unshift @_, undef;
    }
    my $source_id=shift;#//$_default_source_id;
    my $name=shift;
    my $sub=shift;
    my $type=shift//$_default_match_mode;
  
    die 'Cannot listen for an unamed message' unless $name;
    my $object={ignore=>{source=>$source_id, matcher=>$name, type=>$type, sub=>$sub}};

    # Add message to the queue 
    $_dispatcher->([$source_id,[[time, 0, $object]]]);

    $self;
  };



  # Connector sub
  $_connector_sub= sub {
      # takes Socket::more specifiction for connecting
      my $c=shift;
      my $cb=shift;
      $_on_bridge=$cb if $cb;

      socket_stage($c, sub {
        $_[1]{data}={
          on_connect=> sub {
            DEBUG and asay $STDERR, "$$ CONNECTED TO HOST @_";
            DEBUG and asay $STDERR, Dumper @_;
            my $bridge= uSAC::FastPack::Broker::Bridge->new(broker=>$self, rfd=>$_[0], wfd=>$_[0]);
            $self->add_bridge($bridge);
          },

          on_error=>$_on_error

        };
        #asay $STDERR,  "calling usacCONNECT";
        &uSAC::IO::connect;
      });
  };



  # Bootstrap with meta handler for 'unamed' 0 id
  #
  
  $_ht->add(['0', [$_meta_handler, $_uuid], "exact"]);
  
  #Set default
  $_ht->add([undef,[sub { asay $STDERR, "UNKOWN"}, undef],'exact']);
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
  $_on_ready=$cb if $cb;
      use Data::Dumper;

  print STDERR Dumper $l;
  uSAC::IO::socket_stage($l, sub {
      print STDERR Dumper @_;
      $_[1]{data}={
        reuse_port=>1,
        reuse_addr=>1,
        on_bind=>\&uSAC::IO::listen,
        on_listen=>sub {DEBUG and asay $STDERR, "on_listen"; &uSAC::IO::accept; $_on_ready->()},
        on_accept=>sub {
          DEBUG and uSAC::IO::asay   $STDERR, "ADDING CLIENT=====";
          my $clients=$_[0];
          for my $fd (@$clients){
            DEBUG and Log::OK::TRACE and asay $STDERR, "--- Client fd is $fd";
            uSAC::IO::asap(sub {
              my $bridge= uSAC::FastPack::Broker::Bridge->new(broker=>$self, rfd=>$fd, wfd=>$fd);
              $self->add_bridge($bridge);
            });
          }
        },
        on_error=>$_on_error
      };
      &uSAC::IO::bind;
    });

}

method add_bridge {
  
  #my ($rfd, $wfd)=@_;
  #uSAC::FastPack::Broker::Bridge->new(broker=>$self, rfd=>$rfd, wfd=>$wfd);
  my $bridge=shift;
  
  $_bridges->{$bridge->source_id}=$bridge;

  # TODO: Look through the HT and send all the matchers over the bridge so the remote end will forward messages

  $_on_bridge and $_on_bridge->($bridge);


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

method _post_fork {
  $_uuid=rand 10000;
  #print STDERR "UPDATING UUID OF BROKER: $_uuid=====\n";
}

1;
