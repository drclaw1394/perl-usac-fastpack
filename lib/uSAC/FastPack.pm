package uSAC::FastPack;
use v5.36;
use Data::FastPack;
use Data::FastPack::Meta;
use feature ":all";


use Export::These qw<sm_fastpack_encoder sm_fastpack_decoder>;


# Create middleware to decode a buffer (from a reader) in to parsed messages
#
sub sm_fastpack_decoder {

  my %options=@_;
  sub {
    my $ns;
    if($options{no_namespace}){
      # if requested do not use namespaces
      $ns=undef;
    }
    else {
      # default is to use namespace. create a new one if required
      $ns=$options{namespace}//create_namespace;
    }
    my $source_id=$options{source_id};

    my ($next, $index, @optional)=@_;
    #my $buffer="";
    sub {
      my $outputs=[];
      my $cb=$_[1];

      Data::FastPack::decode_fastpack $_[0], $outputs, undef, $ns;

      for(@{$outputs}){
        $_->[FP_MSG_PAYLOAD] =decode_meta_payload $_->[FP_MSG_PAYLOAD] if $_->[FP_MSG_ID]==0;
      }

      $next->($source_id, $outputs, $cb);
    }
  }
}


# Create middleware to encode messages into a stream
sub sm_fastpack_encoder {

  my %options=@_;
  sub {
    my ($next, $index, @optional)=@_;
    my $ns;

    if($options{no_namespace}){
      $ns=undef;
    }
    else{
      $ns=$options{namespace}//create_namespace;
    }


    sub {
      #my $inputs=$_[0];
      my $cb=$_[1];
      my $buffer="";

      for(@{$_[0]}){
        $_->[FP_MSG_PAYLOAD] =encode_meta_payload $_->[FP_MSG_PAYLOAD] if $_->[FP_MSG_ID]==0;
      }

      Data::FastPack::encode_fastpack $buffer, $_[0], undef, $ns;
      $next->($buffer, $cb); 
    }
  }
}

1;
