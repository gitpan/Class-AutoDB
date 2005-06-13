package testRegistryTop;
use strict;
use Class::AutoClass;
our @ISA = qw(Class::AutoClass Class::AutoDB::Object);
Class::AutoClass::declare(__PACKAGE__);
1;

package testRegistryLeft;
use strict;
our @ISA = qw(testRegistryTop);
Class::AutoClass::declare(__PACKAGE__);
1;

package testRegistryRight;
use strict;
our @ISA = qw(testRegistryTop);
Class::AutoClass::declare(__PACKAGE__);
1;

package testRegistryBottom;
use strict;
our @ISA = qw(testRegistryLeft testRegistryRight);
Class::AutoClass::declare(__PACKAGE__);
1;
