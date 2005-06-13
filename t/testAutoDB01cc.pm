package testAutoDB1;
use strict;
use Class::AutoClass;
use Class::AutoDB;

use vars qw(@ISA @AUTO_ATTRIBUTES %AUTODB);
@ISA = qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(skey1 lkey1 nonkey);

%AUTODB=
  (-collection=>'Collection1',
   -keys=>q(skey1 string, lkey1 list(string))
  );
Class::AutoClass::declare(__PACKAGE__);

1;

package testAutoDB2;
use strict;
use Class::AutoClass;
use Class::AutoDB;

use vars qw(@ISA @AUTO_ATTRIBUTES %AUTODB);
@ISA = qw(Class::AutoClass);

@AUTO_ATTRIBUTES=qw(skey1 lkey1 nonkey);

%AUTODB=
  (-collection=>'Collection2',
   -keys=>q(skey1 string, lkey1 list(string))
  );
Class::AutoClass::declare(__PACKAGE__);

1;

