package Mojo::Recache;
use Mojo::Base 'Mojo::EventEmitter';

use overload
  bool => sub {1},
  fallback => 1;

use Mojo::DynamicMethods -dispatch;
use Mojo::Loader 'load_class';
use Mojo::Recache::Cache;
use Mojo::Util 'monkey_patch';

use Carp;
use Scalar::Util 'blessed';

use constant BACKEND    => $ENV{MOJO_RECACHE_BACKEND} || 'Storable';
use constant CRON       => $ENV{CRON}                 || 0;
use constant DEBUG      => $ENV{MOJO_RECACHE_DEBUG}   || 0;
use constant RECACHEDIR => $ENV{MOJO_RECACHE_DIR}     || 'recache';

has app     => undef;
has cache   => undef;
has recache => sub { Mojo::Recache->new(app => shift->app) };

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
        my $class = shift;
        my $backend = shift if @_==2;
        bless \Mojo::Recache::_backend($backend)->new(shift), $class
      }
    );
  } else {
    eval q(
      package Mojo::Recache::overload;
      sub new {
        my $class = shift;
        my $backend = shift if @_==2;
        Mojo::Recache::_backend($backend)->new(shift);
      }
    );
  }
  if ( $flags{'-autoload'} ) {
    eval q(
      sub AUTOLOAD {
        my $self = shift;

        my ($package, $method) = our $AUTOLOAD =~ /^(.+)::(.+)$/;
        return if $method =~ /^(app|cache|recache|register_sub)$/;
        Carp::croak "Undefined subroutine &${package}::$method called"
          unless blessed $self && $self->isa(__PACKAGE__);

        $self->app->cached(1) if blessed $self->app && $self->app->can('cached');
        my $data;
        if ( blessed $self->app ) {
          $data = $self->app->$method(@_);
        } else {
          my $app = \&{$self->app.'::'.$method};
          $data = $app->(@_);
        }
        $self->app->cached(0) if blessed $self->app && $self->app->can('cached');
        my $cache = Mojo::Recache::Cache->new(method => $method, args => [@_], data => $data);
        return Mojo::Recache::overload->new(
          $self->new(app => $self->app, cache => $cache)
        );
      }
    );
  } else {
    Mojo::Util::monkey_patch($class, 'register_sub', sub { _register_sub(shift, \%flags, @_) });
    eval q(
      sub BUILD_DYNAMIC {
        my ($class, $method, $dyn_methods) = @_;
        return sub {
          my ($self, @args) = @_;
          my $dynamic = $dyn_methods->{$self}{$method};
          return $self->$dynamic(@args) if $dynamic;
          my $package = ref $self;
          die qq{Can't locate object method "$method" via package "$package"};
        };
      }
    );
  }
}

# Set a good default in the attribute
sub new { shift->SUPER::new(app => scalar caller, @_) }

sub _backend {
  my $class = 'Mojo::Recache::Backend::' . (shift || BACKEND);
  my $e     = load_class $class;
  croak ref $e ? $e : qq{Backend "$class" missing} if $e;
  return $class;
}

sub _register_sub {
  my ($self, $flags) = (shift, shift);
  while ( @_ ) {
    my $method = shift;
    Carp::croak "Cannot register reserved keyword '$method'" if $method =~ /^(app|cache|recache|register_sub)$/;
    my $code = shift if ref $_[0] eq 'CODE';
    $code ||= sub {
      my $self = shift;
      $self->app->cached(1) if blessed $self->app && $self->app->can('cached');
      my $data;
      if ( blessed $self->app ) {
        $data = $self->app->$method(@_);
      } else {
        my $app = \&{$self->app.'::'.$method};
        $data = $app->(@_);
      }
      $self->app->cached(0) if blessed $self->app && $self->app->can('cached');
      my $cache = Mojo::Recache::Cache->new(method => $method, args => [@_], data => $data);
      return Mojo::Recache::overload->new(
        $self->new(app => $self->app, cache => $cache)
      );
    };
    Mojo::DynamicMethods::register ref $self, $self, $method, $code;
  }
  return $self;
}

1;
