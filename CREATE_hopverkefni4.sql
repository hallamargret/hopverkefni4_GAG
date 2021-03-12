CREATE TABLE Professions (
    ProfessionID serial PRIMARY KEY,
    description varchar(255) NOT NULL
);

CREATE TABLE Genders (
    GenderID serial PRIMARY KEY,
    gender varchar(255) NOT NULL
);

CREATE TABLE Locations (
    LocationID serial PRIMARY KEY,
    location VARCHAR(255) NOT NULL,
    caseCount int NOT NULL DEFAULT 0
);

CREATE TABLE People (
    PersonID serial PRIMARY KEY,
    name varchar(255),
    ProfessionID int REFERENCES Professions (ProfessionID), /* WorksIn */
    GenderID int REFERENCES Genders (GenderID),
    LocationID int REFERENCES Locations (LocationID) /* LivesIn */
);

CREATE TABLE Agents (
    AgentID serial PRIMARY KEY,
    codename varchar(255),
    designation char(4),
    killLicense boolean NOT NULL,
    status varchar(20),
    secretIdentity int,
    GenderID int,
    FOREIGN KEY (secretIdentity) REFERENCES People (PersonID),
    FOREIGN KEY (GenderID) REFERENCES Genders (GenderID)
);

CREATE TABLE Cases (
    CaseID serial PRIMARY KEY,
    title varchar(255),
    isClosed boolean NOT NULL,
    year smallint,
    AgentID int NOT NULL REFERENCES Agents (AgentID), /* leadBy */
    LocationID int REFERENCES Locations (LocationID) /* happensIn */
);

CREATE TABLE InvolvedIn (
    PersonID int REFERENCES People (PersonID),
    CaseID int REFERENCES Cases (CaseID),
    AgentID int REFERENCES Agents (AgentID), /* investigates */
    isCulprit boolean,
    PRIMARY KEY (PersonID, CaseID)
);

CREATE TABLE Passwords (
    AgentID int PRIMARY KEY,
    username varchar(255) UNIQUE,
    password VARCHAR(255) DEFAULT '[REDACTED]',
    FOREIGN KEY (AgentID) REFERENCES Agents (AgentID) ON DELETE CASCADE ON UPDATE CASCADE
);