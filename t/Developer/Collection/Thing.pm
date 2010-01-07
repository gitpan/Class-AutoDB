package Thing;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
@ISA=qw(Class::AutoClass);
use DBConnector;

@AUTO_ATTRIBUTES=qw(name sex friends);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(-collection=>__PACKAGE__,
	 -keys=>qq(name string, sex string, friends list(object))
	);
Class::AutoClass::declare;

1;
