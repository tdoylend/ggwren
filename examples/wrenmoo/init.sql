CREATE TABLE Object (
    id              INTEGER PRIMARY KEY,
    name            TEXT,
    flags           TEXT,
    owner           INTEGER,
    parent          INTEGER,
    location        INTEGER
);

CREATE INDEX idx_object_by_location ON Object(location);

CREATE TABLE Property (
    object          INTEGER,
    name            TEXT,
    value           TEXT,
    flags           TEXT
);

CREATE INDEX idx_property_by_object_and_name ON Property(object, name);

CREATE TABLE Verb (
    object          INTEGER,
    name            TEXT,
    source          TEXT,
    grammar         TEXT,
    compiled        TEXT
);

CREATE INDEX idx_verb_by_object_and_name ON Verb(object, name);

CREATE TABLE Configuration (
    key             TEXT PRIMARY KEY,
    value           TEXT
) WITHOUT ROWID;

INSERT INTO Configuration(key, value) VALUES ('db_version', '1.0.0');

INSERT INTO Object(id, name, flags, owner, parent, location) VALUES (1, 'root',   'g', 0, 0, 0);
INSERT INTO Object(id, name, flags, owner, parent, location) VALUES (2, 'player', 'g', 0, 0, 0);
INSERT INTO Object(id, name, flags, owner, parent, location) VALUES (3, 'room',   'g', 0, 0, 0);
INSERT INTO Object(id, name, flags, owner, parent, location) VALUES (4, 'exit',   'g', 0, 0, 0);
INSERT INTO Object(id, name, flags, owner, parent, location) VALUES (5, 'item',   'g', 0, 0, 0);

INSERT INTO Object(id, name, flags, owner, parent, location) VALUES (10, 'Green Room', '', 0, 3, 0);

INSERT INTO Object(name, flags, owner, parent, location) VALUES ('Guest_Cedar', 'G', 0, 2, 0);
INSERT INTO Object(name, flags, owner, parent, location) VALUES ('Guest_Redwood', 'G', 0, 2, 0);
INSERT INTO Object(name, flags, owner, parent, location) VALUES ('Guest_Spruce', 'G', 0, 2, 0);
INSERT INTO Object(name, flags, owner, parent, location) VALUES ('Guest_Pine', 'G', 0, 2, 0);
INSERT INTO Object(name, flags, owner, parent, location) VALUES ('Guest_Cherry', 'G', 0, 2, 0);
INSERT INTO Object(name, flags, owner, parent, location) VALUES ('Guest_Rowan', 'G', 0, 2, 0);

INSERT INTO Property(object, name, value, flags) VALUES (10, 'description',
'Brightly lit with overhead fluorescence, the Green Room has the slight chill of industrial ' ||
'air conditioning and pre-show nervousness. During intermission, they will sell snacks here, and '||
'these are arrayed on tables at one side of the room. The checkered floor squeaks under your ' ||
'boots, and through the thick wall you can faintly hear the clatter as the Murderers and Banquo '||
'practice yet again.' || CHAR(10) || CHAR(10) || 'It is 4:30 PM; the show starts in three hours.'
,'');

INSERT INTO Configuration(key, value) VALUES ('free_id', (SELECT MAX(id)+1 FROM Object));
INSERT INTO Configuration(key, value) VALUES ('guest_storage', 0);
INSERT INTO Configuration(key, value) VALUES ('default_home', 10);
INSERT INTO Configuration(key, value) VALUES ('spawn', 10);

INSERT INTO Configuration(key, value) VALUES ('welcome', 'Please type "login" to log in, or ' ||
'"guest" to enter the game as a guest.');
