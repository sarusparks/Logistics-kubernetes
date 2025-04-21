# README: Configuring MySQL Master-Slave Replication and ProxySQL on Amazon Linux 2023

## **1. Install and Configure MySQL Master**

### **Step 1: Install MySQL on the Master**
```sh
# Retrieve MySQL RPM package
sudo wget https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm

# Import MySQL GPG Key
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023

# Install MySQL repository and server
sudo yum install mysql80-community-release-el9-1.noarch.rpm -y
sudo yum install mysql-community-server -y

# Start MySQL service
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Check MySQL service status
sudo systemctl status mysqld
```

### **Step 2: Retrieve and Set MySQL Root Password**
```sh
# Retrieve the temporary password
sudo grep 'temporary password' /var/log/mysqld.log

# Log in to MySQL as root
mysql -u root -p

# Change root password
ALTER USER 'root'@'localhost' IDENTIFIED BY 'Admin@123';

# Verify MySQL version
SELECT VERSION();
```

### **Step 3: Configure MySQL Master**
```sh
# Edit MySQL configuration file
sudo vi /etc/my.cnf
```
Add the following lines:
```
[mysqld]
server-id=1
log-bin=mysql-bin
binlog-format=ROW
```
Restart MySQL:
```sh
sudo systemctl restart mysqld
```

### **Step 4: Create Replication User and Get Master Status**
```sql
CREATE USER 'replica'@'%' IDENTIFIED BY 'Admin@123';
GRANT REPLICATION SLAVE ON *.* TO 'replica'@'%';
FLUSH PRIVILEGES;

# Get master status
SHOW MASTER STATUS;
```
Note down the **File** and **Position** values from `SHOW MASTER STATUS`.

---

## **2. Install and Configure MySQL Replica**

### **Step 1: Install MySQL on the Replica**
Follow the same MySQL installation steps as the master.

### **Step 2: Configure MySQL Replica**
```sh
# Edit MySQL configuration file
sudo vi /etc/my.cnf
```
Add the following lines:
```
[mysqld]
server-id=2
log-bin=mysql-bin
binlog-format=ROW
```
Restart MySQL:
```sh
sudo systemctl restart mysqld
```

### **Step 3: Configure Replication**
```sql
CHANGE MASTER TO
MASTER_HOST='172.31.84.119',
MASTER_USER='replica',
MASTER_PASSWORD='Admin@123',
MASTER_LOG_FILE='mysql-bin.000001',
MASTER_LOG_POS=863;

START SLAVE;
SHOW SLAVE STATUS\G;
```
If you get an authentication error:
```sql
ALTER USER 'replica'@'%' IDENTIFIED WITH mysql_native_password BY 'Admin@123';
FLUSH PRIVILEGES;
```
Ensure `Slave_IO_Running` and `Slave_SQL_Running` are `Yes` in `SHOW SLAVE STATUS;`

---

## **3. Install and Configure ProxySQL**

### **Step 1: Install ProxySQL**
```sh
sudo su -

# Create ProxySQL repo
cat <<EOF | tee /etc/yum.repos.d/proxysql.repo
[proxysql_repo]
name=ProxySQL repository
baseurl=https://repo.proxysql.com/ProxySQL/proxysql-2.7.x/centos/8
gpgcheck=1
gpgkey=https://repo.proxysql.com/ProxySQL/proxysql-2.7.x/repo_pub_key
EOF

# Install ProxySQL
yum install proxysql

# Start ProxySQL service
sudo systemctl start proxysql
sudo systemctl enable proxysql

# Check ProxySQL status
sudo systemctl status proxysql
```

### **Step 2: Configure ProxySQL**

#### **Connect to ProxySQL Admin Interface**
```sh
mysql -u admin -p -h 127.0.0.1 -P 6032
```
(Default password: `admin`)

#### **If `mysql` command is not found:**
```sh
sudo yum install mysql-community-client -y
```

#### **Add MySQL Servers to ProxySQL**
```sql
-- Add Master (writes)
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight) VALUES (10, '172.31.84.119', 3306, 1);

-- Add Replica (reads)
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight) VALUES (20, '172.31.89.163', 3306, 1);

-- Apply changes
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
```

#### **Configure Read/Write Query Routing**
```sql
-- Read queries go to replicas
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) VALUES (1, 1, '^SELECT.*', 20, 1);

-- Write queries go to master
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) VALUES (2, 1, '^(INSERT|UPDATE|DELETE|REPLACE|ALTER|CREATE|DROP).*', 10, 1);

-- Apply changes
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
```

#### **Configure Application User in ProxySQL**
```sql
INSERT INTO mysql_users (username, password, default_hostgroup) VALUES ('app_user', 'AppPassword@123', 10);

-- Apply changes
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
```

#### **Grant Permissions on Master**
```sql
CREATE USER 'app_user'@'%' IDENTIFIED BY 'AppPassword@123';
GRANT ALL PRIVILEGES ON production.* TO 'app_user'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'app_user'@'%';
FLUSH PRIVILEGES;
```

---

## **4. Verify ProxySQL Setup**

#### **Check ProxySQL Backend Servers**
```sql
SELECT * FROM runtime_mysql_servers;
```

#### **Monitor ProxySQL Metrics**
```sql
SELECT * FROM stats_mysql_connection_pool;
SELECT hostgroup_id, hostname, status FROM mysql_servers;
SELECT * FROM stats_mysql_query_digest ORDER BY last_seen DESC;
```

#### **Monitor MySQL Replication**
```sql
SHOW SLAVE STATUS\G;
SHOW MASTER STATUS;
```

#### **Test Application Connection**
```sh
mysql -u app_user -pAppPassword@123 -h 127.0.0.1 -P 6033
```

---

## **5. Conclusion**
This guide sets up a **MySQL Master-Slave Replication with ProxySQL** for **read/write splitting**. You can now scale MySQL efficiently by directing read traffic to replicas and write traffic to the master.

