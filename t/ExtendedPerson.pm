package ExtendedPerson;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %DEFAULTS %AUTODB);
use Class::AutoClass;
use Person;
@ISA=qw(Class::AutoClass Person);

@AUTO_ATTRIBUTES=qw(weakness);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(
	 -collection=>'Person',
   -keys=>qq(weakness string));
Class::AutoClass::declare(__PACKAGE__);

1;
