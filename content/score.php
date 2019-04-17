<?php

$fp = fopen("lock.txt", "r+");

if (flock($fp, LOCK_EX)) {
   // Setting this header instructs Nginx to disable fastcgi_buffering and disable
   // gzip for this request... data gets sent back to the user right away
   header('X-Accel-Buffering: no');

   file_put_contents("teams.txt", $_GET['team_name']."\n", FILE_APPEND | LOCK_EX);

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

    echo $t;
    ob_flush();
    flush();

    exec("supervisorctl stop koth:*");
    sleep(100); // just trying to sleep long enough for everything to be stopped yet not have another team score
}

fclose($fp);

?>
