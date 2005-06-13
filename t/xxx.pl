use strict;

for my $src (@ARGV) {
  my $dst=$src;
  $dst=~s/01/02/;
  open(SRC,"< $src") || die "Cannot open input file $src: $!";
  open(TMP,"> xxx") || die "Cannot open temp output file xxx; $!";
  while(<SRC>) {
    s/use testAutoDB01;/use testAutoDB02;/;
    print TMP;
  }
  my $cmd="cp xxx $dst";
  print "$cmd\n";
  system($cmd);
}
