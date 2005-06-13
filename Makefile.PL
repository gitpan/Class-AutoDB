use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'    => 'Class::AutoDB',
    'VERSION_FROM'  => 'lib/Class/AutoDB.pm', # finds $VERSION
    'PREREQ_PM'    => { Class::AutoClass => '0.09', 
                       Class::WeakSingleton => '1.03',
                       Class::Singleton => '0',
                       IO::Scalar => '2.104',
                       DBD::mysql => '2.9002',
                       Storable => '2.06',
                       Test::More => '0.45',
                       Error => '0.15',
                       Data::Dumper => '2.12',
                       Text::Abbrev => '0',
                       Test::Deep => '0',
                       YAML => '0',
                       Set::Scalar => '0',
                      }, 
);


package MY; # so that "SUPER" works right

sub test_via_harness {
 my $inherited = shift->SUPER::test_via_harness(@_);
 return undef; # handle tests in test.pl
}
