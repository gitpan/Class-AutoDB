package TestAutoDB_4;
# same as TestAutoDB_3, but without %AUTODB connection params
use lib qw(. t ../lib);
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use Class::AutoDB;
@ISA=qw(Class::AutoClass);

  @AUTO_ATTRIBUTES=qw(this that other);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();
  %AUTODB=(-collection=>__PACKAGE__,
	       -keys=>qq(this int, that string, other list(string)),
	      );
  Class::AutoClass::declare(__PACKAGE__);

1;
