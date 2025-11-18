-- =========================================================
-- MEDTRAIN – Full Schema + Seed (idempotent; first-time ready)
-- compatible with: risk/skill(training uses name+level)/training_material
-- =========================================================
BEGIN;

-- ---------- Roles & basic access ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='web_anon') THEN
    CREATE ROLE web_anon NOLOGIN;
  END IF;
END$$;

GRANT USAGE ON SCHEMA public TO web_anon;

-- ---------- Tables ----------
CREATE TABLE IF NOT EXISTS risk (
  id          SERIAL PRIMARY KEY,
  code        TEXT UNIQUE NOT NULL,
  title       TEXT NOT NULL,
  severity    INT  NOT NULL CHECK (severity BETWEEN 1 AND 5),
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS skill (
  id          SERIAL PRIMARY KEY,
  code        TEXT UNIQUE NOT NULL,
  name        TEXT NOT NULL,
  level       INT CHECK (level BETWEEN 1 AND 5),
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS training_material (
  id          SERIAL PRIMARY KEY,
  code        TEXT UNIQUE NOT NULL,
  title       TEXT NOT NULL,
  type        TEXT NOT NULL,                 -- e.g., pdf/video/doc/slide
  format      TEXT,                          -- optional: PDF/MP4/etc.
  url         TEXT,
  description TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- M:N links
CREATE TABLE IF NOT EXISTS risk_skill (
  risk_id  INT NOT NULL,
  skill_id INT NOT NULL,
  PRIMARY KEY (risk_id, skill_id)
);

CREATE TABLE IF NOT EXISTS skill_training (
  skill_id             INT NOT NULL,
  training_material_id INT NOT NULL,
  PRIMARY KEY (skill_id, training_material_id)
);

-- ---------- Foreign keys (CASCADE) ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_risk_skill_risk') THEN
    ALTER TABLE risk_skill
      ADD CONSTRAINT fk_risk_skill_risk
      FOREIGN KEY (risk_id) REFERENCES risk(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_risk_skill_skill') THEN
    ALTER TABLE risk_skill
      ADD CONSTRAINT fk_risk_skill_skill
      FOREIGN KEY (skill_id) REFERENCES skill(id) ON DELETE CASCADE;
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_skill_training_skill') THEN
    ALTER TABLE skill_training
      ADD CONSTRAINT fk_skill_training_skill
      FOREIGN KEY (skill_id) REFERENCES skill(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_skill_training_tm') THEN
    ALTER TABLE skill_training
      ADD CONSTRAINT fk_skill_training_tm
      FOREIGN KEY (training_material_id) REFERENCES training_material(id) ON DELETE CASCADE;
  END IF;
END$$;

-- ---------- Indexes ----------
CREATE INDEX IF NOT EXISTS idx_risk_code ON risk(code);
CREATE INDEX IF NOT EXISTS idx_skill_code ON skill(code);
CREATE INDEX IF NOT EXISTS idx_tm_code   ON training_material(code);
CREATE INDEX IF NOT EXISTS idx_rs_risk   ON risk_skill(risk_id);
CREATE INDEX IF NOT EXISTS idx_rs_skill  ON risk_skill(skill_id);
CREATE INDEX IF NOT EXISTS idx_st_skill  ON skill_training(skill_id);
CREATE INDEX IF NOT EXISTS idx_st_tm     ON skill_training(training_material_id);

-- ---------- updated_at triggers ----------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='tr_risk_set_updated_at') THEN
    CREATE TRIGGER tr_risk_set_updated_at
    BEFORE UPDATE ON risk
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='tr_skill_set_updated_at') THEN
    CREATE TRIGGER tr_skill_set_updated_at
    BEFORE UPDATE ON skill
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='tr_tm_set_updated_at') THEN
    CREATE TRIGGER tr_tm_set_updated_at
    BEFORE UPDATE ON training_material
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END$$;

-- ---------- Default privileges & grants ----------
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO web_anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES     IN SCHEMA public TO web_anon;
GRANT USAGE,  SELECT                    ON ALL SEQUENCES IN SCHEMA public TO web_anon;

-- ---------- Seeds (UPSERT safe) ----------
INSERT INTO risk (code, title, severity, description) VALUES
('R-001','Incorrect device calibration',5,'High severity: may cause patient harm'),
('R-002','Missing cleaning protocol',4,'Potential contamination risk'),
('R-003','Outdated training material',3,'Needs review and update')
ON CONFLICT (code) DO UPDATE
  SET title=EXCLUDED.title, severity=EXCLUDED.severity, description=EXCLUDED.description;

INSERT INTO skill (code, name, level, description) VALUES
('S-001','Operate calibration tool',3,'Intermediate'),
('S-002','Maintain device cleaning log',2,'Record-keeping'),
('S-003','Apply cleaning standards',2,'Basic'),
('S-004','Revise training content',2,'Editorial')
ON CONFLICT (code) DO UPDATE
  SET name=EXCLUDED.name, level=EXCLUDED.level, description=EXCLUDED.description;

INSERT INTO training_material (code, title, type, format, url, description) VALUES
('TM-001','Calibration SOP v1','pdf','PDF','https://example.com/tm001','SOP document'),
('TM-002','Calibration Video','video','MP4','https://example.com/tm002','Walkthrough'),
('TM-003','Traceability checklist','doc','DOCX','https://example.com/tm003','Inspection points'),
('TM-005','Cleaning SOP v2','pdf','PDF','https://example.com/tm005','PDF document')
ON CONFLICT (code) DO UPDATE
  SET title=EXCLUDED.title, type=EXCLUDED.type, format=EXCLUDED.format,
      url=EXCLUDED.url, description=EXCLUDED.description;

-- Links: risk -> skill
INSERT INTO risk_skill (risk_id, skill_id)
SELECT r.id, s.id FROM risk r, skill s WHERE r.code='R-001' AND s.code='S-003'
ON CONFLICT DO NOTHING;
INSERT INTO risk_skill (risk_id, skill_id)
SELECT r.id, s.id FROM risk r, skill s WHERE r.code='R-002' AND s.code='S-002'
ON CONFLICT DO NOTHING;

-- Links: skill -> training_material
INSERT INTO skill_training (skill_id, training_material_id)
SELECT s.id, t.id FROM skill s, training_material t WHERE s.code='S-003' AND t.code='TM-002'
ON CONFLICT DO NOTHING;
INSERT INTO skill_training (skill_id, training_material_id)
SELECT s.id, t.id FROM skill s, training_material t WHERE s.code='S-001' AND t.code='TM-001'
ON CONFLICT DO NOTHING;
INSERT INTO skill_training (skill_id, training_material_id)
SELECT s.id, t.id FROM skill s, training_material t WHERE s.code='S-004' AND t.code='TM-003'
ON CONFLICT DO NOTHING;

-- ---------- Views ----------
-- roll-up for UI
CREATE OR REPLACE VIEW risk_traceability AS
SELECT r.id, r.code AS risk, r.title, r.severity,
       array_remove(array_agg(DISTINCT s.code), NULL) AS skills,
       array_remove(array_agg(DISTINCT t.code), NULL) AS materials
FROM risk r
LEFT JOIN risk_skill rs ON rs.risk_id = r.id
LEFT JOIN skill s ON s.id = rs.skill_id
LEFT JOIN skill_training st ON st.skill_id = s.id
LEFT JOIN training_material t ON t.id = st.training_material_id
GROUP BY r.id, r.code, r.title, r.severity
ORDER BY r.severity DESC, r.code;

-- checks & reports for the UI
CREATE OR REPLACE VIEW v_risks_without_skills AS
SELECT r.id, r.code
FROM risk r
LEFT JOIN risk_skill rs ON rs.risk_id = r.id
WHERE rs.risk_id IS NULL;

CREATE OR REPLACE VIEW v_risks_without_materials AS
SELECT r.id, r.code
FROM risk r
LEFT JOIN risk_skill rs ON rs.risk_id = r.id
LEFT JOIN skill_training st ON st.skill_id = rs.skill_id
WHERE st.training_material_id IS NULL;

CREATE OR REPLACE VIEW v_orphan_skills AS
SELECT s.id, s.code
FROM skill s
LEFT JOIN risk_skill rs ON rs.skill_id = s.id
WHERE rs.skill_id IS NULL;

CREATE OR REPLACE VIEW v_orphan_materials AS
SELECT t.id, t.code
FROM training_material t
LEFT JOIN skill_training st ON st.training_material_id = t.id
WHERE st.training_material_id IS NULL;

-- ---------- Grants for views ----------
GRANT SELECT ON
  risk_traceability, v_risks_without_skills, v_risks_without_materials, v_orphan_skills, v_orphan_materials
TO web_anon;

COMMIT;
