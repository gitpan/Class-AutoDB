package testAutoDB;
use strict;
use Class::AutoClass;
use Class::AutoDB;

use vars qw(@ISA @AUTO_ATTRIBUTES %AUTODB);
@ISA = qw(Class::AutoClass Class::AutoDB::Serialize);

@AUTO_ATTRIBUTES=qw(skey1 skey2 skey3 skey4 lkey1 lkey2 lkey3 lkey4);

%AUTODB=
  (-collection=>'Collection',
   -keys=>q(skey1 string, skey2 integer, skey3 float, skey4 object,
	    lkey1 list(string), lkey2 list(integer), lkey3 list(float), lkey4 list(object)),
  );
Class::AutoClass::declare(__PACKAGE__);

1;

