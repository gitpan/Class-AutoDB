package TestAutoDB_2;
# same as TestAutoDB_3, but with connection params
use lib qw(. t ../lib);
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
@ISA=qw(Class::AutoClass);

  @AUTO_ATTRIBUTES=qw(this that other);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  %AUTODB=(-collection=>__PACKAGE__,
	       -keys=>qq(this int, that string, other list(string)),
         -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
         -user=>$DBConnector::DB_USER,
         -password=>$DBConnector::DB_PASS
	      );
  Class::AutoClass::declare(__PACKAGE__);

1;
