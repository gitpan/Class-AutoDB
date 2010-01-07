package testSerialize_RuntimeUse;

# class whose module name is different from its filename.
# see testSerialize_RuntimeUse.pm for the other case

use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS);
use strict;
use Class::AutoClass;
use Class::AutoDB::Serialize;
@ISA=qw(Class::AutoClass Class::AutoDB::Serialize); # AutoClass must be first!!;

@AUTO_ATTRIBUTES=qw(id sane prev next list);
%DEFAULTS=(list=>[]);
# NG 09-11-19: 'neighbors' not defined or used in these tests. it looks like a leftover
#              how did it ever work??
# %DEFAULTS=(neighbors=>[]);

Class::AutoClass::declare;

1;
