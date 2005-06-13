package testRegistry;
use strict;
use Class::AutoClass;
our @ISA = qw(Class::AutoClass Class::AutoDB::Object);
Class::AutoClass::declare(__PACKAGE__);
1;

package testRegistry1;
use strict;
use Class::AutoClass;
our @ISA = qw(Class::AutoClass Class::AutoDB::Object);
Class::AutoClass::declare(__PACKAGE__);
1;

package testRegistry2;
use strict;
use Class::AutoClass;
our @ISA = qw(Class::AutoClass Class::AutoDB::Object);
Class::AutoClass::declare(__PACKAGE__);
1;

