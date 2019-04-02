<?php

$fp = fopen("lock.txt", "r+");

if (flock($fp, LOCK_EX)) {

   file_put_contents("fake_aps.txt", $_GET['team_name']."\n", FILE_APPEND | LOCK_EX);

$t = <<<EX
<html>
<head>
<title>King of the Hill</title>
</head>
<body>
<style>
body {background-color: #F6F4F3;}
</style>
<center>
The following team has scored:
<h1 style="font-family:Courier New;">{$_GET['team_name']}</h1>
<br>
Locking Access Point
</center>
</body>
</html>
EX;

    exec("COMMAND");

    flock($fp, LOCK_UN);
    echo $t;
}
fclose($fp);

?>
