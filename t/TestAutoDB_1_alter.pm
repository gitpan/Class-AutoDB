package TestAutoDB_1;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use Class::AutoDB;
@ISA=qw(Class::AutoClass);

BEGIN {
  @AUTO_ATTRIBUTES=qw(a b c);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  %AUTODB=(-collection=>__PACKAGE__,
	   -keys=>qq(a string, b string, c list(string)));
  Class::AutoClass::declare(__PACKAGE__);
}

1;
