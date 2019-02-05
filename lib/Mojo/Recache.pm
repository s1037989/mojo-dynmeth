package Mojo::Recache;
use Mojo::Base 'Mojo::EventEmitter';

use overload
  bool => sub {1},
  fallback => 1;

use Mojo::Home;
use Mojo::Loader 'load_class';
use Mojo::Recache::Cache;
use Mojo::Util 'monkey_patch';

use Carp;
use Scalar::Util 'blessed';

use constant BACKEND => $ENV{MOJO_RECACHE_BACKEND} || 'Storable';
use constant CRON    => $ENV{CRON}                 || 0;
use constant DEBUG   => $ENV{MOJO_RECACHE_DEBUG}   || 0;
use constant HOME    => $ENV{MOJO_RECACHE_HOME}    || 'recache';

has app     => undef;
has backend => BACKEND;
has cache   => undef;
has home    => sub { Mojo::Home->new->detect(shift->app)->child(HOME) };

my %RESERVED = map { $_ => 1 } (
  qw(app backend cache home)
);

sub import {
  my ($class, $caller) = (shift, caller);
  my %flags = map { $_ => 1 } @_;
  if ( $flags{'-overload'} ) {
    eval q(
      package Mojo::Recache::overload;
      use overload
        '@{}' => sub { ${$_[0]}->cache ? ${$_[0]}->cache->data : [] },
        '%{}' => sub { ${$_[0]}->cache ? ${$_[0]}->cache->data : {} },
        bool  => sub {1},
        '""'  => sub { ${$_[0]}->cache ? ${$_[0]}->cache->data : '' },
        fallback => 1;
      sub new {
        my ($class, $cb) = (shift, ref $_[-1] eq 'CODE' ? pop : undef);
        my $backend = shift if @_==2;
        $backend = Mojo::Recache::_backend($backend)->new(shift);
        $backend->$cb if $cb;
        bless \$backend, $class;
      }
    );
  } else {
    eval q(
      package Mojo::Recache::overload;
      sub new {
        my ($class, $cb) = (shift, ref $_[-1] eq 'CODE' ? pop : undef);
        my $backend = shift if @_==2;
        $backend = Mojo::Recache::_backend($backend)->new(shift);
        $backend->$cb if $cb;
        return $backend;
      }
    );
  }
}

sub AUTOLOAD {
  my $self = shift;

  my ($package, $method) = our $AUTOLOAD =~ /^(.+)::(.+)$/;
  return if grep { /^$method$/ } keys %RESERVED;
  Carp::croak "Undefined subroutine &${package}::$method called"
    unless blessed $self && $self->isa(__PACKAGE__);

  $self->_cache_method($method => [@_], sub {
    my $self = shift;
    $self->retrieve or $self->store;
  });
}

# Set a good default in the attribute
sub new { shift->SUPER::new(app => scalar caller, @_) }

sub _backend {
  my $class = 'Mojo::Recache::Backend::' . (shift || BACKEND);
  my $e     = load_class $class;
  croak ref $e ? $e : qq{Backend "$class" missing} if $e;
  return $class;
}

sub _cache_method {
  my ($self, $method, $args, $cb) = @_;
  my $cache = Mojo::Recache::Cache->new(method => $method, args => $args);
  my $recache = $self->new(
    app => $self->app, cache => $cache, home => $self->home
  );
  my $overload = Mojo::Recache::overload->new(
    $self->backend, $recache, $cb || ()
  );
  return $overload;
}

1;
