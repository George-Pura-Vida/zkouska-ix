<?php
declare(strict_types=1);

$configFile = __DIR__ . '/config.php';

if (!file_exists($configFile)) {
    if (basename($_SERVER['PHP_SELF'] ?? '') !== 'install.php') {
        http_response_code(503);
        echo 'Zkouška IX není ještě připojena k databázi. Vytvořte config.php podle config.example.php.';
        exit;
    }
    return;
}

$CFG = require $configFile;
date_default_timezone_set($CFG['app']['timezone'] ?? 'Europe/Prague');

if (PHP_SAPI !== 'cli') {
    ini_set('session.use_strict_mode', '1');
    ini_set('session.cookie_httponly', '1');
    ini_set('session.cookie_samesite', 'Lax');

    $isHttps =
        (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https')
        || (($_SERVER['SERVER_PORT'] ?? '') === '443');

    session_name($CFG['app']['session_name'] ?? 'ZKOUSKAIXSESSID');
    session_set_cookie_params([
        'secure' => $isHttps,
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    session_start();
}

function db(): PDO {
    global $CFG;
    static $pdo = null;
    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $d = $CFG['db'];
    $dsn = 'mysql:host=' . $d['host'] . ';dbname=' . $d['name'] . ';charset=' . ($d['charset'] ?? 'utf8mb4');

    $pdo = new PDO($dsn, $d['user'], $d['pass'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);

    return $pdo;
}

function h(?string $value): string {
    return htmlspecialchars($value ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function json_response(array $payload, int $status = 200): never {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
