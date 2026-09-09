SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(120) NULL,
  role ENUM('user','admin') NOT NULL DEFAULT 'user',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exams (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(20) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_versions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  exam_id BIGINT UNSIGNED NOT NULL,
  version_code VARCHAR(50) NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE NULL,
  duration_minutes SMALLINT UNSIGNED NOT NULL,
  total_questions SMALLINT UNSIGNED NOT NULL,
  total_points DECIMAL(6,2) NOT NULL,
  total_pass_percent DECIMAL(5,2) NOT NULL,
  total_pass_points DECIMAL(6,2) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_exam_version (exam_id, version_code),
  CONSTRAINT fk_ev_exam FOREIGN KEY (exam_id) REFERENCES exams(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_sections (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(30) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS question_types (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  answer_mode ENUM('single','multiple') NOT NULL,
  requires_case_study TINYINT(1) NOT NULL DEFAULT 0,
  min_correct_options TINYINT UNSIGNED NOT NULL DEFAULT 1,
  max_correct_options TINYINT UNSIGNED NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_version_sections (
  exam_version_id BIGINT UNSIGNED NOT NULL,
  section_id BIGINT UNSIGNED NOT NULL,
  question_count SMALLINT UNSIGNED NOT NULL,
  max_points DECIMAL(6,2) NOT NULL,
  pass_percent DECIMAL(5,2) NOT NULL,
  pass_points DECIMAL(6,2) NOT NULL,
  PRIMARY KEY (exam_version_id, section_id),
  CONSTRAINT fk_evs_ev FOREIGN KEY (exam_version_id) REFERENCES exam_versions(id) ON DELETE CASCADE,
  CONSTRAINT fk_evs_section FOREIGN KEY (section_id) REFERENCES exam_sections(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_version_question_types (
  exam_version_id BIGINT UNSIGNED NOT NULL,
  question_type_id BIGINT UNSIGNED NOT NULL,
  section_id BIGINT UNSIGNED NOT NULL,
  question_count SMALLINT UNSIGNED NOT NULL,
  points_per_question DECIMAL(5,2) NOT NULL,
  PRIMARY KEY (exam_version_id, question_type_id),
  CONSTRAINT fk_evqt_ev FOREIGN KEY (exam_version_id) REFERENCES exam_versions(id) ON DELETE CASCADE,
  CONSTRAINT fk_evqt_qt FOREIGN KEY (question_type_id) REFERENCES question_types(id),
  CONSTRAINT fk_evqt_section FOREIGN KEY (section_id) REFERENCES exam_sections(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS domains (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_version_domain_quotas (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  exam_version_id BIGINT UNSIGNED NOT NULL,
  section_id BIGINT UNSIGNED NOT NULL,
  domain_id BIGINT UNSIGNED NOT NULL,
  quota_unit ENUM('questions','case_studies') NOT NULL,
  quota_count SMALLINT UNSIGNED NOT NULL,
  UNIQUE KEY uq_ev_domain_quota (exam_version_id, section_id, domain_id, quota_unit),
  CONSTRAINT fk_evdq_ev FOREIGN KEY (exam_version_id) REFERENCES exam_versions(id) ON DELETE CASCADE,
  CONSTRAINT fk_evdq_section FOREIGN KEY (section_id) REFERENCES exam_sections(id),
  CONSTRAINT fk_evdq_domain FOREIGN KEY (domain_id) REFERENCES domains(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_version_case_rules (
  exam_version_id BIGINT UNSIGNED PRIMARY KEY,
  case_study_count SMALLINT UNSIGNED NOT NULL,
  questions_per_case SMALLINT UNSIGNED NOT NULL,
  total_case_questions SMALLINT UNSIGNED NOT NULL,
  CONSTRAINT fk_evcr_ev FOREIGN KEY (exam_version_id) REFERENCES exam_versions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS source_documents (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  filename VARCHAR(255) NOT NULL,
  source_type ENUM('official_pdf','manual','other') NOT NULL DEFAULT 'official_pdf',
  valid_from DATE NULL,
  valid_to DATE NULL,
  sha256 CHAR(64) NULL UNIQUE,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS question_bank_versions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  exam_id BIGINT UNSIGNED NOT NULL,
  source_document_id BIGINT UNSIGNED NULL,
  version_code VARCHAR(50) NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE NULL,
  status ENUM('draft','validated','active','archived') NOT NULL DEFAULT 'draft',
  imported_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_qbv (exam_id, version_code),
  CONSTRAINT fk_qbv_exam FOREIGN KEY (exam_id) REFERENCES exams(id),
  CONSTRAINT fk_qbv_source FOREIGN KEY (source_document_id) REFERENCES source_documents(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS categories (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  domain_id BIGINT UNSIGNED NOT NULL,
  official_code VARCHAR(100) NULL,
  official_name VARCHAR(500) NOT NULL,
  CONSTRAINT fk_category_domain FOREIGN KEY (domain_id) REFERENCES domains(id),
  INDEX idx_category_domain (domain_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS questions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  exam_id BIGINT UNSIGNED NOT NULL,
  official_number VARCHAR(50) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_question_official (exam_id, official_number),
  CONSTRAINT fk_question_exam FOREIGN KEY (exam_id) REFERENCES exams(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS case_studies (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  exam_id BIGINT UNSIGNED NOT NULL,
  domain_id BIGINT UNSIGNED NOT NULL,
  official_number VARCHAR(50) NULL,
  stable_key VARCHAR(100) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_case_key (exam_id, stable_key),
  CONSTRAINT fk_case_exam FOREIGN KEY (exam_id) REFERENCES exams(id),
  CONSTRAINT fk_case_domain FOREIGN KEY (domain_id) REFERENCES domains(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS case_study_versions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  case_study_id BIGINT UNSIGNED NOT NULL,
  version_no SMALLINT UNSIGNED NOT NULL,
  title VARCHAR(255) NULL,
  case_text MEDIUMTEXT NOT NULL,
  explanation MEDIUMTEXT NULL,
  source_text MEDIUMTEXT NULL,
  content_hash CHAR(64) NULL,
  valid_from DATE NULL,
  valid_to DATE NULL,
  UNIQUE KEY uq_case_version (case_study_id, version_no),
  CONSTRAINT fk_csv_case FOREIGN KEY (case_study_id) REFERENCES case_studies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS question_versions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  question_id BIGINT UNSIGNED NOT NULL,
  version_no SMALLINT UNSIGNED NOT NULL,
  question_type_id BIGINT UNSIGNED NOT NULL,
  category_id BIGINT UNSIGNED NOT NULL,
  case_study_version_id BIGINT UNSIGNED NULL,
  case_question_position TINYINT UNSIGNED NULL,
  question_text MEDIUMTEXT NOT NULL,
  explanation MEDIUMTEXT NULL,
  source_text MEDIUMTEXT NULL,
  content_hash CHAR(64) NULL,
  valid_from DATE NULL,
  valid_to DATE NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_question_version (question_id, version_no),
  UNIQUE KEY uq_case_position (case_study_version_id, case_question_position),
  CONSTRAINT fk_qv_question FOREIGN KEY (question_id) REFERENCES questions(id),
  CONSTRAINT fk_qv_type FOREIGN KEY (question_type_id) REFERENCES question_types(id),
  CONSTRAINT fk_qv_category FOREIGN KEY (category_id) REFERENCES categories(id),
  CONSTRAINT fk_qv_case FOREIGN KEY (case_study_version_id) REFERENCES case_study_versions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS answer_options (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  question_version_id BIGINT UNSIGNED NOT NULL,
  option_letter ENUM('A','B','C','D') NOT NULL,
  option_text MEDIUMTEXT NOT NULL,
  is_correct TINYINT(1) NOT NULL,
  UNIQUE KEY uq_answer_letter (question_version_id, option_letter),
  CONSTRAINT fk_answer_qv FOREIGN KEY (question_version_id) REFERENCES question_versions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS question_bank_question_versions (
  question_bank_version_id BIGINT UNSIGNED NOT NULL,
  question_version_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (question_bank_version_id, question_version_id),
  CONSTRAINT fk_bqv_bank FOREIGN KEY (question_bank_version_id) REFERENCES question_bank_versions(id) ON DELETE CASCADE,
  CONSTRAINT fk_bqv_qv FOREIGN KEY (question_version_id) REFERENCES question_versions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_attempts (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  exam_version_id BIGINT UNSIGNED NOT NULL,
  question_bank_version_id BIGINT UNSIGNED NOT NULL,
  status ENUM('in_progress','submitted','scored','abandoned') NOT NULL DEFAULT 'in_progress',
  started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  submitted_at DATETIME NULL,
  scored_at DATETIME NULL,
  duration_seconds INT UNSIGNED NULL,
  total_max_points DECIMAL(6,2) NOT NULL,
  knowledge_max_points DECIMAL(6,2) NOT NULL,
  skills_max_points DECIMAL(6,2) NOT NULL,
  total_pass_points DECIMAL(6,2) NOT NULL,
  knowledge_pass_points DECIMAL(6,2) NOT NULL,
  skills_pass_points DECIMAL(6,2) NOT NULL,
  knowledge_points DECIMAL(6,2) NULL,
  skills_points DECIMAL(6,2) NULL,
  total_points DECIMAL(6,2) NULL,
  knowledge_percent DECIMAL(5,2) NULL,
  skills_percent DECIMAL(5,2) NULL,
  total_percent DECIMAL(5,2) NULL,
  knowledge_condition_met TINYINT(1) NULL,
  skills_condition_met TINYINT(1) NULL,
  total_condition_met TINYINT(1) NULL,
  passed TINYINT(1) NULL,
  current_score_audit_id BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_attempt_user FOREIGN KEY (user_id) REFERENCES users(id),
  CONSTRAINT fk_attempt_ev FOREIGN KEY (exam_version_id) REFERENCES exam_versions(id),
  CONSTRAINT fk_attempt_qbv FOREIGN KEY (question_bank_version_id) REFERENCES question_bank_versions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS attempt_questions (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  attempt_id BIGINT UNSIGNED NOT NULL,
  question_version_id BIGINT UNSIGNED NOT NULL,
  section_id BIGINT UNSIGNED NOT NULL,
  question_type_id BIGINT UNSIGNED NOT NULL,
  case_study_version_id BIGINT UNSIGNED NULL,
  case_question_position TINYINT UNSIGNED NULL,
  position SMALLINT UNSIGNED NOT NULL,
  answer_order JSON NULL,
  points_possible DECIMAL(5,2) NOT NULL,
  points_awarded DECIMAL(5,2) NULL,
  is_correct TINYINT(1) NULL,
  is_answered TINYINT(1) NOT NULL DEFAULT 0,
  is_flagged TINYINT(1) NOT NULL DEFAULT 0,
  response_time_ms INT UNSIGNED NULL,
  answered_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_attempt_position (attempt_id, position),
  UNIQUE KEY uq_attempt_question (attempt_id, question_version_id),
  CONSTRAINT fk_aq_attempt FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE,
  CONSTRAINT fk_aq_qv FOREIGN KEY (question_version_id) REFERENCES question_versions(id),
  CONSTRAINT fk_aq_section FOREIGN KEY (section_id) REFERENCES exam_sections(id),
  CONSTRAINT fk_aq_type FOREIGN KEY (question_type_id) REFERENCES question_types(id),
  CONSTRAINT fk_aq_case FOREIGN KEY (case_study_version_id) REFERENCES case_study_versions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS attempt_answers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  attempt_question_id BIGINT UNSIGNED NOT NULL,
  answer_option_id BIGINT UNSIGNED NOT NULL,
  option_letter_snapshot ENUM('A','B','C','D') NOT NULL,
  selected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_attempt_selected_answer (attempt_question_id, answer_option_id),
  CONSTRAINT fk_aa_aq FOREIGN KEY (attempt_question_id) REFERENCES attempt_questions(id) ON DELETE CASCADE,
  CONSTRAINT fk_aa_option FOREIGN KEY (answer_option_id) REFERENCES answer_options(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_attempt_score_audits (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  attempt_id BIGINT UNSIGNED NOT NULL,
  audit_no INT UNSIGNED NOT NULL,
  calculation_type ENUM('initial','recalculation','manual_override','data_correction','rules_change','question_bank_change') NOT NULL,
  initiated_by ENUM('system','user','admin','migration') NOT NULL DEFAULT 'system',
  actor_user_id BIGINT UNSIGNED NULL,
  reason_code ENUM('initial_scoring','manual_rescore','answer_correction','question_correction','scoring_rule_change','exam_rule_change','question_bank_update','technical_fix','other') NOT NULL,
  reason_text TEXT NULL,
  scoring_engine_version VARCHAR(50) NOT NULL,
  rules_snapshot JSON NOT NULL,
  previous_knowledge_points DECIMAL(6,2) NULL,
  previous_skills_points DECIMAL(6,2) NULL,
  previous_total_points DECIMAL(6,2) NULL,
  previous_knowledge_percent DECIMAL(5,2) NULL,
  previous_skills_percent DECIMAL(5,2) NULL,
  previous_total_percent DECIMAL(5,2) NULL,
  previous_knowledge_condition_met TINYINT(1) NULL,
  previous_skills_condition_met TINYINT(1) NULL,
  previous_total_condition_met TINYINT(1) NULL,
  previous_passed TINYINT(1) NULL,
  knowledge_points DECIMAL(6,2) NOT NULL,
  skills_points DECIMAL(6,2) NOT NULL,
  total_points DECIMAL(6,2) NOT NULL,
  knowledge_percent DECIMAL(5,2) NOT NULL,
  skills_percent DECIMAL(5,2) NOT NULL,
  total_percent DECIMAL(5,2) NOT NULL,
  knowledge_condition_met TINYINT(1) NOT NULL,
  skills_condition_met TINYINT(1) NOT NULL,
  total_condition_met TINYINT(1) NOT NULL,
  passed TINYINT(1) NOT NULL,
  result_changed TINYINT(1) NOT NULL DEFAULT 0,
  score_changed TINYINT(1) NOT NULL DEFAULT 0,
  calculation_started_at DATETIME(6) NOT NULL,
  calculation_finished_at DATETIME(6) NOT NULL,
  calculation_duration_ms INT UNSIGNED NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY uq_score_audit_attempt_no (attempt_id, audit_no),
  CONSTRAINT fk_score_audit_attempt FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id),
  CONSTRAINT fk_score_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS exam_attempt_question_score_audits (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  score_audit_id BIGINT UNSIGNED NOT NULL,
  attempt_question_id BIGINT UNSIGNED NOT NULL,
  question_version_id BIGINT UNSIGNED NOT NULL,
  section_code VARCHAR(30) NOT NULL,
  question_type_code VARCHAR(50) NOT NULL,
  points_possible DECIMAL(5,2) NOT NULL,
  points_awarded DECIMAL(5,2) NOT NULL,
  is_correct TINYINT(1) NOT NULL,
  selected_option_ids JSON NOT NULL,
  correct_option_ids JSON NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY uq_question_score_audit (score_audit_id, attempt_question_id),
  CONSTRAINT fk_qsa_run FOREIGN KEY (score_audit_id) REFERENCES exam_attempt_score_audits(id),
  CONSTRAINT fk_qsa_aq FOREIGN KEY (attempt_question_id) REFERENCES attempt_questions(id),
  CONSTRAINT fk_qsa_qv FOREIGN KEY (question_version_id) REFERENCES question_versions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE exam_attempts ADD CONSTRAINT fk_attempt_current_score_audit FOREIGN KEY (current_score_audit_id) REFERENCES exam_attempt_score_audits(id);

INSERT IGNORE INTO exams (code, name) VALUES ('IX','Souhrnná zkouška na pojištění');
INSERT IGNORE INTO exam_sections (code, name) VALUES ('KNOWLEDGE','Odborné znalosti'),('SKILLS','Odborné dovednosti');
INSERT IGNORE INTO question_types (code,name,answer_mode,requires_case_study,min_correct_options,max_correct_options) VALUES
('KNOWLEDGE_SINGLE','Znalostní otázka s jednou správnou odpovědí','single',0,1,1),
('KNOWLEDGE_MULTIPLE','Znalostní otázka s více správnými odpověďmi','multiple',0,2,4),
('CASE_SINGLE','Otázka v případové studii s jednou správnou odpovědí','single',1,1,1);
INSERT IGNORE INTO domains (code,name) VALUES ('LIFE','Životní pojištění'),('LARGE_RISKS','Pojištění velkých pojistných rizik');

INSERT IGNORE INTO exam_versions (exam_id,version_code,valid_from,duration_minutes,total_questions,total_points,total_pass_percent,total_pass_points,is_active)
SELECT id,'IX-2026','2026-08-20',180,100,140,75,105,1 FROM exams WHERE code='IX';

SET @ev := (SELECT ev.id FROM exam_versions ev JOIN exams e ON e.id=ev.exam_id WHERE e.code='IX' AND ev.version_code='IX-2026' LIMIT 1);
SET @knowledge := (SELECT id FROM exam_sections WHERE code='KNOWLEDGE');
SET @skills := (SELECT id FROM exam_sections WHERE code='SKILLS');
SET @single := (SELECT id FROM question_types WHERE code='KNOWLEDGE_SINGLE');
SET @multiple := (SELECT id FROM question_types WHERE code='KNOWLEDGE_MULTIPLE');
SET @case_single := (SELECT id FROM question_types WHERE code='CASE_SINGLE');
SET @life := (SELECT id FROM domains WHERE code='LIFE');
SET @large := (SELECT id FROM domains WHERE code='LARGE_RISKS');

INSERT IGNORE INTO exam_version_sections VALUES (@ev,@knowledge,80,100,60,60),(@ev,@skills,20,40,60,24);
INSERT IGNORE INTO exam_version_question_types VALUES (@ev,@single,@knowledge,60,1),(@ev,@multiple,@knowledge,20,2),(@ev,@case_single,@skills,20,2);
INSERT IGNORE INTO exam_version_case_rules VALUES (@ev,4,5,20);
INSERT IGNORE INTO exam_version_domain_quotas (exam_version_id,section_id,domain_id,quota_unit,quota_count) VALUES
(@ev,@knowledge,@large,'questions',52),(@ev,@knowledge,@life,'questions',28),(@ev,@skills,@large,'case_studies',2),(@ev,@skills,@life,'case_studies',2);
