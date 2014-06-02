BEGIN;
delete FROM  soop.soop_platforms CASCADE;
ALTER SEQUENCE  soop.soop_platforms_pkid_seq
INCREMENT 1
MINVALUE 1
START 1
RESTART
CACHE 1;
INSERT INTO soop.soop_platforms(platform_code)
VALUES ('RV Solander');
INSERT INTO soop.soop_platforms(platform_code)
VALUES ('RV Cape Ferguson');
COMMIT;
BEGIN;
delete FROM  soop.soop_parameters CASCADE;
ALTER SEQUENCE  soop.soop_parameters_pkid_seq
INCREMENT 1
MINVALUE 1
START 1
RESTART
CACHE 1;
