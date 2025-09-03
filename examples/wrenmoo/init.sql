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

CREATE INDEX idx_verb_by_object ON Verb(object);
CREATE INDEX idx_verb_by_name   ON Verb(name);

CREATE TABLE Configuration (
    key             TEXT PRIMARY KEY,
    value           TEXT
) WITHOUT ROWID;

INSERT INTO Configuration(key, value) VALUES ('db_version', '1.0.0');

INSERT INTO Objects(id, name, flags, owner, parent, location) VALUES (1, 'root',   'g', 0, 0, 0);
INSERT INTO Objects(name, flags, owner, parent, location)     VALUES (   'player', 'g', 0, 0, 0);
INSERT INTO Objects(name, flags, owner, parent, location)     VALUES (   'room',   'g', 0, 0, 0);
INSERT INTO Objects(name, flags, owner, parent, location)     VALUES (   'exit',   'g', 0, 0, 0);
INSERT INTO Objects(name, flags, owner, parent, location)     VALUES (   'item',   'g', 0, 0, 0);

INSERT INTO Configuration(key, value) VALUES ('free_id', (
    SELECT MAX(id)+1 FROM Objects
));
