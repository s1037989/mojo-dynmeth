use Test::More;

use Mojo::Collection 'c';
use Mojo::Recache;

sub array { [@_] }
sub collection { c(@_) }

is array(99..102)->[0], 99, 'right first value in array';
is collection(99..102)->first, 99, 'right first value in collection';
is collection(99..102)->first(qr/101/), 101, 'right collection value';

# Keep the recache repo clear for these tests
my $cleanup = Mojo::Recache->new;
$cleanup->home->remove_tree if $cleanup->home->basename eq 'recache';

my $recache = Mojo::Recache->new;
isa_ok $recache, 'Mojo::Recache';
isa_ok $recache->app, 'main';
isa_ok $recache->app->array(99..102)->[0], 'main';
isa_ok $recache->home, 'Mojo::Home';
is $recache->home->basename, 'recache', 'right recache child of home';
my $array = $recache->array(99..102);
isa_ok $array, 'Mojo::Recache::Backend';
isa_ok $array, 'Mojo::Recache::Backend::Storable';
eval { @$array; };
ok $@, 'not an ARRAY reference (no -overload flag)';
eval { $$array; };
ok $@, 'not a SCALAR reference (no -overload flag)';
is $array->cache->data->[0], 99, 'right first value in cached data array';
is $array->cache->method, 'array', 'right method name in cache';
isa_ok $array->home, 'Mojo::Home';
is $array->home->basename, 'recache', 'right recache child of home';
like $array->cache->name, qr(^[0-9a-f]{32}$), 'looks like a name';
ok -e $array->file->touch->to_string, 'file exists';

my $recache1 = Mojo::Recache->new;
my $array1 = $recache1->array(199..202);
is $array1->cache->data->[0], 199, 'right first value in cached data array';
is $array->cache->data->[0], 99, 'still right first value in previous cached data array (no -singleton flag)';
is $array1->cache->data->[0], 199, 'still right first value in this cached data array (no -singleton flag)';
ok length($array->cache->name)==32 && length($array1->cache->name)==32 && $array->cache->name ne $array1->cache->name, 'different names';
is $recache1->collection(99..102)->first(qr/101/), 101, 'right collection value';

$cleanup->home->remove_tree if $cleanup->home->basename eq 'recache';
done_testing;
