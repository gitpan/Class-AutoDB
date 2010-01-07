package testSerialize;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use Class::AutoClass;
use Class::AutoDB::Serialize;
@ISA=qw(Class::AutoClass Class::AutoDB::Serialize);

@AUTO_ATTRIBUTES=qw(class_string);
%DEFAULTS=();
Class::AutoClass::declare;

1;
