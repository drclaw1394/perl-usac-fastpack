package uSAC::FastPack;
use v5.36;
use Data::FastPack;
use Data::FastPack::Meta;
use feature ":all";

our $VERSION = v0.1.0;

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
    my $sub=$options{sub};
    

    my ($next, $index, @optional)=@_;
    #my $buffer="";
    sub {
      my $outputs=[];
      my $cb=$_[1];

      Data::FastPack::decode_fastpack $_[0][0], $outputs, undef, $ns;

      for(@{$outputs}){
        if($_->[FP_MSG_ID] eq '0' ){
          $_->[FP_MSG_PAYLOAD] =decode_meta_payload $_->[FP_MSG_PAYLOAD];
          for($_->[FP_MSG_PAYLOAD]{listen}){
            $_->{sub}=$sub if $_;
          }
          for($_->[FP_MSG_PAYLOAD]{ignore}){
            $_->{sub}=$sub if $_;
          }
        }
      }
      say STDERR "DECODE FASTPACK====";

      $next->([$source_id, $outputs], $cb);
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
      #my $source=$_[0];
      my $source=shift @{$_[0]};
      my $inputs=$_[0][0];

      my $cb=$_[1];
      my $buffer="";

      for(@$inputs){
        $_->[FP_MSG_PAYLOAD] =encode_meta_payload $_->[FP_MSG_PAYLOAD] if $_->[FP_MSG_ID] eq '0';
      }

      Data::FastPack::encode_fastpack $buffer, $inputs, undef, $ns;
      say STDERR "BUFFER  lenght is  ". length $buffer;
      $next->([$buffer], $cb); 
    }
  }
}

1;
