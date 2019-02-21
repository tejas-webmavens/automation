<?

require("./triggerin.conf.php");

$files = glob(dirname(__FILE__)."/procfunc*.sql");
while($f=array_shift($files)) {
	$def_name = str_replace(array("procfunc_", ".sql"), "", basename($f));
	$def_src = file_get_contents($f);
	$_exp = explode("CREATE ", $def_src);
	$exp2 = explode(" $def_name", array_pop($_exp));
	$def_type = array_shift($exp2);
	
	$con->query("DROP $def_type IF EXISTS $def_name") or print($con->error);
	$con->query($def_src) or die($con->error);
	
}

include("privilieger.php");
