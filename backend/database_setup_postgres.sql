-- PostgreSQL Database Setup for Marathon 2026
-- Converted from MySQL schema
-- Compatible with Railway.app, Render.com, and other PostgreSQL platforms

-- Note: PostgreSQL doesn't need CREATE DATABASE in Railway/Render
-- The database is already created for you

-- Enable UUID extension for ID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Set timezone
SET TIME ZONE 'UTC';

-- --------------------------------------------------------
-- 1. Users Table (Core)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  user_id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(100) DEFAULT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'participant' CHECK (role IN ('participant', 'admin', 'leader')),
  department VARCHAR(100) DEFAULT NULL,
  college VARCHAR(100) DEFAULT NULL,
  phone VARCHAR(20) DEFAULT NULL,
  
  -- Account Status
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'disqualified', 'held', 'suspended')),
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Admin/Leader Approval
  admin_status VARCHAR(20) DEFAULT 'PENDING' CHECK (admin_status IN ('PENDING', 'APPROVED', 'REJECTED')),
  approved_by INTEGER DEFAULT NULL,
  approval_at TIMESTAMP DEFAULT NULL,
  
  -- Meta
  profile_image VARCHAR(255) DEFAULT NULL,
  registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP DEFAULT NULL
);

CREATE INDEX idx_users_role ON users(role);

-- --------------------------------------------------------
-- 2. Contests Table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS contests (
  contest_id SERIAL PRIMARY KEY,
  contest_name VARCHAR(255) NOT NULL,
  description TEXT DEFAULT NULL,
  
  start_datetime TIMESTAMP NOT NULL,
  end_datetime TIMESTAMP NOT NULL,
  
  status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'live', 'paused', 'ended')),
  is_active BOOLEAN DEFAULT TRUE,
  max_violations_allowed INTEGER DEFAULT 5,
  current_round INTEGER DEFAULT 1,
  
  created_by INTEGER DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_contests_creator FOREIGN KEY (created_by) REFERENCES users (user_id) ON DELETE SET NULL
);

CREATE INDEX idx_contests_active ON contests(is_active);

-- --------------------------------------------------------
-- 3. Rounds (Levels) Table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS rounds (
  round_id SERIAL PRIMARY KEY,
  contest_id INTEGER NOT NULL,
  round_name VARCHAR(100) NOT NULL,
  round_number INTEGER NOT NULL,
  
  time_limit_minutes INTEGER NOT NULL,
  total_questions INTEGER NOT NULL,
  passing_score DECIMAL(5,2) DEFAULT NULL,
  
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed')),
  is_locked BOOLEAN DEFAULT TRUE,
  unlock_condition TEXT DEFAULT NULL,
  
  allowed_language VARCHAR(50) DEFAULT 'python',
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_rounds_contest FOREIGN KEY (contest_id) REFERENCES contests (contest_id) ON DELETE CASCADE,
  UNIQUE (contest_id, round_number)
);

-- --------------------------------------------------------
-- 4. Questions Table
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS questions (
  question_id SERIAL PRIMARY KEY,
  round_id INTEGER NOT NULL,
  question_number INTEGER NOT NULL,
  
  question_title VARCHAR(500) NOT NULL,
  question_description TEXT NOT NULL,
  buggy_code TEXT NOT NULL,
  
  expected_output TEXT DEFAULT NULL,
  test_input TEXT DEFAULT NULL,
  test_cases JSONB DEFAULT NULL,
  difficulty_level VARCHAR(20) NOT NULL CHECK (difficulty_level IN ('easy', 'medium', 'hard')),
  
  points INTEGER DEFAULT 10,
  hints TEXT DEFAULT NULL,
  time_estimate_minutes INTEGER DEFAULT NULL,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_questions_round FOREIGN KEY (round_id) REFERENCES rounds (round_id) ON DELETE CASCADE,
  UNIQUE (round_id, question_number)
);

