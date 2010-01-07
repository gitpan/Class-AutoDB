package testSerialize_RuntimeUseSubclass;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use Class::AutoClass;
use Class::AutoDB::Serialize;
use base qw(testSerialize_RuntimeUse);

@AUTO_ATTRIBUTES=qw(id);
Class::AutoClass::declare;

1;
