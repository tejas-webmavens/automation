<?php
ini_set("display_errors", "on");
error_reporting(E_ALL & ~E_NOTICE);

date_default_timezone_set('America/Chicago');

if($_SERVER['SERVER_NAME'] == "") {
	$triggerin_db_host="127.0.0.1";
	$triggerin_db_user="root";
	$triggerin_db_pass="";
	$triggerin_db_name="";
} else {
	$triggerin_db_host="";
	$triggerin_db_user="";
	$triggerin_db_pass="";
	$triggerin_db_name="";
}

$user_app='';

/*set tables with log changes in this array */
$dont_log_changes_tables=array();

$dblog = $triggerin_db_name."_log";
$table_log_changes =  "log_changes";


$con = mysqli_connect($triggerin_db_host, $triggerin_db_user, $triggerin_db_pass) or die (mysql_error());
mysqli_select_db($con,$triggerin_db_name) or die (mysql_error());