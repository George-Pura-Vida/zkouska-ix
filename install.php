<?php
declare(strict_types=1);

if (file_exists(__DIR__ . '/config.php')) {
    http_response_code(403);
    exit('Instalace je již uzamčena. config.php existuje.');
}

$defaults = [
    'host' => 'shareddb-l.hosting.stackcp.net',
    'name' => 'zkouska_ix-39396327',
];
$error = null;
$done = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $host = trim((string)($_POST['db_host'] ?? ''));
    $name = trim((string)($_POST['db_name'] ?? ''));
    $user = trim((string)($_POST['db_user'] ?? ''));
    $pass = (string)($_POST['db_pass'] ?? '');
    $adminEmail = trim((string)($_POST['admin_email'] ?? ''));
    $adminPassword = (string)($_POST['admin_password'] ?? '');

    try {
        if ($host === '' || $name === '' || $user === '' || $pass === '') {
            throw new RuntimeException('Vyplň všechny údaje MySQL.');
        }
        if (!filter_var($adminEmail, FILTER_VALIDATE_EMAIL)) {
            throw new RuntimeException('Zadej platný e-mail administrátora.');
        }
        if (strlen($adminPassword) < 10) {
            throw new RuntimeException('Heslo administrátora musí mít alespoň 10 znaků.');
        }

        $dsn = "mysql:host={$host};dbname={$name};charset=utf8mb4";
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);

        $schemaFile = __DIR__ . '/database/001_core_schema.sql';
        if (!is_file($schemaFile)) {
            throw new RuntimeException('Chybí database/001_core_schema.sql.');
        }

        $sql = file_get_contents($schemaFile);
        if ($sql === false) {
            throw new RuntimeException('Nelze načíst SQL schéma.');
        }

        $statements = preg_split('/;\s*(?:\r?\n|$)/', $sql);
        foreach ($statements as $statement) {
            $statement = trim($statement);
            if ($statement !== '') {
                $pdo->exec($statement);
            }
        }

        $stmt = $pdo->prepare('INSERT INTO users (email,password_hash,display_name,role,is_active) VALUES (?,?,?,?,1)');
        $stmt->execute([
            $adminEmail,
            password_hash($adminPassword, PASSWORD_DEFAULT),
            'Jirka',
            'admin',
        ]);

        $config = "<?php\nreturn " . var_export([
            'db' => [
                'host' => $host,
                'name' => $name,
                'user' => $user,
                'pass' => $pass,
                'charset' => 'utf8mb4',
            ],
            'app' => [
                'name' => 'Zkouška IX',
                'timezone' => 'Europe/Prague',
                'session_name' => 'ZKOUSKAIXSESSID',
                'base_url' => 'https://zkouska.jirijanousek.cz',
            ],
        ], true) . ";\n";

        $tmp = __DIR__ . '/config.php.tmp';
        if (file_put_contents($tmp, $config, LOCK_EX) === false) {
            throw new RuntimeException('Nelze zapsat config.php. Zkontroluj práva složky na hostingu.');
        }
        if (!rename($tmp, __DIR__ . '/config.php')) {
            @unlink($tmp);
            throw new RuntimeException('Nelze dokončit vytvoření config.php.');
        }

        $done = true;
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}
?><!doctype html>
<html lang="cs">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Instalace · Zkouška IX</title>
<style>
body{font-family:system-ui,-apple-system,sans-serif;background:#f5f7fb;color:#172033;margin:0}.wrap{max-width:640px;margin:40px auto;padding:20px}.card{background:#fff;border-radius:20px;padding:28px;box-shadow:0 8px 30px #17203312}h1{margin-top:0}label{display:block;font-weight:700;margin:16px 0 6px}input{width:100%;box-sizing:border-box;padding:14px;border:1px solid #ccd3df;border-radius:12px;font-size:16px}button{width:100%;margin-top:24px;padding:15px;border:0;border-radius:12px;background:#173f91;color:#fff;font-size:17px;font-weight:800}.ok{padding:16px;background:#e8f7ed;border-radius:12px;color:#176b37}.err{padding:16px;background:#fff0f0;border-radius:12px;color:#9b2222}.muted{color:#687386;font-size:14px}</style>
</head>
<body><div class="wrap"><div class="card">
<h1>🎓 Zkouška IX</h1>
<?php if ($done): ?>
<div class="ok"><strong>✅ Databáze je připojena a schéma vytvořeno.</strong><br><br><a href="./">Otevřít aplikaci</a></div>
<?php else: ?>
<p>Jednorázové připojení aplikace k MySQL na Webkitty. Heslo zůstane pouze v <code>config.php</code> na hostingu a není v GitHubu.</p>
<?php if ($error): ?><div class="err"><?=htmlspecialchars($error,ENT_QUOTES,'UTF-8')?></div><?php endif; ?>
<form method="post" autocomplete="off">
<label>MySQL host</label><input name="db_host" value="<?=htmlspecialchars($_POST['db_host'] ?? $defaults['host'],ENT_QUOTES,'UTF-8')?>" required>
<label>Databáze</label><input name="db_name" value="<?=htmlspecialchars($_POST['db_name'] ?? $defaults['name'],ENT_QUOTES,'UTF-8')?>" required>
<label>MySQL uživatel</label><input name="db_user" value="<?=htmlspecialchars($_POST['db_user'] ?? '',ENT_QUOTES,'UTF-8')?>" required>
<label>MySQL heslo</label><input name="db_pass" type="password" required>
<hr style="border:0;border-top:1px solid #e4e8ef;margin:28px 0">
<label>Admin e-mail</label><input name="admin_email" type="email" value="<?=htmlspecialchars($_POST['admin_email'] ?? '',ENT_QUOTES,'UTF-8')?>" required>
<label>Admin heslo</label><input name="admin_password" type="password" minlength="10" required>
<button type="submit">Připojit MySQL a vytvořit databázi</button>
<p class="muted">Po úspěchu se vytvoří config.php a tento instalátor se automaticky uzamkne.</p>
</form>
<?php endif; ?>
</div></div></body></html>
