package Person;
use lib qw(. t ../lib);
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use DBConnector;
@ISA=qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(name sex friends);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(-collection=>__PACKAGE__,
	   -keys=>qq(name string, sex string, friends list(string)),
	  );
Class::AutoClass::declare(__PACKAGE__);


1;
