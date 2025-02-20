use v5.36;

use Test::More;
BEGIN { use_ok('uSAC::FastPack') };

use uSAC::FastPack;
use Sub::Middler;

# Create middlewares

my $enc=sm_fastpack_encoder;
ok $enc, "encoder created ok";

my $dec=sm_fastpack_decoder;
ok $dec, "decoder created ok";


my $chain=Sub::Middler->new;

$chain->register($enc);
$chain->register($dec);


# Create some messages
my @input=([time, "my/name", "this is data"]);


my @copy=map [@$_], @input;


my $head=$chain->link(
  sub {
    # This is the end point 
    # Do a test comparision of output arrays
    #
    ok $_[0]->@* == @copy, "same message count";
    for my $s (0..$#copy){
     for my $i (0..2){ 
      ok $copy[$s][$i] eq $_[0][$s][$i];

      }
    }
  }
);



# execute
$head->(\@input, "callback");

ok $head, "Head generated";
done_testing;
1;
