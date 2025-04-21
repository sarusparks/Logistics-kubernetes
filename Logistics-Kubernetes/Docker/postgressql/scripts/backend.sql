-- Grant all privileges to the `admin` user
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Ensure privileges are applied
FLUSH PRIVILEGES;