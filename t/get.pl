package Person;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS %AUTODB);
use lib qw(. t ../lib);
use Class::AutoClass;

@ISA=qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(name sex friends);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(
	 -collection=>'Person',
	 -keys=>qq(name string, sex string, friends list(string)));
Class::AutoClass::declare(__PACKAGE__);

package main;
use strict;
use Class::AutoDB;
use Data::Dumper;

my $autodb=new Class::AutoDB(-dsn=>'DBI:mysql:database=AutoMagic__testSuite;host=localhost',-user=>'root');

# Query the database
my $cursor=$autodb->find(-collection=>'Person',-name=>'Joe');

#print "Number of Joe's in database: ",$cursor->count,"\n";
#while (my $joe=$cursor->get_next) {          # Loop getting the objects one by one

my @joes=$cursor->get;
for my $joe (@joes) {
  # $joe is a Person object -- do what you want with it
  my $friends=$joe->friends;
  for my $friend (@$friends) {
    my $friend_name=$friend->name;
    print "Joe's friend is named $friend_name\n";
  }
}

