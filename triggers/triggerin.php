<?php
ini_set('max_execution_time','0');
ini_set('memory_limit', '-1');
error_reporting(E_ALL & ~E_NOTICE & ~E_DEPRECATED & ~E_STRICT);

function add_audit_sql($source, $event, $table) {
	if(strpos($table,"deleted_")!==false) { return str_replace("/*audit_sql*/", "", $source); }
	
	if(trim($event)=="BEFORE UPDATE") {
		$code = "
		
IF (SELECT @app_username IS NULL) THEN
	/*SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot update';*/
	SET @app_username='PHPMyAdmin Test/Debug';
	SET @app_user_ip='N';
END IF;

IF NEW.audit_updated_by NOT LIKE '%trigger' AND @dont_update_audit_username IS NULL THEN
	SET NEW.audit_updated_by=@app_username;
END IF;
SET NEW.audit_ip=@app_user_ip;
IF NOT @dont_save_update_time THEN
	SET NEW.audit_updated_date=CURRENT_TIMESTAMP();
END IF;";
		
		$code = str_replace("/*audit_sql*/", $code, $source)."

IF @dont_update_audit_username IS NULL THEN
	SET NEW.audit_updated_by=@app_username;
END IF;

";
		
		return $code;
		
	} elseif(trim($event)=="BEFORE INSERT") {
		
		$code = "
		
IF (SELECT @app_username IS NULL) THEN
	/*SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot insert';*/
	SET @app_username='PHPMyAdmin Test/Debug';
	SET @app_user_ip='N';
END IF;
IF NEW.audit_created_by NOT LIKE '%trigger' THEN
	SET NEW.audit_created_by=@app_username;
END IF;
SET NEW.audit_ip=@app_user_ip;
SET NEW.audit_created_date=CURRENT_TIMESTAMP();

IF NOT @dont_save_update_time THEN
	SET NEW.audit_updated_date=CURRENT_TIMESTAMP();
END IF;";
		
		$code = str_replace("/*audit_sql*/", $code, $source)."
SET NEW.audit_created_by=@app_username;
";
		
		return $code;
		
	} elseif(trim($event)=="BEFORE DELETE") {
		$code = "
IF (SELECT @app_username IS NULL) THEN
	/*SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete';*/
	SET @app_username='PHPMyAdmin Test/Debug';
	SET @app_user_ip='N';
END IF;";
		
		return str_replace("/*audit_sql*/", $code, $source);
		
	}
	
	return $source;
}
function add_log_changes($event, $table,$dont_log_tables){
	global $dblog,$table_log_changes,$con;
	
	if($table=="items_serial_master") return "";
	
	if(in_array($table,$dont_log_tables)) {
		return "";
		
	}
	
	if(trim($event)=="AFTER UPDATE") {
		$res = mysqli_query($con,"DESCRIBE `$table`");
		$code="";
		while($row=mysqli_fetch_assoc($res)) {
			
			if($row['Field']!="id" && strpos($row['Field'],"audit_")===false){
				$code.= "
				IF IFNULL(NEW.{$row[Field]},'')<>'' THEN
					IF (OLD.{$row[Field]} <> NEW.{$row[Field]}) THEN 
						INSERT INTO {$dblog}.log_sql SET table_name='$table', field_name='{$row[Field]}',record_id=NEW.id, old_data=OLD.{$row[Field]}, new_data=NEW.{$row[Field]},operation='update',audit_created_date=CURRENT_TIMESTAMP(),audit_created_by=@app_username;
					END IF;
				END IF;
				";
			}
		}
		
	} elseif(trim($event)=="AFTER INSERT") {
		$res = mysqli_query($con,"DESCRIBE `$table`");
		$code="";
		while($row=mysqli_fetch_assoc($res)) {
			
			if($row['Field']!="id" && strpos($row['Field'],"audit_")===false){
				$code.= "
				IF (NEW.{$row[Field]}) THEN
					INSERT INTO {$dblog}.log_sql SET table_name='$table', field_name='{$row[Field]}',record_id=NEW.id, old_data='', new_data=NEW.{$row[Field]},operation='insert',audit_created_date=CURRENT_TIMESTAMP(),audit_created_by=@app_username;
				END IF;
				";
			}
		}
	} elseif(trim($event)=="AFTER DELETE") {
		$res = mysqli_query($con,"DESCRIBE `$table`");
		$code="";
		while($row=mysqli_fetch_assoc($res)) {
			
			if($row['Field']!="id" && strpos($row['Field'],"audit_")===false){
				$code.= "
				INSERT INTO {$dblog}.log_sql SET table_name='$table', field_name='{$row[Field]}',record_id=OLD.id, old_data=OLD.{$row[Field]}, new_data='',operation='delete',audit_created_date=CURRENT_TIMESTAMP(),audit_created_by=@app_username;
				
				";
			}
		}
	}
	
	return $code;
}

