package Place;

use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES @OTHER_ATTRIBUTES %SYNONYMS %AUTODB);
use Class::AutoClass;
use DBConnector;
@ISA=qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(name location attending sites);
@OTHER_ATTRIBUTES=qw();
%SYNONYMS=();
%AUTODB=(-collection=>__PACKAGE__,
	   -keys=>qq(name string, location string, attending object, sites list(string)),
	  );
Class::AutoClass::declare(__PACKAGE__);

1;