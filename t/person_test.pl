use Class::AutoDB;
use Person;
use Data::Dumper;

my $autodb=new Class::AutoDB(-database=>'test', -create=>1);
my $joe=new Person(-name=>'Joe',-sex=>'male');
my $mary=new Person(-name=>'Mary',-sex=>'female');
my $bill=new Person(-name=>'Bill',-sex=>'male');
# Set up friends lists
$joe->friends([$mary,$bill]);
$mary->friends([$joe,$bill]);
$bill->friends([$joe,$mary]);
$autodb->put_objects;           # store objects in database

# and later...
sleep 1;

my $autodb=new Class::AutoDB(-database=>'test');
my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');
while (my $j = $cursor->get_next){
  $j->name('Joey');
  #print "==> ", $j->oid, "\n";
  $j->put;
}

# and later...
sleep 1;

my $autodb=new Class::AutoDB(-database=>'test');
my $cursor=$autodb->find(-collection=>'Person',-name=>'Joey');
my @joes=$cursor->get;
#print Dumper @joes;
print "==> ", $joes[0]->oid, "\n";