function add_clone_tables_code($event, $table,$dont_log_tables){
	global $dblog,$table_log_changes,$con;
		
//	$_tables = array("3_2rfq_items__qty", "5rfq_items_bom", "10messages");

	$_tables['3_2rfq_items__qty'][]="release_group";
	$_tables['5rfq_items_bom'][]="default_rev";
	$_tables['10messages'][]="no_of_responses_to_this_msg";


	if(!in_array($table,array_keys($_tables))) {
		return "";
	}
	
	/*
	$field_names = array();
	$res = mysqli_query($con,"DESCRIBE `$table`");
	while($row=mysqli_fetch_array($res)) {
		if($row["Field"]!="id") {
			$field_names[] = $row["Field"];
		}
	}
	*/

	if(in_array($table,$dont_log_tables)) {
		return "";
		
	}
	
	if(trim($event)=="AFTER UPDATE") {
		$res = mysqli_query($con,"DESCRIBE `$table`");
		$code="";
		while($row=mysqli_fetch_assoc($res)) {
			
			foreach ($_tables[$table] as $f){
				if($row['Field'] != $f){
					if($row['Field']!="id" && strpos($row['Field'],"audit_")===false){
						$code.= "
						IF IFNULL(NEW.{$row[Field]},'')<>'' THEN
							IF (OLD.{$row[Field]} <> NEW.{$row[Field]}) THEN 
								UPDATE {$table}_clone SET {$row[Field]} = NEW.{$row[Field]} WHERE id = NEW.id;
							END IF;
						END IF;
						";
					}
				}
			}

			
			
			
			
		}
		
	} elseif(trim($event)=="AFTER INSERT") {
		$res = mysqli_query($con,"DESCRIBE `$table`");
		while($row=mysqli_fetch_assoc($res)) {
			foreach ($_tables[$table] as $f){
				if($row['Field'] != $f){
				
					$fields .= $row['Field'].",";
					
				}
			}
		}
				$code.= "
					INSERT INTO {$table}_clone SELECT * FROM $table WHERE id = NEW.id;
				";

	} elseif(trim($event)=="AFTER DELETE") {
		$res = mysqli_query($con,"DESCRIBE `$table`");
		$code="";
		while($row=mysqli_fetch_assoc($res)) {
			
			if($row['Field']!="id" && strpos($row['Field'],"audit_")===false){
				$code.= "
				DELETE FROM {$table}_clone WHERE id = old.id;
				";
			}
		}
	}
	if(trim($event)=="AFTER UPDATE") {
	if($code <> ""){
		// debug echo $code;die;
	}
	}
	return $code;
}

function add_deleted_tables_code($source,$table) {
global $con;
	$_tables = array("orders_details", "orders_request", "invoice_details", "packingslip_details");
	
	if(in_array($table,$_tables)) {
		$field_names = array();
		$res = mysqli_query($con,"DESCRIBE `$table`");
		while($row=mysqli_fetch_array($res)) {
			if($row["Field"]!="id") {
				$field_names[] = $row["Field"];
			}
		}
		
		$code = "INSERT INTO deleted_$table (`".implode("`,`", $field_names)."`,`deleted_datetime`,`deleted_reason`,`deleted_comments`,`deleted_by`) VALUES (old.".implode(",old.", $field_names).",CURRENT_TIMESTAMP(),@deleted_reason,@deleted_comments,@app_username);\n";
		
		return str_replace("/*deleted_tables_sql*/", $code, $source);
	} else {
		return $source;
	}
		
}

function add_clone_tables_code_old($source,$table) {
global $con;
	$_tables = array("3_2rfq_items__qty");
	
	if(in_array($table,$_tables)) {
		$field_names = array();
		$res = mysqli_query($con,"DESCRIBE `$table`");
		while($row=mysqli_fetch_array($res)) {
			if($row["Field"]!="id") {
				$field_names[] = $row["Field"];
			}
		}
		
		$code = "INSERT INTO $table_clone (`".implode("`,`", $field_names)."`) VALUES (old.".implode(",old.", $field_names).");\n";
		
		return str_replace("/*clone_tables_sql*/", $code, $source);
	} else {
		return $source;
	}
		
}


