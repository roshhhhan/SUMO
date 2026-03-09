CREATE DATABASE IF NOT EXISTS sumo;

USE sumo;

CREATE TABLE IF NOT EXISTS brackets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  structure JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DROP USER IF EXISTS 'sumo_app'@'localhost';
CREATE USER 'sumo_app'@'localhost' IDENTIFIED BY 'sumo_password';
GRANT ALL PRIVILEGES ON sumo.* TO 'sumo_app'@'localhost';
FLUSH PRIVILEGES;

SELECT 'Setup complete!' as status;
