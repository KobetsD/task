#!/usr/bin/perl -w
use Data::Dumper;
use strict;

use SDB::mysql_object ;
use SDB::mysql;
### Constants
use proci::_config qw( 
	$DB
	$HOST
	$PASSWORD
	$USER
	$TEMPLATE_DIR 

	$USER_Samba
	$WORKGROUP_Samba
	$PASSWORD_Samba01
	$PASSWORD_Samba02
	@HOSTS_Samba02
	
	$TASKS_TABLE
	$PROCS_TABLE
	$STATISTICS_TABLE
);

use proci::db qw( 
	BeginTransaction 
	CommitTransaction 
	GetCachedTableRecordsByKeys 
	my_quotemeta 
);

### Flags
my $DEBUG = 0;
my $SQL_DEBUG = 0;

### Connect to DB proci (use SDB::mysql_object)
my $mysql_proci = new SDB::mysql_object(
	host => $HOST,
	db => $DB,
	user => $USER,
	password => $PASSWORD,
	sql_debug => $SQL_DEBUG,
);
dbi_connect( "$DB:$HOST", $USER, $PASSWORD );
# ---------- $ProcInTasksRecords ------------
my @task_option_list;

push @task_option_list, {text => 'Любая задача', value => 'All tasks' };
 
#select task_option_list
my $records_href = $mysql_proci->GetCachedTableRecordsByKeys( table => $TASKS_TABLE, keys => ['task_id'], where => "", refresh => 1 );

print Dumper($records_href);
# -------------------------------------------