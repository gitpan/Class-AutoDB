use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::DeleteCache;

# Title   : instance
# Usage   : $dc = Class::AutoDB::DeleteCache->instance();
# Function: creates global static reference to weak cache
# Returns : Class::AutoDB::DeleteCache instance
# Args    : none
# Notes   : subclasses Class::WeakSingleton

my $dc = Class::AutoDB::DeleteCache->instance();
is(ref $dc,'Class::AutoDB::DeleteCache');

#
# Title   : cache
# Usage   : $dc->cache($unique_id,$self);
# Function: takes a reference to an object and a lookup key and deep copies the object
#         : (AutoDB references are not copied) for freezing.
# Returns : the cached object
# Args    : string identifier, object
# Notes   : 

my $test1 = new Test;
my $adb = new Class::AutoDB; # not the real Class::AutoDB - see below
my $unique_id = '1234';

my $test1_return = $dc->cache($unique_id,$test1);
my $test2_return = $dc->cache('AutoDB',$adb);

is(ref($test1_return), 'Test');
is(ref($test2_return), 'Class::AutoDB');

# Title   : exists
# Usage   : $dc->exists($unique_id);
# Function: find out if an object with identifier $unique_id has been cached
# Returns : 1 if exists, else 0
# Args    : string identifier
# Notes   : 

is($dc->exists($unique_id), 1);
is($dc->exists('AutoDB'), 1);

# Title   : recall
# Usage   : $dc->recall($unique_id);
# Function: retrieve the cached object (in the case of Class::AutoDB object)
#         : or a copy (snapshot when cache() is called) of the object
# Returns : see above
# Args    : string identifier
# Notes   : 

is($dc->recall('AutoDB'),$adb,'Class::AutoDB holds a reference');
is($dc->recall($unique_id),$test1,'other objects hold a reference');

$test1->{this}='that';
$adb->{other}='something';

## the following test _should_ use is_deeply, but I can't seem to negate it => need isnt_deeply
#isnt($dc->recall($unique_id),$test1,'modified original object not same as cloned cached version');
#is_deeply($dc->recall('AutoDB'),$adb,'but Class::AutoDB holds a reference, not a copy');

# Title   : dump
# Usage   : $dc->dump;
# Function: dumps the contents of the cache
# Returns : a hash ref of stored hashes or undef if none exist
# Args    : none
# Notes   : 

is(scalar keys %{$dc->dump}, '2', 'dump returns both objects');
is($dc->dump->{AutoDB}->{other},'something');
is($dc->dump->{$unique_id}->{this},'that');

# Title   : remove
# Usage   : $dc->remove($unique_id);
# Function: removes the object pointed to by identifier from the cache
# Returns : the removed object
# Args    : string identifier
# Notes   :

is(ref($dc->remove('AutoDB')),'Class::AutoDB');
is(scalar keys %{$dc->dump}, '1', 'dump returns only remaining object after other is removed');

# Title   : clean
# Usage   : $dc->clean;
# Function: resets the cache, removing all obects and their identifiers
# Returns : undef
# Args    : 
# Notes   :

is($dc->clean,undef);
is(scalar $dc->dump, undef, 'no objects remain after clean()');

## test package

package Test;

sub new {
  my $self={};
  $self->{one}=1;
  $self->{uno}=1;
  $self->{two}=2;
  $self->{dos}=2;
  return bless $self, __PACKAGE__;
}

package Class::AutoDB;

sub new {
  my $self={};
  return bless $self, __PACKAGE__;
}
1;
