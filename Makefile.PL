use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'		=> 'Class::AutoDB',
    'VERSION_FROM'	=> 'lib/Class/AutoDB.pm', # finds $VERSION
    'PREREQ_PM'		=> { Class::AutoClass => '0.06', 
                             Class::WeakSingleton => '1.03',
			     IO::Scalar => '2.104',
			     DBD::mysql => '2.9002',
			     Storable => '2.06',
			     Test::More => '0.45',
                           }, 
);
