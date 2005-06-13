drop table if exists _AutoDB;
create table _AutoDB (
  oid bigint unsigned not null,
  object longblob,
  primary key (oid)
);

