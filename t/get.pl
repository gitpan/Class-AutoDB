use strict;
use lib qw(. t ../lib);
use Person;
use DBConnector;

my $autodb = Class::AutoDB->new(
                          -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
                          -user=>$DBConnector::DB_USER,
                          -password=>$DBConnector::DB_PASS
                        );

# Query the database
my $j_cursor=$autodb->find(-collection=>'Person',-name=>'Joe');

my @joes=$j_cursor->get;
for my $joe (@joes) {
  # $joe is a Person object -- do what you want with it
  my $friends=$joe->friends; 
  for my $friend (@$friends) {
    my $friend_name=$friend->name;
    print "Joe's friend is named $friend_name\n";
  }
}

my $m_cursor=$autodb->find(-collection=>'Person',-name=>'Mary');

my @marys=$m_cursor->get;
for my $mary (@marys) {
  # $mary is a Person object -- do what you want with it
  my $friends=$mary->friends; 
  for my $friend (@$friends) {
    my $friend_name=$friend->name;
    print "Mary's friend is named $friend_name\n";
  }
}

my $b_cursor=$autodb->find(-collection=>'Person',-name=>'Bill');

my @bills=$b_cursor->get;
for my $bill (@bills) {
  # $bill is a Person object -- do what you want with it
  my $friends=$bill->friends; 
  my $friend_name;
  for my $friend (@$friends) {
    eval { $friend_name=$friend->name };
    next if $@; # bill has a scalar in his friend list
    print "Bill's friend is named $friend_name\n" if $friend_name;
  }
}
