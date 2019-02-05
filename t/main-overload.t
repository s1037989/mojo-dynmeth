use Test::More;

use Mojo::Recache -overload;

sub array { [@_] }

my $recache = Mojo::Recache->new;
my $array = $recache->array(99..102);
isa_ok ref $array, 'Mojo::Recache::overload';
eval { @$array; };
ok !$@, 'ARRAY reference (-overload pragma)';
eval { $$array; };
ok !$@, 'SCALAR reference (-overload pragma)';
is $$array->cache->data->[0], 99, 'right first value in cached data array';
is $$array->cache->method, 'array', 'right method name in cache';

done_testing;
