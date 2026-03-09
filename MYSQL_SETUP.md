# MySQL Setup Instructions for Sumo Bracket App

## Quick Setup (Recommended)

### Step 1: Start XAMPP MySQL
1. Open **XAMPP Control Panel**
2. Click **Start** next to MySQL (if not already running)

### Step 2: Access phpMyAdmin
1. Open browser → `http://localhost/phpmyadmin`
2. You should be logged in as root automatically

### Step 3: Create Database and User
In phpMyAdmin:
1. Click the **SQL** tab at the top
2. Copy and paste this SQL code:

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS sumo;

-- Create app user
DROP USER IF EXISTS 'sumo_app'@'localhost';
CREATE USER 'sumo_app'@'localhost' IDENTIFIED BY 'sumo_password';
GRANT ALL PRIVILEGES ON sumo.* TO 'sumo_app'@'localhost';
FLUSH PRIVILEGES;

-- Create brackets table
USE sumo;
CREATE TABLE IF NOT EXISTS brackets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  structure JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

3. Click **Execute**

### Step 4: Verify in Server
The server is already configured in `.env` to use:
- **User**: sumo_app
- **Password**: sumo_password  
- **Database**: sumo

Now run the server:
```bash
cd server
dart run bin/server.dart
```

You should see:
```
Connecting to MySQL: host=localhost port=3306 user=sumo_app db=sumo
✓ Connected to MySQL
🚀 Listening on http://0.0.0.0:8080
```

---

## If phpMyAdmin Login Fails

If you can't log into phpMyAdmin, your XAMPP MySQL might be misconfigured:

**Option A: Restart XAMPP**
1. Stop MySQL from XAMPP Control Panel
2. Stop Apache
3. Close XAMPP Control Panel completely  
4. Reopen XAMPP Control Panel
5. Start Apache, then MySQL
6. Try phpMyAdmin again

**Option B: Reset MySQL (Nuclear Option)**
1. Close XAMPP completely
2. Delete the data folder: `C:\xampp\mysql\data` (backup first!)
3. Reopen XAMPP
4. Start MySQL - it will recreate the default database
5. Try phpMyAdmin

---

## Troubleshooting

### Still Getting "Access Denied"?
- Make sure MySQL is running (**Green light in XAMPP Control Panel**)
- Check that you're using the right URL: `http://localhost/phpmyadmin`
- Try clearing browser cache

### Can't Find XAMPP?
- Default location: `C:\xampp`
- Or search for "XAMPP Control Panel" in Windows Start Menu

### Server Still Won't Connect?
Run the test script:
```bash
cd server
dart run bin/test_connection.dart
```

Then the setup script:
```bash
dart run bin/setup_mysql.dart
```

---

## Database Schema

Once connected, your `sumo` database has:
```
brackets table:
  - id (primary key, auto increment)
  - name (tournament name)
  - structure (JSON: the bracket tree with teams and scores)
  - created_at (timestamp)
```

The scoring logic is handled by the Dart server in `bin/server.dart`.
