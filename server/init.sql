-- Initialize sumo database and create app user
CREATE DATABASE IF NOT EXISTS sumo;
USE sumo;

-- Create brackets table
CREATE TABLE IF NOT EXISTS brackets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  structure JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create app user with password (replace 'sumo_password' if desired)
-- This statement will be skipped if the user already exists
DROP USER IF EXISTS 'sumo_app'@'localhost';
CREATE USER 'sumo_app'@'localhost' IDENTIFIED BY 'sumo_password';
GRANT ALL PRIVILEGES ON sumo.* TO 'sumo_app'@'localhost';
FLUSH PRIVILEGES;

-- Also allow root to connect (reset permissions)
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'root' WITH GRANT OPTION;
FLUSH PRIVILEGES;

SELECT 'Setup complete! Users ready.' as status;
