package TestAutoDB_2;
use lib qw(. t ../lib);
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use Class::AutoDB;
@ISA=qw(Class::AutoClass);

  @AUTO_ATTRIBUTES=qw(a b c);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  %AUTODB=(-collection=>__PACKAGE__,
	   -keys=>qq(a int, b int, c list(int)));
  Class::AutoClass::declare(__PACKAGE__);

1;
