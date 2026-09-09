# Zkouška IX

PWA aplikace pro přípravu na odbornou zkoušku IX podle ZDPZ.

## Produkce

- URL: https://zkouska.jirijanousek.cz/
- PHP 8+
- MySQL 8 / MariaDB kompatibilní jádro
- databáze: `zkouska_ix-39396327`
- DB host: `shareddb-l.hosting.stackcp.net`

## Struktura ostré Zkoušky IX

- 80 znalostních otázek
  - 60 × single × 1 bod
  - 20 × multiple × 2 body
- 4 případové studie × 5 otázek × 2 body
- maximum 140 bodů
- čas 180 minut
- splnit současně:
  - 105/140 celkem
  - 60/100 znalosti
  - 24/40 dovednosti

## První instalace na Webkitty

1. Nasaď obsah repozitáře do document rootu subdomény `zkouska.jirijanousek.cz`.
2. Otevři `https://zkouska.jirijanousek.cz/install.php`.
3. Host a název databáze jsou předvyplněné.
4. Vyplň pouze MySQL uživatele, MySQL heslo a admin účet.
5. Instalátor vytvoří `config.php` pouze na hostingu. Soubor je v `.gitignore` a nikdy se neukládá do GitHubu.
6. Po vytvoření `config.php` se instalátor automaticky uzamkne.

## SQL

- `database/001_core_schema.sql` – tabulky + seed struktury IX
- `database/025_finalize_exam_attempt_atomic.sql` – atomické vyhodnocení + audit
- `database/026_immutable_audit_triggers.sql` – immutable auditní triggery

Stored proceduru a triggery lze po základní instalaci importovat v phpMyAdminu.

## Bezpečnost

Nikdy necommitovat `config.php`, DB hesla ani jiné produkční secrets.
