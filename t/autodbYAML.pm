# only used in Developer tests. not included in build_requires
package autodbYAML;
use t::lib;
use YAML;
use strict;
use Exporter();
our @ISA=qw(Exporter);
our @EXPORT=qw(Dump);

# wrapper for YAML::Dump that shuts up 'deep recursion' warnings and errors
# warnings are generated by Perl itself, not YAML.
# when run under the debugger, fatal errors generated by debugger.
# 
# to catch the warnings, we set $SIG{__WARN__} to a subroutine that eats the warninig 
#   if it's 'deep recursion', and re-warns otherwise.
# to stop the debugger errors, we set $DB::deep to 0, which turns off recursion checking

sub Dump {
  local $SIG{__WARN__}=sub {warn @_ unless $_[0]=~/^Deep recursion/;};
  local $DB::deep=0;
  YAML::Dump(@_);
}
1;
