package testAutoDBTop;
use strict;
use Class::AutoClass;
use vars qw(@ISA @AUTO_ATTRIBUTES %AUTODB);
@ISA = qw(Class::AutoClass);
@AUTO_ATTRIBUTES=qw(top_key);
%AUTODB=(-collection=>'CollectionTop',-keys=>'top_key string');
Class::AutoClass::declare(__PACKAGE__);
1;

package testAutoDBLeft;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES %AUTODB);
@ISA = qw(testAutoDBTop);
@AUTO_ATTRIBUTES=qw(left_key);
%AUTODB=(-collection=>'CollectionLeft',-keys=>'left_key string');
Class::AutoClass::declare(__PACKAGE__);
1;

package testAutoDBRight;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES %AUTODB);
@ISA = qw(testAutoDBTop);
@AUTO_ATTRIBUTES=qw(right_key);
%AUTODB=(-collection=>'CollectionRight',-keys=>'right_key string');
Class::AutoClass::declare(__PACKAGE__);
1;

package testAutoDBBottom;
use strict;
use vars qw(@ISA @AUTO_ATTRIBUTES %AUTODB);
@ISA = qw(testAutoDBLeft testAutoDBRight);
@AUTO_ATTRIBUTES=qw(bottom_key);
%AUTODB=(-collection=>'CollectionBottom',-keys=>'bottom_key string');
Class::AutoClass::declare(__PACKAGE__);
1;
