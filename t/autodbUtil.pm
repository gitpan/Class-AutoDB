package autodbUtil;
# use t::lib;
use strict;
use Carp;
use FindBin;
# sigh. Test::Deep exports reftype, blessed (and much more) so don't import from Scalar::Util
# use Scalar::Util qw(looks_like_number reftype blessed);
use Scalar::Util qw(looks_like_number);
use List::Util qw(min max);
use List::MoreUtils qw(uniq);
use Data::Rmap ();
use Storable qw(dclone);
use File::Basename qw(fileparse);
use File::Spec;
use Cwd qw(cwd);
use DBI;
use Fcntl;   # For O_RDWR, O_CREAT, etc.
use SDBM_File;
use Test::More;
# Test::Deep doesn't export cmp_details, deep_diag until recent version (0.104)
# so we import them "by hand"
use Test::Deep;
*cmp_details=\&Test::Deep::cmp_details;
*deep_diag=\&Test::Deep::deep_diag;
use TAP::Harness;
# use TAP::Formatter::Console; 
use TAP::Parser::Aggregator;
use Hash::AutoHash::Args;
use Exporter();

our @ISA=qw(Exporter);
our @EXPORT=qw(group groupmap 
	       create_autodb_table autodb dbh
	       tie_oid %oid %oid2id %id2oid %obj2oid %oid2obj
	       id id_restore id_next next_id
	       reach reach_fetch reach_mark
	       ok_dbtables _ok_dbtables ok_dbcolumns _ok_dbcolumns
	       ok_basetable ok_listtable ok_collection ok_collections
	       _ok_basetable _ok_listtable _ok_collection _ok_collections
	       ok_oldoid ok_oldoids ok_newoid ok_newoids
	       _ok_oldoid _ok_oldoids _ok_newoid _ok_newoids
	       cmp_thawed _cmp_thawed
	       remember_oids
	       test_single 
	       actual_tables actual_counts norm_counts actual_columns
	       report report_pass report_fail
	     );
# TODO: database name should be configurable
# CAUTION: $test_db and $SDBM_dir duplicated in Build.PL
our $test_db='test';
our $SDBM_dir=File::Spec->catdir(cwd(),qw(t SDBM));

# TODO: rewrite w/ Hash::AutoHash::MultiValued
# group a list by categories returned by sub.
# has to be declared before use, because of prototype
sub group (&@) {
  my($sub,@list)=@_;
  my %groups;
  for (@list) {
    my $group=&$sub($_);
    my $members=$groups{$group} || ($groups{$group}=[]);
    push(@$members,$_);
  }
  wantarray? %groups: \%groups;
}
# like group, but processes elements that are put on list. 
# sub should return 2 element list: 1st defines group, 2nd maps the value
# has to be declared before use, because of prototype
sub groupmap (&@) {
  my($sub,@list)=@_;
  my %groups;
  for (@list) {
    my($group,$value)=&$sub($_);
    my $members=$groups{$group} || ($groups{$group}=[]);
    push(@$members,$value);
  }
  wantarray? %groups: \%groups;
}

# used in serialize_ok tests. someday in Developer/Serialize tests
sub create_autodb_table {
  my $dbh=DBI->connect("dbi:mysql:database=test",undef,undef,
		       {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,})
    or return $DBI::errstr;
  $dbh->do(qq(DROP TABLE IF EXISTS _AutoDB)) or return $dbh->errstr;
  $dbh->do(qq(CREATE TABLE IF NOT EXISTS
                _AutoDB(oid BIGINT UNSIGNED NOT NULL,
                        object LONGBLOB,
                        PRIMARY KEY (oid))))
      or return $dbh->errstr;
  undef;
}
sub autodb {$Class::AutoDB::GLOBALS->autodb}
sub dbh {my $autodb=autodb; $autodb? $autodb->dbh: _dbh()}
our $MYSQL_dbh;
sub _dbh {
  $MYSQL_dbh or $MYSQL_dbh=DBI->connect
    ("dbi:mysql:database=$test_db",undef,undef,
     {AutoCommit=>1, ChopBlanks=>1, PrintError=>0, PrintWarn=>0, Warn=>0,});
}
# hashes below are exported.
# %oid,%oid2id,%id2oid are persistent and refer to db objects
# %obj2oid,%oid2obj are non-persistent and refer to in-memory objects
our(%oid,%oid2id,%id2oid,%obj2oid,%oid2obj);

