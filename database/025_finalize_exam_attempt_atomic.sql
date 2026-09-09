DROP PROCEDURE IF EXISTS finalize_exam_attempt_atomic;
DELIMITER $$
CREATE PROCEDURE finalize_exam_attempt_atomic(
    IN p_attempt_id BIGINT UNSIGNED,
    IN p_calculation_type VARCHAR(32),
    IN p_initiated_by VARCHAR(32),
    IN p_actor_user_id BIGINT UNSIGNED,
    IN p_reason_code VARCHAR(50),
    IN p_reason_text TEXT,
    IN p_scoring_engine_version VARCHAR(50)
)
proc: BEGIN
    DECLARE v_started_at DATETIME(6);
    DECLARE v_finished_at DATETIME(6);
    DECLARE v_duration_ms BIGINT UNSIGNED DEFAULT 0;
    DECLARE v_exam_version_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_question_bank_version_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_current_score_audit_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_audit_no INT UNSIGNED DEFAULT 0;
    DECLARE v_score_audit_id BIGINT UNSIGNED DEFAULT NULL;
    DECLARE v_attempt_status VARCHAR(30);
    DECLARE v_knowledge_max DECIMAL(6,2);
    DECLARE v_skills_max DECIMAL(6,2);
    DECLARE v_total_max DECIMAL(6,2);
    DECLARE v_knowledge_pass DECIMAL(6,2);
    DECLARE v_skills_pass DECIMAL(6,2);
    DECLARE v_total_pass DECIMAL(6,2);
    DECLARE v_knowledge DECIMAL(6,2) DEFAULT 0;
    DECLARE v_skills DECIMAL(6,2) DEFAULT 0;
    DECLARE v_total DECIMAL(6,2) DEFAULT 0;
    DECLARE v_knowledge_pct DECIMAL(5,2) DEFAULT 0;
    DECLARE v_skills_pct DECIMAL(5,2) DEFAULT 0;
    DECLARE v_total_pct DECIMAL(5,2) DEFAULT 0;
    DECLARE v_knowledge_met TINYINT DEFAULT 0;
    DECLARE v_skills_met TINYINT DEFAULT 0;
    DECLARE v_total_met TINYINT DEFAULT 0;
    DECLARE v_passed TINYINT DEFAULT 0;
    DECLARE v_prev_knowledge DECIMAL(6,2) DEFAULT NULL;
    DECLARE v_prev_skills DECIMAL(6,2) DEFAULT NULL;
    DECLARE v_prev_total DECIMAL(6,2) DEFAULT NULL;
    DECLARE v_prev_knowledge_pct DECIMAL(5,2) DEFAULT NULL;
    DECLARE v_prev_skills_pct DECIMAL(5,2) DEFAULT NULL;
    DECLARE v_prev_total_pct DECIMAL(5,2) DEFAULT NULL;
    DECLARE v_prev_knowledge_met TINYINT DEFAULT NULL;
    DECLARE v_prev_skills_met TINYINT DEFAULT NULL;
    DECLARE v_prev_total_met TINYINT DEFAULT NULL;
    DECLARE v_prev_passed TINYINT DEFAULT NULL;
    DECLARE v_score_changed TINYINT DEFAULT 0;
    DECLARE v_result_changed TINYINT DEFAULT 0;
    DECLARE v_invalid_answers INT UNSIGNED DEFAULT 0;
    DECLARE v_attempt_knowledge_possible DECIMAL(6,2) DEFAULT 0;
    DECLARE v_attempt_skills_possible DECIMAL(6,2) DEFAULT 0;
    DECLARE v_attempt_total_possible DECIMAL(6,2) DEFAULT 0;
    DECLARE v_rules_snapshot JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS tmp_question_audit;
        RESIGNAL;
    END;

    IF p_attempt_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='attempt_id nesmí být NULL.';
    END IF;
    IF p_scoring_engine_version IS NULL OR CHAR_LENGTH(TRIM(p_scoring_engine_version))=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='scoring_engine_version je povinný.';
    END IF;

    SET v_started_at=CURRENT_TIMESTAMP(6);
    DROP TEMPORARY TABLE IF EXISTS tmp_question_audit;
    START TRANSACTION;

    SELECT status,exam_version_id,question_bank_version_id,current_score_audit_id,
           knowledge_max_points,skills_max_points,total_max_points,
           knowledge_pass_points,skills_pass_points,total_pass_points,
           knowledge_points,skills_points,total_points,
           knowledge_percent,skills_percent,total_percent,
           knowledge_condition_met,skills_condition_met,total_condition_met,passed
      INTO v_attempt_status,v_exam_version_id,v_question_bank_version_id,v_current_score_audit_id,
           v_knowledge_max,v_skills_max,v_total_max,
           v_knowledge_pass,v_skills_pass,v_total_pass,
           v_prev_knowledge,v_prev_skills,v_prev_total,
           v_prev_knowledge_pct,v_prev_skills_pct,v_prev_total_pct,
           v_prev_knowledge_met,v_prev_skills_met,v_prev_total_met,v_prev_passed
      FROM exam_attempts WHERE id=p_attempt_id FOR UPDATE;

    IF v_exam_version_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Požadovaný exam_attempt neexistuje.';
    END IF;
    IF v_attempt_status='abandoned' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Opuštěný pokus nelze vyhodnotit.';
    END IF;
    IF v_current_score_audit_id IS NULL AND p_calculation_type<>'initial' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='První vyhodnocení musí mít calculation_type=initial.';
    END IF;
    IF v_current_score_audit_id IS NOT NULL AND p_calculation_type='initial' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pokus již byl vyhodnocen.';
    END IF;

    SELECT COUNT(*) INTO v_invalid_answers
      FROM attempt_answers aa
      JOIN attempt_questions aq ON aq.id=aa.attempt_question_id
      JOIN answer_options ao ON ao.id=aa.answer_option_id
     WHERE aq.attempt_id=p_attempt_id AND ao.question_version_id<>aq.question_version_id;
    IF v_invalid_answers>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Pokus obsahuje odpověď nepatřící k dané verzi otázky.';
    END IF;

    SELECT COALESCE(SUM(CASE WHEN es.code='KNOWLEDGE' THEN aq.points_possible ELSE 0 END),0),
           COALESCE(SUM(CASE WHEN es.code='SKILLS' THEN aq.points_possible ELSE 0 END),0),
           COALESCE(SUM(aq.points_possible),0)
      INTO v_attempt_knowledge_possible,v_attempt_skills_possible,v_attempt_total_possible
      FROM attempt_questions aq JOIN exam_sections es ON es.id=aq.section_id
     WHERE aq.attempt_id=p_attempt_id;

    IF v_attempt_knowledge_possible<>v_knowledge_max OR v_attempt_skills_possible<>v_skills_max OR v_attempt_total_possible<>v_total_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Součet možných bodů neodpovídá snapshotu zkoušky.';
    END IF;

    UPDATE attempt_questions aq
    JOIN (
        SELECT aq2.id AS attempt_question_id,
               COUNT(DISTINCT CASE WHEN ao.is_correct=1 THEN ao.id END) AS correct_count,
               COUNT(DISTINCT aa.answer_option_id) AS selected_count,
               COUNT(DISTINCT CASE WHEN ao.is_correct=1 AND aa.answer_option_id IS NOT NULL THEN ao.id END) AS selected_correct_count
          FROM attempt_questions aq2
          JOIN answer_options ao ON ao.question_version_id=aq2.question_version_id
          LEFT JOIN attempt_answers aa ON aa.attempt_question_id=aq2.id AND aa.answer_option_id=ao.id
         WHERE aq2.attempt_id=p_attempt_id
         GROUP BY aq2.id
    ) s ON s.attempt_question_id=aq.id
       SET aq.is_answered=IF(s.selected_count>0,1,0),
           aq.is_correct=IF(s.selected_count=s.correct_count AND s.selected_correct_count=s.correct_count,1,0),
           aq.points_awarded=IF(s.selected_count=s.correct_count AND s.selected_correct_count=s.correct_count,aq.points_possible,0)
     WHERE aq.attempt_id=p_attempt_id;

    SELECT COALESCE(SUM(CASE WHEN es.code='KNOWLEDGE' THEN aq.points_awarded ELSE 0 END),0),
           COALESCE(SUM(CASE WHEN es.code='SKILLS' THEN aq.points_awarded ELSE 0 END),0),
           COALESCE(SUM(aq.points_awarded),0)
      INTO v_knowledge,v_skills,v_total
      FROM attempt_questions aq JOIN exam_sections es ON es.id=aq.section_id
     WHERE aq.attempt_id=p_attempt_id;

    SET v_knowledge_pct=ROUND(v_knowledge/NULLIF(v_knowledge_max,0)*100,2);
    SET v_skills_pct=ROUND(v_skills/NULLIF(v_skills_max,0)*100,2);
    SET v_total_pct=ROUND(v_total/NULLIF(v_total_max,0)*100,2);
    SET v_knowledge_met=IF(v_knowledge>=v_knowledge_pass,1,0);
    SET v_skills_met=IF(v_skills>=v_skills_pass,1,0);
    SET v_total_met=IF(v_total>=v_total_pass,1,0);
    SET v_passed=IF(v_knowledge_met=1 AND v_skills_met=1 AND v_total_met=1,1,0);

    IF v_current_score_audit_id IS NOT NULL THEN
        SET v_score_changed=IF(NOT(v_prev_knowledge<=>v_knowledge) OR NOT(v_prev_skills<=>v_skills) OR NOT(v_prev_total<=>v_total),1,0);
        SET v_result_changed=IF(NOT(v_prev_passed<=>v_passed),1,0);
    END IF;
    IF v_result_changed=1 AND (p_reason_text IS NULL OR CHAR_LENGTH(TRIM(p_reason_text))=0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Změna výsledku vyžaduje textový důvod.';
    END IF;

    SELECT COALESCE(MAX(audit_no),0)+1 INTO v_audit_no FROM exam_attempt_score_audits WHERE attempt_id=p_attempt_id;

    SET v_rules_snapshot=JSON_OBJECT(
        'examVersionId',v_exam_version_id,
        'questionBankVersionId',v_question_bank_version_id,
        'scoringEngineVersion',p_scoring_engine_version,
        'knowledge',JSON_OBJECT('maxPoints',v_knowledge_max,'passPoints',v_knowledge_pass),
        'skills',JSON_OBJECT('maxPoints',v_skills_max,'passPoints',v_skills_pass),
        'total',JSON_OBJECT('maxPoints',v_total_max,'passPoints',v_total_pass),
        'multipleChoiceScoring','all_or_nothing',
        'finalRule','knowledge AND skills AND total'
    );

    CREATE TEMPORARY TABLE tmp_question_audit (
        attempt_question_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
        question_version_id BIGINT UNSIGNED NOT NULL,
        section_code VARCHAR(30) NOT NULL,
        question_type_code VARCHAR(50) NOT NULL,
        points_possible DECIMAL(5,2) NOT NULL,
        points_awarded DECIMAL(5,2) NOT NULL,
        is_correct TINYINT(1) NOT NULL,
        selected_option_ids JSON NOT NULL,
        correct_option_ids JSON NOT NULL
    ) ENGINE=InnoDB;

    INSERT INTO tmp_question_audit
    SELECT aq.id,aq.question_version_id,es.code,qt.code,aq.points_possible,COALESCE(aq.points_awarded,0),COALESCE(aq.is_correct,0),
           COALESCE((SELECT JSON_ARRAYAGG(aa2.answer_option_id) FROM attempt_answers aa2 WHERE aa2.attempt_question_id=aq.id),JSON_ARRAY()),
           COALESCE((SELECT JSON_ARRAYAGG(ao2.id) FROM answer_options ao2 WHERE ao2.question_version_id=aq.question_version_id AND ao2.is_correct=1),JSON_ARRAY())
      FROM attempt_questions aq
      JOIN exam_sections es ON es.id=aq.section_id
      JOIN question_types qt ON qt.id=aq.question_type_id
     WHERE aq.attempt_id=p_attempt_id;

    SET v_finished_at=CURRENT_TIMESTAMP(6);
    SET v_duration_ms=TIMESTAMPDIFF(MICROSECOND,v_started_at,v_finished_at) DIV 1000;

    INSERT INTO exam_attempt_score_audits(
        attempt_id,audit_no,calculation_type,initiated_by,actor_user_id,reason_code,reason_text,scoring_engine_version,rules_snapshot,
        previous_knowledge_points,previous_skills_points,previous_total_points,
        previous_knowledge_percent,previous_skills_percent,previous_total_percent,
        previous_knowledge_condition_met,previous_skills_condition_met,previous_total_condition_met,previous_passed,
        knowledge_points,skills_points,total_points,knowledge_percent,skills_percent,total_percent,
        knowledge_condition_met,skills_condition_met,total_condition_met,passed,result_changed,score_changed,
        calculation_started_at,calculation_finished_at,calculation_duration_ms
    ) VALUES (
        p_attempt_id,v_audit_no,p_calculation_type,p_initiated_by,p_actor_user_id,p_reason_code,p_reason_text,p_scoring_engine_version,v_rules_snapshot,
        v_prev_knowledge,v_prev_skills,v_prev_total,v_prev_knowledge_pct,v_prev_skills_pct,v_prev_total_pct,
        v_prev_knowledge_met,v_prev_skills_met,v_prev_total_met,v_prev_passed,
        v_knowledge,v_skills,v_total,v_knowledge_pct,v_skills_pct,v_total_pct,
        v_knowledge_met,v_skills_met,v_total_met,v_passed,v_result_changed,v_score_changed,
        v_started_at,v_finished_at,v_duration_ms
    );

    SET v_score_audit_id=LAST_INSERT_ID();

    INSERT INTO exam_attempt_question_score_audits(
        score_audit_id,attempt_question_id,question_version_id,section_code,question_type_code,
        points_possible,points_awarded,is_correct,selected_option_ids,correct_option_ids
    )
    SELECT v_score_audit_id,attempt_question_id,question_version_id,section_code,question_type_code,
           points_possible,points_awarded,is_correct,selected_option_ids,correct_option_ids
      FROM tmp_question_audit;

    UPDATE exam_attempts SET
        knowledge_points=v_knowledge,skills_points=v_skills,total_points=v_total,
        knowledge_percent=v_knowledge_pct,skills_percent=v_skills_pct,total_percent=v_total_pct,
        knowledge_condition_met=v_knowledge_met,skills_condition_met=v_skills_met,total_condition_met=v_total_met,
        passed=v_passed,current_score_audit_id=v_score_audit_id,status='scored',
        submitted_at=COALESCE(submitted_at,CURRENT_TIMESTAMP),scored_at=CURRENT_TIMESTAMP
     WHERE id=p_attempt_id;

    DROP TEMPORARY TABLE tmp_question_audit;
    COMMIT;

    SELECT p_attempt_id AS attempt_id,v_score_audit_id AS score_audit_id,v_audit_no AS audit_no,
           v_knowledge AS knowledge_points,v_knowledge_max AS knowledge_max_points,v_knowledge_pct AS knowledge_percent,v_knowledge_met AS knowledge_condition_met,
           v_skills AS skills_points,v_skills_max AS skills_max_points,v_skills_pct AS skills_percent,v_skills_met AS skills_condition_met,
           v_total AS total_points,v_total_max AS total_max_points,v_total_pct AS total_percent,v_total_met AS total_condition_met,
           v_passed AS passed,v_score_changed AS score_changed,v_result_changed AS result_changed,v_duration_ms AS calculation_duration_ms;
END$$
DELIMITER ;
