# NOTE - DO NOT USE Class::C3 directly as a user, use MRO::Compat instead!
package A;
use Class::C3;
sub hello { 'A::hello' }

package B;
use base 'A';
use Class::C3;

package C;
use base 'A';
use Class::C3;
sub hello { 'C::hello' }

package D;
use base ('B', 'C');
use Class::C3;

# Classic Diamond MI pattern
#    <A>
#   /   \
# <B>   <C>
#   \   /
#    <D>

package main;

# initializez the C3 module
# (formerly called in INIT)
Class::C3::initialize();

print join ', ' => Class::C3::calculateMRO('Diamond_D'); # prints D, B, C, A

print D->hello(); # prints 'C::hello' instead of the standard p5 'A::hello'

D->can('hello')->();          # can() also works correctly
UNIVERSAL::can('D', 'hello'); # as does UNIVERSAL::can()