our $SDBM_errstr;
sub _tie_sdbm (\%$;$) {		# eg, tie_sdbm(%oid,'oid','create')
  my($hash,$filebase,$create)=@_;
  return undef if !$create && tied %$hash; # short circuit if already tied
  my $file=File::Spec->catfile($SDBM_dir,$filebase);
  my $flags=$create? (O_TRUNC|O_CREAT|O_RDWR): O_RDWR;
  my $tie=tie(%$hash, 'SDBM_File', $file, $flags, 0666);
  $SDBM_errstr=$tie? undef:('Cannot '.($create? 'create': 'open')." SDBM file $file: $!");
}
sub tie_oid {
  my $create=shift;
  _tie_sdbm(%oid,'oid',$create) and confess $SDBM_errstr;
  _tie_sdbm(%oid2id,'oid2id',$create) and confess $SDBM_errstr;
  _tie_sdbm(%id2oid,'id2oid',$create) and confess $SDBM_errstr;
  undef;
}

our $ID;
use File::Spec::Functions qw(splitdir abs2rel);
sub init_id {
  $ID=0;
  for (splitdir(abs2rel($0))) {
    $ID=1000*$ID+(/\.(\d+)\./)[0];
  }
  $ID*=1000;
}
sub id {defined $ID? $ID: ($ID=init_id)}
sub id_restore {tie_oid(); $ID=1+max(keys %id2oid)}
sub id_next {my $id=id(); $ID++; $id} # like $id++
sub next_id {my $id=id(); ++$ID}	    # like ++$id

# return objects reachable from one or more starting points.
# adapted from Data::Rmap docs
sub reach {
  my @reach=uniq(Data::Rmap::rmap_ref {Scalar::Util::blessed($_) ? $_ : ();} @_);
  wantarray? @reach: \@reach;
}
# fetch objects reachable from one or more starting points. 
# uses stringify ("$_") to do the work
# adapted from Data::Rmap docs
sub reach_fetch {
  my @reach=uniq(Data::Rmap::rmap_ref {"$_" if UNIVERSAL::isa($_,'Class::AutoDB::Oid'); $_;} @_);
  wantarray? @reach: \@reach;
}

