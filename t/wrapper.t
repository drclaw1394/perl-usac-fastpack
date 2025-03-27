use v5.36;
use Test::More;
# Wrapper to use the usac script to run the tests

my @files=grep !/\.dis$/, <t/usac/*>;

use File::Basename qw<basename>;
for(@files){
  my $filename=basename $_;
  say STDERR  "Wrapper running  $filename";
  say STDERR "";
  `usac --backend AnyEvent t/usac/$filename @ARGV`;
  ok $? == 0,  "Sub file passed";
}

ok 1;
done_testing;
