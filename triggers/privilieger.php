<?
	
$last_privilieger = file_get_contents("privilieger.last");

$DENY = array();

//if($last_privilieger!=md5_file("privilieger.sql") || $_GET["remote"]) {
	require("../database.conf.php");

	$privilieges = explode("DEF:",file_get_contents("privilieger.sql"));
	//$con->query("REVOKE ALL PRIVILEGES, GRANT OPTION FROM `$user_app`") or die("line 11<br>".$con->error);	
	$con->query("GRANT SELECT,INSERT ON `$triggerin_db_name`.* TO `$user_app`") or die("line 12<br>".$con->error);
	$con->query("GRANT SELECT,INSERT ON `$dblog`.* TO `$user_app`") or die("line 13<br>".$con->error);

	foreach($privilieges as $p) {
		if($p!="") {
			$paux = explode("\n", $p);
			$user_app = array_shift($paux);
	
			$res = $con->query("SHOW PROCEDURE STATUS");
			while($row=$res->fetch_array()) {
				if(strtoupper($row["Db"])!=strtoupper($triggerin_db_name)) { continue; }
				$con->query("GRANT EXECUTE ON PROCEDURE `$row[Name]` TO `$user_app`") or die("line 22<br>".$con->error);
			}
			$res = $con->query("SHOW FUNCTION STATUS");
			while($row=$res->fetch_array()) {
				if(strtoupper($row["Db"])!=strtoupper($triggerin_db_name)) { continue; }
				$con->query("GRANT EXECUTE ON FUNCTION `$row[Name]` TO `$user_app`") or die("line 27<br>".$con->error);
			}
			
			$p = implode("\n", $paux);
			
			preg_match_all('|(.*)\{(.*)\}|Us', $p, $privs);
			
			foreach($privs[1] as $I => $prv) {
				$def = $privs[2][$I];
				list($prv,$prv_type) = explode(" ",trim(str_replace("\n","",$prv)));
				
				
				
				$def = explode("\n", $def);
				
				foreach($def as $d) {
					if($d!="") {
						list($table,$field) = explode(":", $d);
						
						$table = trim($table);
						
						if($prv=="DENY") {
							$field = explode(",",$field);
							foreach($field as $ff) {
								$ff = trim(str_replace("\n","",$ff));
								$DENY[$prv_type][$table][]=$ff;
							}
						}
					}
				}
			}
			
		}
		
	}
	try {
		$q="SHOW FULL TABLES WHERE Table_Type = 'BASE TABLE'";
		$res = $con->query($q);
		while($row=$res->fetch_array()) {
			$res2 = $con->query("DESCRIBE `$row[0]`") or die($q."<br>".$con->error);
			
			$updatefields = array();
			while($row2=$res2->fetch_array()) {
				if(!is_array($DENY["UPDATE"][$row[0]])) {
					$updatefields[]="`$row2[0]`";
				} elseif(in_array($row2[0],$DENY["UPDATE"][$row[0]])===false && $DENY["UPDATE"][$row[0]][0]!="*") {
					$updatefields[]="`$row2[0]`";
				}
			}
			
			if(count($updatefields)) {
				$q="GRANT UPDATE (".implode(",",$updatefields).") ON `$triggerin_db_name`.`$row[0]` TO `$user_app`";
				$con->query($q) or die("line 73<br>".$con->error."<br>$q");
			}
			
			$res2 = $con->query("DESCRIBE `$row[0]`");
			$deletefields = array();
			while($row2=$res2->fetch_array()) {
				if(!is_array($DENY["DELETE"][$row[0]])) {
					$deletefields[]="`$row2[0]`";
				} elseif(@in_array($row2[0],$DENY["DELETE"][$row[0]])===false && $DENY["DELETE"][$row[0]][0]!="*") {
					$deletefields[]="`$row2[0]`";
				}
			}
			if(count($deletefields)) {
				$q="GRANT DELETE ON `$triggerin_db_name`.`$row[0]` TO `$user_app`";
				$con->query($q) or die("line 85<br>".$con->error."<br>$q");
			}
		}
	} catch(Exception $e) {
		echo $q;
		echo $e->getMessage();
	}
	
	file_put_contents("./privilieger.last", md5_file("privilieger.sql"));
	echo "Completed";
//}
