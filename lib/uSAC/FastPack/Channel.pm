package uSAC::FastPack::Channel;

use uSAC::IO;
use Data::Dumper;
use feature ":all";
use Object::Pad;
use UUID qw<uuid4>;
use Data::FastPack;
use Data::FastPack::Meta;

use constant::more DEBUG=>0;

class uSAC::FastPack::Channel;

field $_uuid :param=undef;
field $_mode :param=undef;
field $_broker :param;

field $_on_data :mutator;
field $_on_control :mutator;
field $_data_in_name;
field $_control_in_name;

field $_data_out_name;
field $_control_out_name;

BUILD {
  #$_uuid//=uuid4;
}

# Setup listeners depending on mode
method _setup {

  # If sender is set, called by accept
  my $sender=shift;
  my $on_connect=shift;


  if($_mode eq "master"){
    DEBUG and asay $STDERR, "DOING Master SETUP: $_uuid";
    $_data_in_name=    "$_uuid/MISO";
    $_data_out_name=    "$_uuid/MOSI";
    $_control_in_name= "$_data_in_name/CTL";
    $_control_out_name= "$_data_out_name/CTL";

    $_broker->listen(undef, $_control_in_name,  sub {

        DEBUG and asay $STDERR, "CONTROL LISTENER for master $_control_in_name";
        $_on_control and $_on_control->($_[0][1][0][FP_MSG_PAYLOAD]);
      },

      "exact");

    # If called with a sender, check if a bridge and setup fowarding for
    # anything on channel uuid
    my $bridge=$_broker->bridges->{$sender}; 
    if($bridge){
      $_broker->listen(undef, $_uuid, $bridge, "begin");
    }
    # Data listening
    #
    $_broker->listen(undef, $_data_in_name, sub {
        DEBUG and asay $STDERR, "$_on_data D== Data in". Dumper @_;

        $_on_data and $_on_data->($_[0][1][0][FP_MSG_PAYLOAD]);
      },
      "exact");
    $on_connect and $on_connect->($self); 
  }
  else {
    DEBUG and asay $STDERR, "DOING slave SETUP:  $_uuid";
    $_data_in_name="$_uuid/MOSI";
    $_data_out_name="$_uuid/MISO";

    $_control_in_name= "$_data_in_name/CTL";
    $_control_out_name= "$_data_out_name/CTL";

    my $first=1;
    $_broker->listen(undef, $_control_in_name,  sub {
        DEBUG and asay $STDERR, "CONTROL LISTENER for slave $_control_in_name";
        # Intercept the control  messages
        # the first messgae is used to initiate forwarding
        # and acknowlege the connection
        #
        if($first){
          my $sender=$_[0][0];
          my $bridge=$_broker->bridges->{$sender}; 
          if($bridge){
            $_broker->listen(undef, $_uuid, $bridge, "begin");
          }

          $on_connect and $on_connect->($self); 
          $first=undef;
        }
        else {
          $_on_control and $_on_control->($_[0][1][0][FP_MSG_PAYLOAD]);
        }
      },
      "exact"
    );
    # Data listening
    #
    $_broker->listen(undef, $_data_in_name, sub {
        $_on_data and $_on_data->($_[0][1][0][FP_MSG_PAYLOAD]);
      },
      "exact");
  }



}


# Initiate a slave to connect to master
#
method connect {
  my $connection_endpoint=shift;
  my $callback=shift;

  $_uuid//=uuid4;
  $_mode="slave";

  my %obj=(
    uuid=>$_uuid,
    rate_limit=>0,
    virtual_buffer_size=>16
  );

  $self->_setup(undef, $callback);

  $_broker->broadcast(undef, $connection_endpoint, encode_meta_payload \%obj);


};


# Class method, setup a listener for the connection enpoint
# Does a callback with a new channel set up as master
#
sub accept{
  shift;
  my $connection_endpoint=shift;
  my $broker=shift;
  my $callback=shift;

  $broker->listen(undef, $connection_endpoint, sub {
      my $data=shift;
      my $sender=$data->[0];
      my $payload=$data->[1][0][FP_MSG_PAYLOAD];
      DEBUG and asay $STDERR, $payload;
      my $object=decode_meta_payload $payload;

      my $channel=uSAC::FastPack::Channel->new(uuid=>$object->{uuid}, broker=>$broker, mode=>"master");

      DEBUG and asay $STDERR, "ACCEPT END POINT CALLED by new sender: $sender";
      $channel->_setup($sender, $callback);
      $channel->send_control("");

      #$callback and $callback->($channel);
    },
    "exact"
  );
}

method send_data {
  DEBUG and asay $STDERR, "SENDING TO peer on $_data_out_name";
  $_broker->broadcast(undef, $_data_out_name, $_[0]);
}

method send_control {
  $_broker->broadcast(undef, $_control_out_name, $_[0]);
}

1;
