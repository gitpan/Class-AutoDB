package Person;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES
%SYNONYMS %DEFAULTS
%AUTODB);
use Class::AutoClass;

@ISA=qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(name sex friends alias hobbies);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(
-collection=>'Person',
-keys=>qq(name string, sex string, hobbies list(string), friends list(mixed)));
Class::AutoClass::declare(__PACKAGE__);

1;