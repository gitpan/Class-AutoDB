use t::lib;
use strict;
use autodbRunTests;

# Regression test: put large complex graph. breaks Dumper 2.121
# I don't know why this particular structure is problematic. not just size...
#   big arrays or hashes don't break it
#   ternary trees with depth <= 3 don't break it
#   in this test, binary trees with depth <= 5 don't break it

runtests_main();
