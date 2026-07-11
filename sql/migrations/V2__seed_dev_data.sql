INSERT INTO person (full_name, headline, email, location, summary) VALUES
  ('Jane Doe', 'Full-Stack Engineer', 'jane.doe@example.com', 'Remote', 'Demo seed record for local development.');

INSERT INTO skill (name, category) VALUES
  ('Java', 'Backend'),
  ('Spring Boot', 'Backend'),
  ('Node.js', 'Backend'),
  ('React', 'Frontend'),
  ('Terraform', 'Infra');

INSERT INTO person_skill (person_id, skill_id, proficiency)
SELECT p.id, s.id, 'ADVANCED'
FROM person p, skill s
WHERE p.email = 'jane.doe@example.com';
