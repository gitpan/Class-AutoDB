## this is a database utility class that provides a common connection api
## for all the tests.

package DBConnector;
use strict;
use vars qw($noConnectionFile $DB_SERVER $DB_DATABASE $DB_USER $DB_PASS $DB_DRIVER $DB_NAME @ISA);
use DBI;
use Class::AutoClass;
@ISA = qw(Class::AutoClass);


###############################################################################
# _mark_noconnect
#
# writes a file named ".noDBConnnection" in this directory so that both
# testing class and instance methods can find out if we have a DB connection
###############################################################################
sub _mark_noconnect {
  $noConnectionFile = "__noDBConnection";
  open(FILE,">./$noConnectionFile");
}

###############################################################################
# can_connect
#
# Returns true if there is an active db handle, false otherwise
###############################################################################

sub can_connect {
  my $connected=0;
  open(FILE,"$noConnectionFile") or $connected=1;
  return $connected;
}


###############################################################################
# DBI Connection Variables
###############################################################################
$DB_DRIVER	= "DBI:mysql:server=$DB_SERVER;database=$DB_DATABASE";	

BEGIN{
  $DB_NAME      = 'mysql';
  $DB_SERVER    = 'localhost';
  $DB_DATABASE  = 'AutoMagic__testSuite';
  $DB_USER      = 'root';
  $DB_PASS      = '';

  # Connect to DB without a database name to create the database
  my $DB_DRIVER = "DBI:mysql:server=$DB_SERVER:database=";
  my $dbh = DBI->connect("$DB_DRIVER", "$DB_USER", "$DB_PASS") || _mark_noconnect();
  if(&can_connect){
    $dbh->do("create database $DB_DATABASE");
    $dbh->disconnect();
  }
}


###############################################################################
# Constructor
###############################################################################
sub _init_self {
  my $self = shift;
  return $self->_dbConnect;
}

###############################################################################
# _createDB
#
# Create the DB table, if it doesn't already exist
###############################################################################
sub _createDB {
  my $DB_DRIVER = "DBI:mysql:server=$DB_SERVER;database=";
  my $dbh = DBI->connect("$DB_DRIVER", "$DB_USER", "$DB_PASS")
    or die "$DBI::errstr : perhaps you should alter $0's connection parameters";
  $dbh->do("create database $DB_DATABASE");
  $dbh->disconnect();
}

###############################################################################
# db Connect
#
# Perform the actual database connection open call via DBI.
###############################################################################
sub _dbConnect {
	my $self=shift;
	if(&can_connect){
    $self->{dbh} = DBI->connect("$DB_DRIVER", "$DB_USER", "$DB_PASS")
      or die "$DBI::errstr : perhaps you should alter $0's connection parameters";
	}
}

###############################################################################
# get DB Handle
#
# Returns the current database connection handle to be used by any query.
# If the database handle doesn't yet exist, dbConnect() is called to create
# one.
###############################################################################
sub getDBHandle {
    my $self = shift;
    $self->{dbh} = _dbConnect() unless $self->can_connect();
    return $self->{dbh};
}


###############################################################################
# get DB Server
#
# Return the servername of the database
###############################################################################
sub getDBServer {
    $DB_SERVER;
}

###############################################################################
# get DB Driver
#
# Return the driver name (DSN string) of the database connection.
###############################################################################
sub getDBDriver {
    $DB_DRIVER;
}

###############################################################################
# get DB Database
#
# Return the database name of the connection.
###############################################################################
sub getDBDatabase {
    $DB_DATABASE;
}

###############################################################################
# get DB User
#
# Return the username used to open the connection to the database.
###############################################################################
sub getDBUser {
    $DB_USER;
}


END  {
	   if(&can_connect){
         my $dbh = DBI->connect("$DB_DRIVER", "$DB_USER", "$DB_PASS")
	       or die "$DBI::errstr : perhaps you should alter $0's connection parameters";
         $dbh->do("drop database $DB_DATABASE");
         $dbh->disconnect();
	   }
	   else{ 	   	  
	   	     unlink $noConnectionFile;
	   }
     }
     

1;
