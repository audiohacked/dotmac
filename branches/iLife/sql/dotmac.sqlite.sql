CREATE TABLE auth (
id INTEGER  PRIMARY KEY AUTOINCREMENT,
username VARCHAR(32) ,
realm VARCHAR(128) default 'idisk.mac.com',
idisk_quota_limit INT default 2048000,
mail_quota_limit INT default 1024000,
is_admin INT default 0,
is_idisk INT default 1,
email_addr VARCHAR(255) 
);
CREATE TABLE delta (
user VARCHAR(32) ,
opcode VARCHAR(4) ,
source MEDIUMTEXT ,
destination MEDIUMTEXT ,
timestamp INTEGER 
);
