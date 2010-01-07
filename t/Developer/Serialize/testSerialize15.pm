package testSerialize;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use Class::AutoClass;
use Class::AutoDB::Serialize;
@ISA=qw(Class::AutoClass Class::AutoDB::Serialize);

@AUTO_ATTRIBUTES=qw(id list list1 list2);
%DEFAULTS=(list=>[],list1=>[],list2=>[]);
Class::AutoClass::declare;

use overload
  fallback => 'TRUE';
1;
