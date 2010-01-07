package Foo;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Serialize;
@ISA=qw(Class::AutoClass Class::AutoDB::Serialize); # AutoClass must be first!!;

@AUTO_ATTRIBUTES=qw(message next prev list bar);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
Class::AutoClass::declare;
use overload
  fallback => 'TRUE';
1;

package Bar;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS);
use strict;
use Class::AutoClass;
@ISA = qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(message next prev list);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
Class::AutoClass::declare;

use overload
  fallback => 'TRUE';
1;
