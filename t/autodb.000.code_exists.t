#!perl
use strict;
use Test::More tests =>17;
use DBI;
# make sure all the necesary modules exist
BEGIN {
    use_ok( 'Class::AutoDB' );
    use_ok('Class::AutoDB::BaseTable');
    use_ok('Class::AutoDB::Collection');
    use_ok('Class::AutoDB::CollectionDiff');
    use_ok('Class::AutoDB::Connect');
    use_ok('Class::AutoDB::Cursor');
    use_ok('Class::AutoDB::Database');
    use_ok('Class::AutoDB::Globals');
    use_ok('Class::AutoDB::ListTable');
    use_ok('Class::AutoDB::Object');
    use_ok('Class::AutoDB::Oid');
    use_ok('Class::AutoDB::Registration');
    use_ok('Class::AutoDB::Registry');
    use_ok('Class::AutoDB::RegistryDiff');
    use_ok('Class::AutoDB::RegistryVersion');
    use_ok('Class::AutoDB::Serialize');
    use_ok('Class::AutoDB::Table');
}
my $dbh=DBI->connect("dbi:mysql:",undef,undef,
		     {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,});
my($mysql)=$dbh->selectrow_array(qq(SELECT VERSION()));
diag( "Testing Class::AutoDB $Class::AutoDB::VERSION, Perl $], $^X, MySQL $mysql" );

done_testing();
