<?php
declare(strict_types=1);

if (!file_exists(__DIR__ . '/config.php')) {
    header('Location: install.php');
    exit;
}

require __DIR__ . '/lib.php';

$dbOk = false;
$questionCount = 0;
$caseCount = 0;
$attemptCount = 0;
$exam = null;
$error = null;

try {
    $pdo = db();
    $pdo->query('SELECT 1');
    $dbOk = true;
    $questionCount = (int)$pdo->query('SELECT COUNT(*) FROM question_versions')->fetchColumn();
    $caseCount = (int)$pdo->query('SELECT COUNT(*) FROM case_study_versions')->fetchColumn();
    $attemptCount = (int)$pdo->query('SELECT COUNT(*) FROM exam_attempts')->fetchColumn();
    $exam = $pdo->query("SELECT e.code,e.name,ev.duration_minutes,ev.total_questions,ev.total_points,ev.total_pass_points FROM exams e JOIN exam_versions ev ON ev.exam_id=e.id WHERE e.code='IX' AND ev.is_active=1 ORDER BY ev.valid_from DESC LIMIT 1")->fetch();
} catch (Throwable $e) {
    $error = $e->getMessage();
}
?><!doctype html>
<html lang="cs">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#153d8a">
<title>Zkouška IX</title>
<style>
:root{font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#172033;background:#f5f7fb}*{box-sizing:border-box}body{margin:0}.app{max-width:760px;margin:0 auto;padding:22px 18px 100px}.top{display:flex;align-items:center;justify-content:space-between;margin-bottom:22px}.brand{font-size:26px;font-weight:900}.chip{padding:8px 12px;border-radius:999px;font-weight:800;font-size:13px}.green{background:#e8f7ed;color:#176b37}.red{background:#ffeceb;color:#a52828}.hero{background:linear-gradient(135deg,#153d8a,#2757b7);color:white;padding:26px;border-radius:24px;box-shadow:0 14px 35px #173f9130}.hero h1{font-size:32px;margin:0 0 8px}.hero p{margin:0;opacity:.88}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:18px}.stat{background:white;border-radius:18px;padding:18px;box-shadow:0 5px 18px #1720330c}.stat b{display:block;font-size:25px}.stat span{color:#6b7586;font-size:13px}.section{margin-top:24px}.section h2{font-size:19px}.buttons{display:grid;gap:12px}.btn{display:block;text-decoration:none;background:#fff;color:#172033;padding:18px;border-radius:17px;font-weight:850;box-shadow:0 5px 18px #1720330c}.btn strong{display:block;font-size:17px}.btn small{display:block;color:#6b7586;margin-top:4px;font-weight:500}.notice{margin-top:20px;background:#fff6d8;border-radius:16px;padding:16px;color:#7a5c00}.error{background:#ffeceb;color:#912626;padding:16px;border-radius:16px;margin-top:20px}@media(max-width:520px){.grid{grid-template-columns:1fr 1fr}.grid .stat:last-child{grid-column:1/-1}.hero h1{font-size:28px}}</style>
</head>
<body>
<main class="app">
<div class="top"><div class="brand">🎓 Zkouška IX</div><div class="chip <?=$dbOk?'green':'red'?>"><?=$dbOk?'MySQL připojeno':'DB chyba'?></div></div>
<section class="hero">
<h1><?=h($exam['name'] ?? 'Souhrnná zkouška na pojištění')?></h1>
<p><?=isset($exam['duration_minutes'])?(int)$exam['duration_minutes'].' minut · '.(int)$exam['total_questions'].' otázek · '.(int)$exam['total_points'].' bodů':'Příprava na Zkoušku IX'?></p>
</section>
<?php if($error): ?><div class="error">⚠️ <?=h($error)?></div><?php endif; ?>
<div class="grid">
<div class="stat"><b><?=$questionCount?></b><span>verzí otázek</span></div>
<div class="stat"><b><?=$caseCount?></b><span>případových studií</span></div>
<div class="stat"><b><?=$attemptCount?></b><span>pokusů</span></div>
</div>
<section class="section"><h2>Trénink</h2><div class="buttons">
<a class="btn" href="#"><strong>🔥 Co mám teď trénovat?</strong><small>Adaptivní výběr slabých míst</small></a>
<a class="btn" href="#"><strong>🎯 Diagnostický test</strong><small>Rychlá kontrola připravenosti</small></a>
<a class="btn" href="#"><strong>🏆 Ostrá zkouška IX</strong><small>180 minut · 100 otázek · 140 bodů</small></a>
</div></section>
<?php if($questionCount===0 && $dbOk): ?><div class="notice"><strong>🟡 Databáze funguje.</strong><br>Další krok je import oficiální banky otázek platné od 20. 8. 2026.</div><?php endif; ?>
</main>
</body>
</html>
