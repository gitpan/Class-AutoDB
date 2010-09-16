package Class::AutoDB::OidDeleted;
use Carp;
use base qw(Class::AutoDB::Oid);

# oid, put defined in Oid. 
#   'oid' is fine as is -- just returns _OID from hash 
#   'put' is fine as is -- nop 
# NG 10-09-09: decided to remove these methods to avoid polluting namespace further
# #   override 'is_extant' to always say 'no' & 'is_deleted' the opposite
# #   override 'put' to confess
# #   override 'del' to nop -- seems the right semantics because application might traverse a
# #      stucture deleting sub-objects as it goes; should be okay to hit same sub-object twice 
# sub del {0}
# sub is_extant {0}
# sub is_deleted {1}

# NG 10-09-09: changed my mind about 'put'. made it nop
# sub put {
#   my $self=shift;
#   local $AUTOLOAD='put';
#   $self->AUTOLOAD(@_);
# }

# AUTOLOAD always confesses, since it is impossible to access deleted object
use vars qw($AUTOLOAD);
sub AUTOLOAD {
  my $self=shift;
  my $method=$AUTOLOAD;
  $method=~s/^.*:://;             # strip class qualification
  return if $method eq 'DESTROY'; # the books say you should do this
  my $oid=$self->{_OID};
  my $class=$self->{_CLASS} || '(unknown)';
  confess "Trying to access deleted object of class $class via method $method (oid=$oid)";
}

####################
# stringify to empty string, just like undef would
sub stringify {''}

# # Code below adapted from Graph v0.67
# NG 10-09-11: removed eq, ne. Perl autogenerates from stringify
# sub eq {"$_[0]" eq "$_[1]"}
# sub ne {"$_[0]" ne "$_[1]"}
use overload
  '""' => \&stringify,
  'bool'=>sub {undef},
  # 'eq' => \&eq,
  # 'ne' => \&ne,
  fallback => 'TRUE';
####################
1;
