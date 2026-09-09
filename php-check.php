<?php
header('Content-Type: text/plain; charset=utf-8');
echo "ZKOUSKA IX PHP CHECK\n";
echo "PHP_VERSION=" . PHP_VERSION . "\n";
echo "PDO=" . (extension_loaded('pdo') ? 'yes' : 'no') . "\n";
echo "PDO_MYSQL=" . (extension_loaded('pdo_mysql') ? 'yes' : 'no') . "\n";
echo "JSON=" . (extension_loaded('json') ? 'yes' : 'no') . "\n";
echo "OK\n";
