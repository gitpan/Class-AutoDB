package TestAutoDBOutside_2;

# ISA Class::AutoClass but not AutoDB able

use lib qw(. t ../lib);
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use DBConnector;

@ISA=qw(Class::AutoClass);

  @AUTO_ATTRIBUTES=qw(this that other);
  @OTHER_ATTRIBUTES=qw();
  %SYNONYMS=();

  Class::AutoClass::declare(__PACKAGE__);

1;
