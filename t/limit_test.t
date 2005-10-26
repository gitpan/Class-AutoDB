use Class::AutoDB;
use Person;
use Data::Dumper;
use Test::More qw/no_plan/;

# test fetching a result with limit set

my $autodb=new Class::AutoDB(-database=>'test', -create=>1);

for (1..3){
 foreach my $p (qw(joe mary bill)) {
   new Person(-name=>"$p", -sex=>'unknown');
 }
}

$autodb->put_objects;  # store objects in database

sleep 1; # avoid race conditions

# check full collection
my $full_cursor=$autodb->find(-collection=>'Person',-sex=>'unknown');
is($full_cursor->count, 9, 'first fetch gets all results');
# retrieve only up to the limit
my $limit_cursor=$autodb->find(-collection=>'Person',-sex=>'unknown',_limit_=>3);
is(scalar @{$limit_cursor->get}, 3, 'second fetch gets limit 3');
