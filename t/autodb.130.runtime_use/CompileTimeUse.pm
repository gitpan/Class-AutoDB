# Regression test: runtime use
# all classes use the same collection. 
# the 'put' test stores objects of different classes in the collection 
# the 'get' test gets objects from the collection w/o first using their classes
#   some cases should be okay; others should fail 
# 
# this class is used at compile-time, as usual. it's used to fire off the 'get'

package CompileTimeUse;
use base qw(Class::AutoClass);
use vars qw(@AUTO_ATTRIBUTES %AUTODB);
@AUTO_ATTRIBUTES=qw(id name);
%AUTODB=
  (collection=>'HasName',keys=>qq(id integer, name string));
Class::AutoClass::declare;

1;
