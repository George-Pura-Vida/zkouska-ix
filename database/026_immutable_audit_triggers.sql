DROP TRIGGER IF EXISTS trg_score_audit_no_update;
DROP TRIGGER IF EXISTS trg_score_audit_no_delete;
DROP TRIGGER IF EXISTS trg_question_score_audit_no_update;
DROP TRIGGER IF EXISTS trg_question_score_audit_no_delete;

DELIMITER $$
CREATE TRIGGER trg_score_audit_no_update
BEFORE UPDATE ON exam_attempt_score_audits
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Auditní záznam vyhodnocení je neměnný a nelze jej aktualizovat.';
END$$

CREATE TRIGGER trg_score_audit_no_delete
BEFORE DELETE ON exam_attempt_score_audits
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Auditní záznam vyhodnocení je neměnný a nelze jej odstranit.';
END$$

CREATE TRIGGER trg_question_score_audit_no_update
BEFORE UPDATE ON exam_attempt_question_score_audits
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Auditní záznam otázky je neměnný a nelze jej aktualizovat.';
END$$

CREATE TRIGGER trg_question_score_audit_no_delete
BEFORE DELETE ON exam_attempt_question_score_audits
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Auditní záznam otázky je neměnný a nelze jej odstranit.';
END$$
DELIMITER ;
