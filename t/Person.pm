package Person;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use DBConnector;
@ISA=qw(Class::AutoClass);

BEGIN {
  @AUTO_ATTRIBUTES=qw(name sex friends);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  %AUTODB=(-collection=>__PACKAGE__,
	   -keys=>qq(name string, sex string, friends list(string)),
	   -dsn=>"DBI:$DBConnector::DB_NAME:database=$DBConnector::DB_DATABASE;host=$DBConnector::DB_SERVER",
           -user=>$DBConnector::DB_USER,
           -password=>$DBConnector::DB_PASS
	  );
  Class::AutoClass::declare(__PACKAGE__);
}


1;
