#DB2_TableName,DB2_FieldName,DB2_DataType,ColLen,Scale,Nulls
#T_VLAN	VLAN_ID	BIGINT	8	0	No
#T_VLAN	NAME	VARCHAR	64	0	No

DB2_TableName,DB2_FieldName,DB2_DataType,ColLen,Scale,Nulls
T_ARP_CACHE,HOST_ID,BIGINT,8,0,No
T_ARP_CACHE,MAC_ADDRESS,VARCHAR,20,0,No
T_ARP_CACHE,IP_ADDRESS,VARCHAR,40,0,Yes
T_ARP_CACHE,TYPE,VARCHAR,8,0,Yes
T_ARP_CACHE,RECORD_SCAN_TIME,TIMESTAMP,10,6,No
T_ARP_CACHE,RECORD_CHANGE_TIME,TIMESTAMP,10,6,No
T_ARP_CACHE,RECORD_INSERT_TIME,TIMESTAMP,10,6,No
T_BANDWIDTH_SAMPLE,SITE_CODE,VARCHAR,4,0,No
T_BANDWIDTH_SAMPLE,IP_ADDRESS,VARCHAR,40,0,No
T_BANDWIDTH_SAMPLE,DOWNLOAD_BPS,INTEGER,4,0,No
T_BANDWIDTH_SAMPLE,UPLOAD_BPS,INTEGER,4,0,No
T_BANDWIDTH_SAMPLE,ROUND_TRIP_TIME_MSEC,REAL,4,0,No
T_BANDWIDTH_SAMPLE,COUNT,INTEGER,4,0,No
T_BANDWIDTH_SAMPLE,RECORD_INSERT_TIME,TIMESTAMP,10,6,No
T_BANDWIDTH_SAMPLE,RECORD_CHANGE_TIME,TIMESTAMP,10,6,Yes



$destination_schema = "design"
$db2_csv = Import-Csv -Path .\DB2_Inventory_Database.csv

$tables = $db2_csv | Select DB2_TableName -Unique

foreach($table in $tables){
	#Write-Output "Make Table DDL for $table.DB2_TableName"
	$db2_csv | Where-Object{$_.DB2_TableName -eq $table.DB2_TableName} | Select DB2_TableName -Last 1
	#$table_name = 
	Write-Output "Make Table DDL for $table_Name"
}

exit
foreach($table in $tables){
    $db2_csv | Where-Object{$_.DB2_TableName -eq $table.DB2_TableName} | Select DB2_TableName -Last 1
	$table_name = $db2_csv | Where-Object{$_.DB2_TableName -eq $table.DB2_TableName} | Select DB2_TableName -Last 1
	$fields = $db2_csv | Where-Object($_.DB2_TableName -eq $table.DB2_TableName) | Select DB2_FieldName,DB2_DataType,ColLen,Scale,Nulls
	#$table_name = $table.$DB2_TableName
	Write-Output "Make Table DDL for $table_name"
	#| Write-Output '<- Table DDL For'
	Write-Output "CREATE TABLE $destination_shema.$table_name;"
	foreach($field in $fields){
		Write-Output "DB2_FieldName"
	}
}

#group DB2_TableName | foreach {$_.group -select -last 1}

#CREATE [ [ GLOBAL | LOCAL ] { TEMPORARY | TEMP } | UNLOGGED ] TABLE [ IF NOT EXISTS ] table_name ( [
#  { column_name data_type [ COLLATE collation ] [ column_constraint [ ... ] ]
#    | table_constraint
#    | LIKE parent_table [ like_option ... ] }
#    [, ... ]
#] )
#[ INHERITS ( parent_table [, ... ] ) ]
#[ WITH ( storage_parameter [= value] [, ... ] ) | WITH OIDS | WITHOUT OIDS ]
#[ ON COMMIT { PRESERVE ROWS | DELETE ROWS | DROP } ]
#[ TABLESPACE tablespace ]

