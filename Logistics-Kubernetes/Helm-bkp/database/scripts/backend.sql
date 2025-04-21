-- Create the admin user with a password
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'Admin@123';

-- Grant all privileges to the `admin` user
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Ensure privileges are applied
FLUSH PRIVILEGES;