function add_audit_fields_to_table($table){
	global $con;
	mysqli_query($con,"ALTER TABLE `".$table."` ADD `audit_created_by` VARCHAR(50)  NULL  DEFAULT NULL");
	mysqli_query($con,"ALTER TABLE `".$table."` ADD `audit_updated_by` VARCHAR(50)  NULL  DEFAULT NULL  AFTER `audit_created_by`");
	mysqli_query($con,"ALTER TABLE `".$table."` ADD `audit_created_date` TIMESTAMP  NULL  AFTER `audit_updated_by`");
	mysqli_query($con,"ALTER TABLE `".$table."` ADD `audit_updated_date` TIMESTAMP  NULL  AFTER `audit_created_date`");
	mysqli_query($con,"ALTER TABLE `".$table."` ADD `audit_ip` VARCHAR(50)  NULL  DEFAULT NULL  AFTER `audit_updated_date`");
	return true;
}

function has_audit_fields($table) {
global $con;
	$res = mysqli_query($con,"DESCRIBE `$table`") or die(mysql_error());
	while($row=mysqli_fetch_array($res)) {
		if(strpos($row[0],"audit_")!==false) {
			return true;
		}
	}
	return false;
}

file_put_contents("./triggerin.running",1);

$last_triggerin = file_get_contents("triggerin.last");

error_reporting(E_ALL & ~E_STRICT & ~E_DEPRECATED);

require("./triggerin.conf.php");

//added on june 15 to add audit columns to missing tables automatically
echo "Checking Audit fields...<br>";
$res_tables = mysqli_query($con,"SHOW FULL TABLES WHERE Table_Type = 'BASE TABLE'");
while($row_tables = mysqli_fetch_array($res_tables)) {
	if(!has_audit_fields($row_tables[0])) {
		add_audit_fields_to_table($row_tables[0]);
	}
}


