CREATE TABLE auth (
  id INTEGER  PRIMARY KEY AUTOINCREMENT,
  username VARCHAR(32) ,
  realm VARCHAR(128) default 'idisk.mac.com',
  passwd VARCHAR(128),
  idisk_quota_limit INT default 0,
  mail_quota_limit INT default 0,
  is_admin INT default 0,
  is_idisk INT default 1,
  email_addr VARCHAR(255),
  firstname VARCHAR(128),
  lastname VARCHAR(128),
  created DATE
);
CREATE TABLE commentProperties (
  user INTEGER NOT NULL
    CONSTRAINT fk_commentProperties_user REFERENCES auth(id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  properties TEXT NOT NULL,
  PRIMARY KEY(user, path)
);
CREATE TABLE commentTag (
  user INTEGER NOT NULL PRIMARY KEY
    CONSTRAINT fk_commentTag_user REFERENCES auth(id) ON DELETE CASCADE,
  tag INT
);
CREATE TABLE comments (
  user INTEGER NOT NULL
    CONSTRAINT fk_comments_user REFERENCES auth(id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  commentID TEXT NOT NULL,
  tag INT NOT NULL,
  comment TEXT NOT NULL,
  PRIMARY KEY(user, path, commentID)
);
CREATE TABLE delta (
user VARCHAR(32) ,
opcode VARCHAR(4) ,
source MEDIUMTEXT ,
destination MEDIUMTEXT ,
timestamp INTEGER 
);
CREATE TRIGGER ai_auth_createDate
AFTER INSERT ON auth
BEGIN
UPDATE auth SET created = DATETIME('NOW') WHERE rowid = new.rowid;
END;
CREATE TRIGGER fkdc_commentProperties_user_auth_id
BEFORE DELETE ON auth
FOR EACH ROW BEGIN
    DELETE FROM commentProperties WHERE commentProperties.user = OLD.id;
END;
CREATE TRIGGER fkdc_commentTag_user_auth_id
BEFORE DELETE ON auth
FOR EACH ROW BEGIN
    DELETE FROM commentTag WHERE commentTag.user = OLD.id;
END;
CREATE TRIGGER fkdc_comments_user_auth_id
BEFORE DELETE ON auth
FOR EACH ROW BEGIN
    DELETE FROM comments WHERE comments.user = OLD.id;
END;
CREATE TRIGGER fki_commentProperties_user_auth_id
BEFORE INSERT ON [commentProperties]
FOR EACH ROW BEGIN
  SELECT RAISE(ROLLBACK, 'insert on table "commentProperties" violates foreign key constraint "fki_commentProperties_user_auth_id"')
  WHERE (SELECT id FROM auth WHERE id = NEW.user) IS NULL;
END;
CREATE TRIGGER fki_commentTag_user_auth_id
BEFORE INSERT ON [commentTag]
FOR EACH ROW BEGIN
  SELECT RAISE(ROLLBACK, 'insert on table "commentTag" violates foreign key constraint "fki_commentTag_user_auth_id"')
  WHERE (SELECT id FROM auth WHERE id = NEW.user) IS NULL;
END;
CREATE TRIGGER fki_comments_user_auth_id
BEFORE INSERT ON [comments]
FOR EACH ROW BEGIN
  SELECT RAISE(ROLLBACK, 'insert on table "comments" violates foreign key constraint "fki_comments_user_auth_id"')
  WHERE (SELECT id FROM auth WHERE id = NEW.user) IS NULL;
END;
CREATE TRIGGER fku_commentProperties_user_auth_id
BEFORE UPDATE ON [commentProperties]
FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'update on table "commentProperties" violates foreign key constraint "fku_commentProperties_user_auth_id"')
      WHERE (SELECT id FROM auth WHERE id = NEW.user) IS NULL;
END;
CREATE TRIGGER fku_commentTag_user_auth_id
BEFORE UPDATE ON [commentTag]
FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'update on table "commentTag" violates foreign key constraint "fku_commentTag_user_auth_id"')
      WHERE (SELECT id FROM auth WHERE id = NEW.user) IS NULL;
END;
CREATE TRIGGER fku_comments_user_auth_id
BEFORE UPDATE ON [comments]
FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'update on table "comments" violates foreign key constraint "fku_comments_user_auth_id"')
      WHERE (SELECT id FROM auth WHERE id = NEW.user) IS NULL;
END;
