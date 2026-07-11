CREATE TABLE person (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  headline VARCHAR(200),
  email VARCHAR(150) NOT NULL UNIQUE,
  phone VARCHAR(30),
  location VARCHAR(150),
  summary TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE experience (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  person_id BIGINT NOT NULL,
  company VARCHAR(150) NOT NULL,
  role VARCHAR(150) NOT NULL,
  location VARCHAR(150),
  start_date DATE NOT NULL,
  end_date DATE,
  description TEXT,
  CONSTRAINT fk_experience_person FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

CREATE TABLE education (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  person_id BIGINT NOT NULL,
  institution VARCHAR(150) NOT NULL,
  degree VARCHAR(150) NOT NULL,
  field_of_study VARCHAR(150),
  start_date DATE NOT NULL,
  end_date DATE,
  CONSTRAINT fk_education_person FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

CREATE TABLE skill (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  category VARCHAR(100)
);

CREATE TABLE person_skill (
  person_id BIGINT NOT NULL,
  skill_id BIGINT NOT NULL,
  proficiency ENUM('BEGINNER','INTERMEDIATE','ADVANCED','EXPERT') NOT NULL DEFAULT 'INTERMEDIATE',
  PRIMARY KEY (person_id, skill_id),
  CONSTRAINT fk_person_skill_person FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
  CONSTRAINT fk_person_skill_skill FOREIGN KEY (skill_id) REFERENCES skill(id) ON DELETE CASCADE
);

CREATE TABLE project (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  person_id BIGINT NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  repo_url VARCHAR(255),
  start_date DATE,
  end_date DATE,
  CONSTRAINT fk_project_person FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);