# mark objects reachable from a starting point w/ traversal order. result contains no duplicates
# copies the structure and returns the copy, 
# since it modifies the objects it encounters -- that's the whole point!!
our $MARK;
sub reach_mark {
  my $start=[@_];
  my $copy=dclone($start);
  $MARK=0;
  _reach_mark($copy);
  wantarray? @$copy: $copy;
}
# sub reach_mark {
#   my $start=shift;
#   my $copy=dclone($start);
#   $MARK=0;
#   _reach_mark($copy);
#   $copy;
# }
sub _reach_mark {
  my $start=shift;
  Data::Rmap::rmap_ref 
      {
	if (Scalar::Util::blessed($_) && 'HASH' eq Scalar::Util::reftype($_)) {
	  $_->{__MARK__}=$MARK++ unless exists $_->{__MARK__};
	}
        return $_} $start;
}
# check tables that exist in database
sub ok_dbtables {
  my($tables,$label)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=_ok_dbtables($tables,$label,$file,$line);
  report_pass($ok,$label);
}
sub _ok_dbtables {
  my($correct,$label,$file,$line)=@_;
  my $actual=dbh->selectcol_arrayref(qq(SHOW TABLES)) || [];
  my($ok,$details)=cmp_details($actual,set(@$correct));
  report_fail($ok,$label,$file,$line,$details);
}
# check columns that exist in database. $table2columns is HASH of column=>[columns]
sub ok_dbcolumns {
  my($table2columns,$label)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=_ok_dbcolumns($table2columns,$label,$file,$line);
  report_pass($ok,$label);
}
sub _ok_dbcolumns {
  my($table2columns,$label,$file,$line)=@_;
  my($ok,$details);
  while(my($table,$correct)=each %$table2columns) {
    my $actual=actual_columns($table);
    my($ok,$details)=cmp_details($actual,set(@$correct));
    report_fail($ok,$label,$file,$line,$details) or return 0;
  }
  return 1;
}
# check object's row in base table
sub ok_basetable {
  my($object,$label,$table,@keys)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=_ok_basetable($object,$label,$table,$file,$line,@keys);
  report_pass($ok,$label);
}
sub _ok_basetable {
  my($object,$label,$table,$file,$line,@keys)=@_;
  my $oid=autodb->oid($object);
  my($actual,$correct);
  if (@keys) {
    my $keys=join(', ',@keys);
    # expect one row. result will be ARRAY of ARRAY of columns
    $actual=dbh->selectall_arrayref(qq(SELECT $keys FROM $table WHERE oid=$oid));
    # remember to convert objects to oid in $correct
    #  my $correct=[[$object->get(@keys)]];
    # my $correct=[[map {ref($_) && UNIVERSAL::isa($_,'Class::AutoDB::Object')? autodb->oid($_): $_}
    $correct=[[map {autodb->oid($_) || $_} $object->get(@keys)]];
  } else {			# empty collection, so just make sure oid is present
    ($actual)=dbh->selectrow_array(qq(SELECT COUNT(oid) FROM $table WHERE oid=$oid));
    $correct=1;
  }
  my($ok,$details)=cmp_details($actual,$correct);
  report_fail($ok,$label,$file,$line,$details);
}
# check object's rows in list table
sub ok_listtable {
  my($object,$label,$basetable,$listkey)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=_ok_listtable($object,$label,$basetable,$file,$line,$listkey);
  report_pass($ok,$label);
}
sub _ok_listtable {
  my($object,$label,$basetable,$file,$line,$listkey)=@_;
  my $oid=autodb->oid($object);
  my $table=$basetable.'_'.$listkey;
  # expect 0 or more rows. result will be ARRAY of values
  my $actual=dbh->selectcol_arrayref(qq(SELECT $listkey FROM $table WHERE oid=$oid));
  # remember NOT to convert non-objects to oids in @correct
  # my @correct=map {autodb->oid($_)} @{$object->$listkey};
  # my @correct=map {ref($_) && UNIVERSAL::isa($_,'Class::AutoDB::Object')? autodb->oid($_): $_}
  my @correct=map {autodb->oid($_) || $_} @{$object->$listkey || []};
  my($ok,$details)=cmp_details($actual,bag(@correct));
  report_fail($ok,$label,$file,$line,$details);
}

# check object in collection
sub ok_collection {
  my($object,$label,$base,$basekeys,$listkeys)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=_ok_collection($object,$label,$base,$basekeys,$listkeys,$file,$line);
  report_pass($ok,$label);
}
# check multiple objects in multiple collections
# $colls is HASH of collection=>[[basekeys],[listkeys]]
sub ok_collections {
  my($objects,$label,$colls)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=1;
  for(my $i=0; $i<@$objects; $i++) {
    my $object=$objects->[$i];
    while(my($coll,$keylists)=each %$colls) {
      my($basekeys,$listkeys)=@$keylists;
      $ok&&=_ok_collection($object,"$label: object $i $coll",
			   $coll,$basekeys,$listkeys,$file,$line);
    }
  }
  report_pass($ok,$label);
}
sub _ok_collection {
  my($object,$label,$base,$basekeys,$listkeys,$file,$line)=@_;
  _ok_basetable($object,"$label: base table",$base,$file,$line,@$basekeys) or return 0;
  for my $listkey (@$listkeys) {
    _ok_listtable($object,"$label: $listkey list table",$base,$file,$line,$listkey) or return 0;
  }
  1;
}

