DROP TABLE IF EXISTS `auth`;
CREATE TABLE auth (
  id INTEGER  PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(32) ,
  realm VARCHAR(128) default 'idisk.mac.com',
  passwd VARCHAR(128),
  idisk_quota_limit INT default 0,
  mail_quota_limit INT default 0,
  is_admin INT default 0,
  is_idisk INT default 1,
  email_addr VARCHAR(255) default null,
  firstname VARCHAR(128) default null,
  lastname VARCHAR(128) default null,
  created DATE
) ENGINE=INNODB;

DROP TABLE IF EXISTS `commentProperties`;
CREATE TABLE commentProperties (
  user INTEGER NOT NULL,
  path VARCHAR(255) NOT NULL,
  properties VARCHAR(255) NOT NULL,
  INDEX fk_commentProperties_user (user),
  FOREIGN KEY (user) REFERENCES auth(id) ON DELETE CASCADE,
  PRIMARY KEY (user, path)
) ENGINE=INNODB;

DROP TABLE IF EXISTS `commentTag`;
CREATE TABLE commentTag (
  user INTEGER NOT NULL PRIMARY KEY,
  tag INT,
  INDEX fk_commentTag_user (user),
  FOREIGN KEY (user) REFERENCES auth(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS `comments`;
CREATE TABLE comments (
  user INTEGER NOT NULL,
  path VARCHAR(255) NOT NULL,
  commentID VARCHAR(10) NOT NULL,
  tag INT NOT NULL,
  comment VARCHAR(255) NOT NULL,
  PRIMARY KEY(user, path, commentID),
  INDEX fk_comments_user (user),
  FOREIGN KEY (user) REFERENCES auth(id) ON DELETE CASCADE
);

DROP TABLE IF EXISTS `delta`;
CREATE TABLE delta (
user VARCHAR(32) ,
opcode VARCHAR(4) ,
source MEDIUMTEXT ,
destination MEDIUMTEXT ,
timestamp INTEGER 
);


DELIMITER //
CREATE TRIGGER `ai_auth_createDate`
BEFORE INSERT ON `auth`
FOR EACH ROW BEGIN
	SET NEW.created = DATE('NOW');
END//

CREATE TRIGGER fkdc_user_auth_id
BEFORE DELETE ON auth
FOR EACH ROW BEGIN
    DELETE FROM commentProperties WHERE commentProperties.user = OLD.id;
    DELETE FROM commentTag WHERE commentTag.user = OLD.id;
    DELETE FROM comments WHERE comments.user = OLD.id;
END//

CREATE TRIGGER fki_commentProperties_user_auth_id
BEFORE INSERT ON commentProperties
FOR EACH ROW BEGIN
  SET @fki_id = (SELECT id FROM auth WHERE id = NEW.user);
END//

CREATE TRIGGER fki_commentTag_user_auth_id
BEFORE INSERT ON commentTag
FOR EACH ROW BEGIN
  SET @fki_id = (SELECT id FROM auth WHERE id = NEW.user);
END//

CREATE TRIGGER fki_comments_user_auth_id
BEFORE INSERT ON comments
FOR EACH ROW BEGIN
  SET @fki_id = (SELECT id FROM auth WHERE id = NEW.user);
END//

CREATE TRIGGER fku_commentProperties_user_auth_id
BEFORE UPDATE ON commentProperties
FOR EACH ROW BEGIN
  SET @fki_id = (SELECT id FROM auth WHERE id = NEW.user);
END//

CREATE TRIGGER fku_commentTag_user_auth_id
BEFORE UPDATE ON commentTag
FOR EACH ROW BEGIN
  SET @fki_id = (SELECT id FROM auth WHERE id = NEW.user);
END//

CREATE TRIGGER fku_comments_user_auth_id
BEFORE UPDATE ON comments
FOR EACH ROW BEGIN
  SET @fki_id = (SELECT id FROM auth WHERE id = NEW.user);
END//
