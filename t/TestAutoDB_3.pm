# sets up %AUTODB with connection params
package TestAutoDB_3;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use Class::AutoDB;
use DBConnector;

@ISA=qw(Class::AutoClass);

BEGIN {
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
}

1;
