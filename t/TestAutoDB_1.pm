package TestAutoDB_1;

use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use Class::AutoDB;
@ISA=qw(Class::AutoClass);

BEGIN {
  @AUTO_ATTRIBUTES=qw(a);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  %AUTODB=(-collection=>__PACKAGE__,
	   -keys=>qq(a string));
  Class::AutoClass::declare(__PACKAGE__);
}

1;
