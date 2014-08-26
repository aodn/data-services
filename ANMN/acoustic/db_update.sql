SET search_path = anmn, public;


-- Add foreign key constraint to acoustic_spectrograms
ALTER TABLE acoustic_spectrograms 
  ADD CONSTRAINT spec2dep FOREIGN KEY (acoustic_deploy_fk) 
  REFERENCES acoustic_deployments(pkid) MATCH SIMPLE 
  ON UPDATE CASCADE ON DELETE CASCADE;


-- Add cascade to foreign key constraint on acoustic_recordings
ALTER TABLE acoustic_recordings DROP CONSTRAINT rec2spec ;

ALTER TABLE acoustic_recordings 
  ADD CONSTRAINT rec_spec_fk FOREIGN KEY (acoustic_spec_fk)
  REFERENCES acoustic_spectrograms (pkid) MATCH SIMPLE
  ON UPDATE CASCADE ON DELETE CASCADE;

-- need to re-create index fki_rec2spec too ???


-- Add last updated column to acoustic_spectrograms
ALTER TABLE acoustic_spectrograms 
  ADD COLUMN last_updated timestamp with time zone DEFAULT CURRENT_TIMESTAMP(0);

UPDATE acoustic_spectrograms SET last_updated = NULL;

