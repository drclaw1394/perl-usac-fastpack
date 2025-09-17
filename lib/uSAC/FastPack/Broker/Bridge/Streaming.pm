package uSAC::FastPack::Broker::Bridge::Streaming;
use v5.36;
use uSAC::IO;
use Object::Pad;
use uSAC::Log;
use Log::OK;
use constant::more DEBUG=>0;


class uSAC::FastPack::Broker::Bridge::Streaming :isa(uSAC::FastPack::Broker::Bridge);

field $_reader :param = undef;
field $_writer :param = undef;

field $_rfd :param;
field $_wfd :param;
field $_on_error :mutator;

BUILD {
  #say "BUILD IN STREAM";

  my $source_id=$self->source_id; # From parent class. local (faster) copy

  $_reader//=reader($_rfd);
  $_writer//=writer($_wfd);

  my $dispatch=$self->broker->get_dispatcher;

  #  The sub to call with serialized data
  $self->buffer_out_sub=$_writer->writer;
  $_reader->on_read=$self->on_read_handler;

  #$self->_link;

  $_writer->on_error=$_reader->on_error=
  $_reader->on_eof=sub {
    DEBUG and Log::OK::TRACE and asay $STDERR, "$$ CLOSING THE CONNECTION";
    $self->close;
    &$_on_error if $_on_error;
  };

  $_reader->start;
}


method close :override {
  DEBUG and Log::OK::TRACE and asay $STDERR, "$$ --CONNECTION CLOSED";
  if($_reader){
    $_reader->pause;
    $_reader=undef;
    IO::FD::close($_rfd) if $_rfd;
  }
  if($_writer){
    $_writer->pause;
    $_writer=undef;
    IO::FD::close($_wfd) if $_wfd;
  }
  $self->SUPER::close();
}

1;