# check that object's oid looks okay and is old
# @tables no longer used since loop that checks oids vs. tables commented out
sub ok_oldoid {
  my($object,$label,@tables)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=_ok_oldoid($object,$label,$file,$line,@tables);
  report_pass($ok,$label);
}
# check that objects' oids look okay and are old
# @tables no longer used since loop that checks oids vs. tables commented out
sub ok_oldoids {
  my($objects,$label,@tables)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=1;
  for(my $i=0; $i<@$objects; $i++) {
    $ok&&=_ok_oldoid($objects->[$i],"$label object $i",$file,$line,@tables);
  }
  report_pass($ok,$label);
}
# @tables no longer used since loop that checks oids vs. tables commented out
sub _ok_oldoid {
  my($object,$label,$file,$line,@tables)=@_;
  tie_oid;
  my $oid=autodb->oid($object);
  report_fail($oid>1,"$label: oid looks good",$file,$line) or return 0;
  # first check in-memory state
  report_fail(exists $oid2obj{$oid}? $oid2obj{$oid}==$object: 1,
	      "$label: oid-to-object unique",$file,$line) or return 0;
  report_fail(exists $obj2oid{$object}? $obj2oid{$object}==$oid: 1,
	      "$label: object-to-oid unique",$file,$line) or return 0;
  # update in-memory state
  $oid2obj{$oid}=$object;
  $obj2oid{$object}=$oid;
  # then check against database
  report_fail($oid{$oid},"$label: in oid SDBM file",$file,$line) or return 0;
  if (UNIVERSAL::can($object,'id')) {
    my $id=$object->id;
    report_fail($oid2id{$oid}==$id,"$label: in oid2id SDBM file",$file,$line) or return 0;
    report_fail($id2oid{$id}==$oid,"$label: in id2oid SDBM file",$file,$line) or return 0;
  }
  # this loop fails when object has list keys, but some lists are empty
  # redundant with ok_collection anyway. just keep check against _AutoDB
  #   push(@tables,'_AutoDB') unless grep {$_ eq '_AutoDB'} @tables;
  #   for my $table (@tables) {
  #     my($count)=dbh->selectrow_array(qq(SELECT COUNT(oid) FROM $table WHERE oid=$oid));
  #     report_fail($count>=1,"$label: in $table table",$file,$line) or return 0;
  #   }
  my($count)=dbh->selectrow_array(qq(SELECT COUNT(oid) FROM _AutoDB WHERE oid=$oid));
  report_fail($count==1,"$label: $oid has count $count in _AutoDB table",$file,$line) or return 0;
}

