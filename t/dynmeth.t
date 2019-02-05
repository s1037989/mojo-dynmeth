use Test::More;

use Mojo::Recache;

sub array { [@_] }

my $recache = Mojo::Recache->new;
$recache->register_sub('array');
my $array = $recache->array(99..102);
is $array->cache->data->[0], 99;
is $array->cache->method, 'array';

done_testing; exit;
__END__

my $app = MyApp->new;
warn $app->array;

my $app1 = MyApp->new->recache->overload($ARGV[0])->singleton($ARGV[1]);
my $a = $app1->array(7..9);
my $b = $app1->array(11..13);
if ( $app1->overload ) {
  warn $a->[0];
  warn $$a->data->[0];
  warn $b->[0];
  warn $$b->data->[0];
} else {
  warn $a->data->[0];
  warn $b->data->[0];
}

my $app2 = MyBadApp->new;
my $a2 = $app2->array(14..17);
warn $a2;
warn $a2->[0];

my $app3 = Mojo::Recache->new(app => MyBadApp->new, overload => $ARGV[0], singleton => $ARGV[1]);
$app3->cache_this('array');
my $a3 = $app3->array(21..24);
warn $a3;
warn $a3->[0];
warn $$a3->data->[0];


#warn $app1->array->method;
#warn $app1->array->data;
#my $a = $app1->array;
#warn $a;
#warn $a->data;
#my $a3 = $app1->slow(3);
#warn $a3->data;
#my $a4 = $app1->slow(4);
#warn $a3->data;
#warn sprintf "%s(%s)", $a3->cache->method, @{$a3->cache->args};
#warn $a4->data;
#warn sprintf "%s(%s)", $a4->cache->method, @{$a4->cache->args};
