use lib qw(. t ../lib);
use strict;
use Test::More qw/no_plan/;
use Class::AutoDB::WeakCache;
use Data::Dumper; # only for testing

# Title   : instance
# Usage   : $wc = Class::AutoDB::WeakCache->instance();
# Function: creates global static reference to weak cache
# Returns : Class::AutoDB::WeakCache instance
# Args    : none
# Notes   : subclasses Class::WeakSingleton

my $wc = Class::AutoDB::WeakCache->instance();
is(ref $wc,'Class::AutoDB::WeakCache');

#
# Title   : cache
# Usage   : $wc->cache($unique_id,$self);
# Function: takes a reference to an object and a lookup key and deep copies the object
#         : (AutoDB references are not copied) for freezing.
# Returns : the cached object
# Args    : string identifier, object
# Notes   : 

my $test1 = new Test;
my $adb = new Class::AutoDB; # not the real Class::AutoDB - see below
my $unique_id = '1234';

my $test1_return = $wc->cache($unique_id,$test1);
my $test2_return = $wc->cache('AutoDB',$adb);

is(ref($test1_return), 'Test');
is(ref($test2_return), 'Class::AutoDB');

# Title   : exists
# Usage   : $wc->exists($unique_id);
# Function: find out if an object with identifier $unique_id has been cached
# Returns : 1 if exists, else 0
# Args    : string identifier
# Notes   : 

is($wc->exists($unique_id), 1);
is($wc->exists('AutoDB'), 1);

# Title   : recall
# Usage   : $wc->recall($unique_id);
# Function: retrieve the cached object (in the case of Class::AutoDB object)
#         : or a copy (snapshot when cache() is called) of the object
# Returns : see above
# Args    : string identifier
# Notes   : 

is($wc->recall('AutoDB'),$adb,'Class::AutoDB holds a reference, not a copy');
isnt($wc->recall($unique_id),$test1,'other objects are copies');

$test1->{this}='that';
$adb->{other}='something';

# the following test _should_ use is_deeply, but I can't seem to negate it => need isnt_deeply
isnt($wc->recall($unique_id),$test1,'modified original object not same as cloned cached version');
is_deeply($wc->recall('AutoDB'),$adb,'but Class::AutoDB holds a reference, not a copy');

# Title   : dump
# Usage   : $wc->dump;
# Function: dumps the contents of the cache
# Returns : a hash ref of stored hashes or undef if none exist
# Args    : none
# Notes   : 

is(scalar keys %{$wc->dump}, '2', 'dump returns both objects');
is($wc->dump->{AutoDB}->{other},'something','Class::AutoDB state was updated (cache stores reference)');
is($wc->dump->{$unique_id}->{this},undef,'other classes returned in their cached state (cache stores copy)');

# Title   : remove
# Usage   : $wc->remove($unique_id);
# Function: removes the object pointed to by identifier from the cache
# Returns : the removed object
# Args    : string identifier
# Notes   :

is(ref($wc->remove('AutoDB')),'Class::AutoDB');
is(scalar keys %{$wc->dump}, '1', 'dump returns only remaining object after other is removed');

# Title   : clean
# Usage   : $wc->clean;
# Function: resets the cache, removing all obects and their identifiers
# Returns : undef
# Args    : 
# Notes   :

is($wc->clean,undef);
is(scalar $wc->dump, undef, 'no objects remain after clean()');

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