# check that object's oid looks okay and is new
sub ok_newoid {
  my($object,$label,@tables)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=_ok_newoid($object,$label,$file,$line,@tables);
  report_pass($ok,$label);
}
# check that objects' oids look okay and are new
sub ok_newoids {
  my($objects,$label,@tables)=@_;
  my($package,$file,$line)=caller; # for fails
  my $ok=1;
  for(my $i=0; $i<@$objects; $i++) {
    $ok&&=_ok_newoid($objects->[$i],"$label object $i",$file,$line,@tables);
  }
  report_pass($ok,$label);
}
sub _ok_newoid {
  my($object,$label,$file,$line,@tables)=@_;
  tie_oid;
  my $oid=autodb->oid($object);
  report_fail($oid>1,"$label: oid looks good",$file,$line) or return 0;
  # first check in-memory state
  report_fail(exists $oid2obj{$oid}? $oid2obj{$oid}==$object: 1,
	      "$label: oid-to-object unique",$file,$line) or return 0;
  report_fail(exists $obj2oid{$object}? $obj2oid{$object}==$oid: 1,
	      "$label: object-to-oid unique",$file,$line) or return 0;
  # update in-memory state
  $oid2obj{$oid}=$object;
  $obj2oid{$object}=$oid;
  # then check against database
  report_fail(!$oid{$oid},"$label: not in SDBM file",$file,$line) or return 0;
  if (UNIVERSAL::can($object,'id')) {
    my $id=$object->id;
    report_fail(!$oid2id{$oid},"$label: in oid2id SDBM file",$file,$line) or return 0;
    # line below generates spurious errors when tests rerun
    # report_fail(!$id2oid{$id},"$label: in id2oid SDBM file",$file,$line) or return 0;
  }
  push(@tables,'_AutoDB') unless grep {$_ eq '_AutoDB'} @tables;
  for my $table (@tables) {
    my($count)=dbh->selectrow_array(qq(SELECT COUNT(oid) FROM $table WHERE oid=$oid));
    report_fail(!$count,"$label: not in $table table",$file,$line) or return 0;
  }
  1;
}
# TODO: use is all thawed tests!
# $actual_objects. array of lots of object. 
# $correct_thawed. subset of $actual_objects expected to be thawed
sub cmp_thawed {
  my($actual_objects,$correct_thawed,$label)=@_;
 my($package,$file,$line)=caller; # for fails
  my $ok=_cmp_thawed($actual_objects,$correct_thawed,$label,$file,$line);
  report_pass($ok,$label);
}
sub _cmp_thawed {
  my($actual_objects,$correct_thawed,$label,$file,$line)=@_;
  my @actual_thawed=grep {'Class::AutoDB::Oid' ne ref $_} @$actual_objects;
  # unthawed objects are fragile and esily thawed. do the cmp this way to avoid thawing
  my @actual_refs=
    uniq map {ref($_).'='.Scalar::Util::reftype($_).sprintf('(%0x)',Scalar::Util::refaddr($_))}
      @actual_thawed;
  my @correct_refs=
    uniq map {ref($_).'='.Scalar::Util::reftype($_).sprintf('(%0x)',Scalar::Util::refaddr($_))}
      @$correct_thawed;
  @actual_refs=sort @actual_refs;
  @correct_refs=sort @correct_refs;
  
  my($ok,$details)=cmp_details(\@actual_refs,\@correct_refs);
  report_fail($ok,$label,$file,$line,$details);
}
# remember a list of oids for later tests
sub remember_oids {
  tie_oid;
  my @oids=grep {$_>1} map {autodb->oid($_)} @_; # only remember good looking oids
  @oid{@oids}=@oids;
  # get id-able oids and corresponding ids
  my @oids=grep {$_>1} map {autodb->oid($_)} grep {UNIVERSAL::can($_,'id')} @_;
  my @ids=map {autodb->oid($_)>1? $_->id: ()} grep {UNIVERSAL::can($_,'id')} @_;
  @oid2id{@oids}=@ids;
  @id2oid{@ids}=@oids;
}
# return those tables (from a given list) that are actually in database
sub actual_tables {
  my @correct=@_;
  my $tables=dbh->selectcol_arrayref(qq(SHOW TABLES));
  my @actual;
  for my $table (@$tables) {
    push(@actual,$table) if grep {$table eq $_} @correct;
  }
  @actual;
}
# return hash of counts for given list of tables
sub actual_counts {
  my @tables=@_;
  my %counts;
  for my $table (@tables) {
    my($count)=dbh->selectrow_array(qq(SELECT COUNT(oid) FROM $table));
    $counts{$table}=$count||0; # convert undef to 0 (usually nonexistent table)
  }
  wantarray? %counts: \%counts;
}
# remove elements with non-true counts
sub norm_counts {
  my %counts=(@_==1 && ref $_[0])? %{$_[0]}: @_;
  map {$counts{$_} or delete $counts{$_}} keys %counts;
  wantarray? %counts: \%counts;
}
# return columns that are actually in a database table
sub actual_columns {
  my($table)=@_;
  my $columns=dbh->selectcol_arrayref(qq(SHOW COLUMNS FROM $table)) || [];
  wantarray? @$columns: $columns;
}
# test one object. presently used in autodb.099.docs/docs.03x series
require autodbTestObject;	# 'require' instead of 'use' to avoid circular 'uses'
our $TEST_OBJECT;
sub test_single {
  my($class,@colls)=@_;
  @colls or @colls=qw(Person);
  my %all_coll2basekeys=(Person=>[qw(name sex id)],PersonStrings=>[qw(name sex id)],
			 HasName=>[qw(name)]);
  my %coll2basekeys=map {$_=>$all_coll2basekeys{$_}} @colls;
#   my $new_args=
#     sub {my($test)=@_; name=>$test->class,sex=>($main::ID%2? 'M': 'F'),id=>$main::ID++};
  my $new_args=
    sub {my($test)=@_; name=>$test->class,sex=>(id()%2? 'M': 'F'),id=>id_next()};
  my $test_object=$TEST_OBJECT || 
    ($TEST_OBJECT=new autodbTestObject
     (new_args=>$new_args,correct_diffs=>1,
      label=>sub {my $test=shift; my $obj=$test->current_object; $obj && $obj->name;},
     ));
  $test_object->test_put(class=>$class,correct_colls=>\@colls,coll2basekeys=>\%coll2basekeys);
  $test_object->last_object;
}

sub report {
  my($ok,$label,$file,$line,$details)=@_;
  pass($label), return if $ok;
  fail($label);
  diag("from $file line $line") if defined $file;
  if (defined $details) {
    diag(deep_diag($details)) if ref $details;
    diag($details) unless ref $details;
  }
  return 0;
}

sub report_pass {
  my($ok,$label)=@_;
  pass($label) if $ok;
  $ok;
}
sub report_fail {
  my($ok,$label,$file,$line,$details)=@_;
  return 1 if $ok;
  fail($label);
  diag("from $file line $line") if defined $file;
  if (defined $details) {
    diag(deep_diag($details)) if ref $details;
    diag($details) unless ref $details;
  }
  return 0;
}
1;