-- --------------------------------------------------------
-- 5. Submissions Table (Results)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS submissions (
  submission_id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  contest_id INTEGER NOT NULL,
  round_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,
  
  submitted_code TEXT DEFAULT NULL,
  is_correct BOOLEAN DEFAULT NULL,
  score_awarded DECIMAL(5,2) DEFAULT 0.00,
  test_results JSONB DEFAULT NULL,
  
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'evaluated', 'failed')),
  time_taken_seconds INTEGER DEFAULT NULL,
  submission_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_sub_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_question FOREIGN KEY (question_id) REFERENCES questions (question_id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_round FOREIGN KEY (round_id) REFERENCES rounds (round_id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_contest FOREIGN KEY (contest_id) REFERENCES contests (contest_id) ON DELETE CASCADE
);

CREATE INDEX idx_submissions_user_contest ON submissions(user_id, contest_id);
CREATE INDEX idx_submissions_perf ON submissions(user_id, contest_id, round_id, is_correct, submission_timestamp);

-- --------------------------------------------------------
-- 6. Participant Level Stats (Progress)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS participant_level_stats (
  stat_id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  contest_id INTEGER NOT NULL,
  level INTEGER NOT NULL,
  
  status VARCHAR(20) DEFAULT 'NOT_STARTED' CHECK (status IN ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED')),
  questions_solved INTEGER DEFAULT 0,
  level_score DECIMAL(5,2) DEFAULT 0.00,
  violation_count INTEGER DEFAULT 0,
  
  start_time TIMESTAMP DEFAULT NULL,
  completed_at TIMESTAMP DEFAULT NULL,
  run_count INTEGER DEFAULT 0,
  
  UNIQUE (user_id, contest_id, level)
);

-- --------------------------------------------------------
-- 7. Proctoring Configuration
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS proctoring_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contest_id INTEGER NOT NULL UNIQUE,
  
  enabled BOOLEAN DEFAULT TRUE,
  max_violations INTEGER DEFAULT 10,
  auto_disqualify BOOLEAN DEFAULT TRUE,
  warning_threshold INTEGER DEFAULT 5,
  grace_violations INTEGER DEFAULT 2,
  strict_mode BOOLEAN DEFAULT FALSE,
  
  -- Monitoring Settings
  track_tab_switches BOOLEAN DEFAULT TRUE,
  track_focus_loss BOOLEAN DEFAULT TRUE,
  block_copy BOOLEAN DEFAULT TRUE,
  block_paste BOOLEAN DEFAULT TRUE,
  block_cut BOOLEAN DEFAULT TRUE,
  block_selection BOOLEAN DEFAULT FALSE,
  block_right_click BOOLEAN DEFAULT TRUE,
  detect_screenshot BOOLEAN DEFAULT TRUE,
  
  -- Penalties
  tab_switch_penalty INTEGER DEFAULT 1,
  copy_paste_penalty INTEGER DEFAULT 2,
  screenshot_penalty INTEGER DEFAULT 3,
  focus_loss_penalty INTEGER DEFAULT 1,
  
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_pc_contest FOREIGN KEY (contest_id) REFERENCES contests (contest_id) ON DELETE CASCADE
);

-- --------------------------------------------------------
-- 8. Participant Proctoring Status
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS participant_proctoring (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  participant_id VARCHAR(100) DEFAULT NULL,
  user_id INTEGER DEFAULT NULL,
  contest_id INTEGER NOT NULL,
  
  risk_level VARCHAR(20) DEFAULT 'low' CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  total_violations INTEGER DEFAULT 0,
  violation_score INTEGER DEFAULT 0,
  extra_violations INTEGER DEFAULT 0,
  
  -- Status Flags
  is_disqualified BOOLEAN DEFAULT FALSE,
  disqualified_at TIMESTAMP DEFAULT NULL,
  disqualification_reason TEXT DEFAULT NULL,
  
  is_suspended BOOLEAN DEFAULT FALSE,
  suspended_at TIMESTAMP DEFAULT NULL,
  suspension_reason TEXT DEFAULT NULL,

  -- Live Monitoring
  last_heartbeat TIMESTAMP DEFAULT NULL,
  client_ip VARCHAR(45) DEFAULT NULL,
  
  -- Violation Counts Breakdown
  tab_switches INTEGER DEFAULT 0,
  focus_losses INTEGER DEFAULT 0,
  copy_attempts INTEGER DEFAULT 0,
  paste_attempts INTEGER DEFAULT 0,
  screenshot_attempts INTEGER DEFAULT 0,
  
  last_violation_at TIMESTAMP DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_pp_contest FOREIGN KEY (contest_id) REFERENCES contests (contest_id) ON DELETE CASCADE,
  CONSTRAINT fk_pp_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  UNIQUE (participant_id, contest_id)
);

-- --------------------------------------------------------
-- 9. Violations Log
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS violations (
  violation_id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  contest_id INTEGER NOT NULL,
  round_id INTEGER DEFAULT NULL,
  question_id INTEGER DEFAULT NULL,
  
  violation_type VARCHAR(50) NOT NULL,
  description TEXT DEFAULT NULL,
  severity VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  penalty_points INTEGER DEFAULT 1,
  
  level INTEGER DEFAULT 1,
  ip_address VARCHAR(45) DEFAULT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_v_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_v_contest FOREIGN KEY (contest_id) REFERENCES contests (contest_id) ON DELETE CASCADE
);

CREATE INDEX idx_violations_tracking ON violations(user_id, contest_id);

-- --------------------------------------------------------
-- 10. Proctoring Logs
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS proctoring_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contest_id INTEGER DEFAULT NULL,
  user_id INTEGER DEFAULT NULL,
  participant_id VARCHAR(100) DEFAULT NULL,
  
  action_type VARCHAR(50) NOT NULL,
  action_by VARCHAR(100) DEFAULT NULL,
  details JSONB DEFAULT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- 11. Shortlisted Participants
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS shortlisted_participants (
    id SERIAL PRIMARY KEY,
    contest_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    level INTEGER NOT NULL,
    is_allowed BOOLEAN DEFAULT TRUE,
    UNIQUE (contest_id, level, user_id)
);

-- --------------------------------------------------------
-- 12. Leaderboard
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS leaderboard (
  leaderboard_id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  contest_id INTEGER NOT NULL,
  
  rank_position INTEGER DEFAULT NULL,
  total_score DECIMAL(7,2) DEFAULT 0.00,
  total_time_taken_seconds INTEGER DEFAULT 0,
  
  questions_attempted INTEGER DEFAULT 0,
  questions_correct INTEGER DEFAULT 0,
  violations_count INTEGER DEFAULT 0,
  current_round INTEGER DEFAULT 1,
  
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  CONSTRAINT fk_lb_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_lb_contest FOREIGN KEY (contest_id) REFERENCES contests (contest_id) ON DELETE CASCADE,
  UNIQUE (user_id, contest_id)
);

-- --------------------------------------------------------
-- 13. Admin State
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_state (
    key_name VARCHAR(100) NOT NULL PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- 14. Proctoring Alerts
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS proctoring_alerts (
  id SERIAL PRIMARY KEY,
  contest_id INTEGER NOT NULL,
  participant_id VARCHAR(100) DEFAULT NULL,
  
  alert_type VARCHAR(50) NOT NULL,
  severity VARCHAR(20) DEFAULT 'warning' CHECK (severity IN ('info', 'warning', 'critical')),
  message TEXT NOT NULL,
  
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------
-- Create trigger for updated_at columns
-- --------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_proctoring_config_updated_at BEFORE UPDATE ON proctoring_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_participant_proctoring_updated_at BEFORE UPDATE ON participant_proctoring
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_state_updated_at BEFORE UPDATE ON admin_state
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leaderboard_updated_at BEFORE UPDATE ON leaderboard
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- --------------------------------------------------------
-- Insert default admin user
-- --------------------------------------------------------
INSERT INTO users (username, email, password_hash, full_name, role, admin_status)
VALUES ('admin', 'admin@marathon.com', 'pbkdf2:sha256:600000$placeholder', 'System Admin', 'admin', 'APPROVED')
ON CONFLICT (username) DO NOTHING;

-- --------------------------------------------------------
-- Insert default contest
-- --------------------------------------------------------
INSERT INTO contests (contest_name, description, start_datetime, end_datetime, status)
VALUES ('Marathon 2026', 'Debug Marathon Contest', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '30 days', 'draft')
ON CONFLICT DO NOTHING;

-- Success message
SELECT 'PostgreSQL schema created successfully!' AS status;