if(($last_triggerin!=md5_file("triggerin.sql")) || $_GET["remote"] || $_GET["force"] || $argv[1]=="initialize" || $argv[1]=="force" || $argv[1]=="syncstock") {
	$_audited_tables=array();
	
	$triggers = array();
	$q="SHOW TRIGGERS FROM $triggerin_db_name";
	$res = mysqli_query($con,$q);
	while($r=mysqli_fetch_array($res)) {
		$triggers[] = $r["Trigger"];
	}
	
	echo "Dropping triggers...\n";
	foreach($triggers as $t) {
		$q="DROP TRIGGER IF EXISTS `$t`";
		mysqli_query($con,$q);
	}
	
	$_run_sync_sql=0;
	
	
	echo "Running trigger-free sql...\n";
	list($new_trigger_free_query,$old_trigger_free_query) = explode("// OLD QUERIES //", file_get_contents("triggerin.triggerfree".($argv[1]=="initialize"?"initialize":"").".sql"));
	if($new_trigger_free_query!="") {
		if($argv[1]=="initialize") {
			include("initializer.php");
		}
		
		preg_match_all('|-php-(.*)--php--|Us',$new_trigger_free_query,$php_code);
		foreach($php_code[1] as $p => $c) {
			$__start = microtime(1);
			$new_trigger_free_query = str_replace($php_code[0][$p],"/*php$p*/", $new_trigger_free_query);
			eval($c);
			$__end = microtime(1);
			echo "Script took ".($__end-$__start)." secs\n";
		}
		
		$sqls = explode(";",$new_trigger_free_query);
		foreach($sqls as $_idx => $sql) {
			if(trim($sql)=="") continue;
			
			try {
				$__start = microtime(1);
				mysqli_query($con,$sql) or die("<br>".$con->error);
				$__end = microtime(1);
				echo "Affected rows: ".mysqli_affected_rows($con)." in ".($__end-$__start)." secs\n";
			} catch(Exception $e) {
				echo $e->getMessage();
				exit;
			}
		}
		
		foreach($php_code[1] as $p => $c) {
			$new_trigger_free_query = str_replace("/*php$p*/",$php_code[0][$p], $new_trigger_free_query);
		}
		
		file_put_contents("triggerin.triggerfree".($argv[1]=="initialize"?"initialize":"").".sql", "// OLD QUERIES // \n\n".date("Y-m-d H:i:s")."\n".trim($new_trigger_free_query)."\n\n".trim($old_trigger_free_query));
	}
	
	echo "Creating triggers...";
	$triggers = explode("DEF:",file_get_contents("triggerin.sql"));
	foreach($triggers as $t) {
		if($t!="") {
			$taux = explode("\n", $t);
			$table = array_shift($taux);
			
			$t = implode("\n", $taux);
			
			preg_match_all('|(.*)\{(.*)\}|Us', $t, $trigs);
			
			foreach($trigs[1] as $I => $event) {
				$source = $trigs[2][$I];
				
				$event = str_replace("\n","",$event);
				
				$trigger_name = strtolower($table."_".str_replace(" ","_",trim($event)));
				
				mysqli_query($con,"DROP TRIGGER IF EXISTS `$trigger_name`");

				$clone_table = add_clone_tables_code($event,$table,$dont_log_changes_tables);

				$source_new = add_audit_sql($source, $event, $table);
				
				$source_new = add_deleted_tables_code($source_new, $table);
								
				$source_new.=add_log_changes($event,$table,$dont_log_changes_tables);
				
				$source_new=str_replace("#dblog#",$dblog,$source_new);
				$source_new=str_replace("#clone_table_data#",$clone_table,$source_new);
				
				//if($source_new!=$source) {
					$_audited_tables[trim($event)][] = $table;
				//}
				
				$_event = explode(" ",trim($event));
				if(array_pop($_event)=="DELETE") {
					$audit_field = "OLD.audit_updated_by";
				} else {
					$audit_field = "NEW.audit_updated_by";
				}
				
				
				$q="
CREATE TRIGGER `$trigger_name` $event ON `$table`  
FOR EACH ROW 
BEGIN 

$source_new 

IF @debug_triggers THEN
	INSERT INTO $dblog.log_triggers SET user=@app_username, datetime=CURRENT_TIMESTAMP(),trigger_name='$trigger_name',
		token_id=@rand_token,audit=$audit_field;
END IF;


END";
				
				mysqli_query($con,$q) or die("$q\n$table\n".$con->error."\n");
			}
		}
	}
	
	
	$_events = array("BEFORE UPDATE", "BEFORE INSERT","BEFORE DELETE", "AFTER UPDATE", "AFTER DELETE", "AFTER INSERT");
	global $con;
	$res_tables = mysqli_query($con,"SHOW FULL TABLES WHERE Table_Type = 'BASE TABLE'");
	while($row_tables = mysqli_fetch_array($res_tables)) {
		foreach($_events as $event) {
			if(!isset($_audited_tables[$event])) { $_audited_tables[$event] = array(); }
			
			if(!has_audit_fields($row_tables[0])) { continue; }
			
			if(!in_array($row_tables[0],$_audited_tables[$event])) {
				$trigger_name = strtolower($row_tables[0]."_".str_replace(" ","_",trim($event)));
				mysqli_query($con,"DROP TRIGGER IF EXISTS `$trigger_name`");

				if(has_audit_fields($row_tables[0])) {
					$source_new = add_audit_sql("/*audit_sql*/", $event, $row_tables[0]);
				}
				
				$source_new.=add_log_changes($event,$row_tables[0],$dont_log_changes_tables);
				
				$source_new=str_replace("#dblog#",$dblog,$source_new);
				$_event = explode(" ",trim($event));
				if(array_pop($_event)=="DELETE") {
					$audit_field = "OLD.audit_updated_by";
				} else {
					$audit_field = "NEW.audit_updated_by";
				}
				
				
				$q="
CREATE TRIGGER `$trigger_name` $event ON {$row_tables[0]}
FOR EACH ROW 
BEGIN 

$source_new 

IF @debug_triggers THEN
    INSERT INTO $dblog.log_triggers SET user=@app_username, datetime=CURRENT_TIMESTAMP(),trigger_name='$trigger_name',
		token_id=@rand_token,audit=$audit_field;
END IF;

END";
				
				mysqli_query($con,$q) or die("$q\n$table\n".$con->error."\n");
			}
		}
	}
	echo "Done!\n";
	file_put_contents("./triggerin.last", md5_file("triggerin.sql"));
} else {
	echo "Triggers file did not change! <a href='triggerin.php?force=true'>Force run?</a>\n";
}

unlink("./triggerin.running");
