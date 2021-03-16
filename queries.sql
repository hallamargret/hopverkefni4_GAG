--CREATE DATABASE PIV;


-- 1.
select
    1 as Query;

CREATE OR REPLACE FUNCTION mostCommonLocationAgentCaseLed()





CREATE OR REPLACE VIEW AS infoAgent AS
SELECT A.codename, A.status, COUNT(C.CaseID)
FROM Agents A
NATURAL JOIN Cases C
GROUP BY A.AgentID
HAVING ()


SELECT * FROM infoAgent;



select
    2 as Query;

CREATE OR REPLACE VIEW top3subjectsStokkseyri AS
SELECT P.PersonID, P.name, L.location
FROM People P
INNER JOIN Locations L ON P.LocationID = L.LocationID
INNER JOIN InvolvedIn I ON P.PersonID = I.PersonID
GROUP BY P.PersonID, L.LocationID
HAVING L.location = 'Stokkseyri'
ORDER BY COUNT(distinct I.CaseID) DESC
LIMIT 3;

SELECT * FROM top3subjectsStokkseyri;

-- 3.
CREATE OR REPLACE VIEW allNemeses AS
SELECT DISTINCT ON (P.PersonId) A.AgentID, A.codename, P.PersonID, P.name
FROM People P
INNER JOIN InvolvedIn I ON I.PersonID = P.PersonID
INNER JOIN Agents A ON I.AgentID = A.AgentID
GROUP BY P.PersonID, A.AgentID, I.isCulprit
HAVING I.isCulprit = TRUE AND COUNT(I.isCulprit = TRUE) > 1
ORDER BY P.PersonID, COUNT(A.AgentID) DESC;

--DROP VIEW IF EXISTS allNemeses;


SELECT * FROM allNemeses;

BEGIN;
INSERT INTO InvolvedIn
VALUES(374, 1, 44, true);
INSERT INTO InvolvedIn
VALUES(374, 2, 44, true);

SELECT * FROM allNemeses;

INSERT INTO InvolvedIn
VALUES(374, 3, 22, true);
SELECT * FROM allNemeses;
INSERT INTO InvolvedIn
VALUES(374, 4, 44, true);
SELECT * FROM allNemeses;

ROLLBACK;




-- 4.

CREATE OR REPLACE PROCEDURE InsertPerson(
    Pname_in varchar(255),
    Profession_in varchar(255),
    Gender_in varchar(255),
    Location_in varchar(255)
)
AS
$$
BEGIN
    IF(trim(Pname_in) = '') THEN
        RAISE EXCEPTION 'Name can not be empty!' USING ERRCODE = '45000';
    END IF;
    
    IF(Gender_in NOT IN (SELECT G.gender FROM Genders G)) THEN
        RAISE EXCEPTION 'Gender must be valid (in the gender table)!' USING ERRCODE = '45000';
    END IF;

    IF(Location_in NOT IN (SELECT L.location FROM Locations L)) THEN
        RAISE EXCEPTION 'Location must be valid (in the location table)!' USING ERRCODE = '45000';
    END IF;


    IF(Profession_in NOT IN (SELECT P.description FROM Professions P )) THEN
        INSERT INTO Professions(ProfessionID, description)
        VALUES(default, Profession_in);
    END IF;

    INSERT INTO PEOPLE(PersonID, name, ProfessionID, GenderID, LocationID)
    VALUES(default, Pname_in, 
            (SELECT P.ProfessionID FROM Professions P WHERE P.description = Profession_in),
            (SELECT G.GenderID FROM Genders G WHERE G.gender = Gender_in),
            (SELECT L.LocationID FROM Locations L WHERE L.location = Location_in));

END;
$$
LANGUAGE plpgsql;


BEGIN;
CALL InsertPerson('thoka', 'voffi', 'Female', 'Akranes');

SELECT * FROM PEOPLE
WHERE name = 'thoka';
SELECT * FROM Professions;
--ROLLBACK;

CALL InsertPerson('  ', 'voffi', 'Female', 'Akranes');
SELECT * FROM PEOPLE
WHERE name = '  ';
SELECT * FROM Genders;

ROLLBACK;




-- 5.
DROP PROCEDURE IF EXISTS CaseCountFixer();
CREATE OR REPLACE PROCEDURE CaseCountFixer()
LANGUAGE SQL
AS $$
    UPDATE Locations L
    SET caseCount = (
        SELECT COUNT(C.CaseID)
        FROM Cases C 
        WHERE C.LocationID = L.LocationID);
$$;

BEGIN;
CALL CaseCountFixer();
SELECT * FROM Locations;

ROLLBACK;



-- 6. Create a trigger CaseCountTracker that whenever a new case is created, deleted or its
-- location attribute is updated, runs CaseCountFixer

CREATE OR REPLACE FUNCTION TriggerCallsCaseCountFixer()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    Call CaseCountFixer();
    RETURN NEW;
END;
$$;




DROP TRIGGER IF EXISTS CaseCountTracker ON Cases;
CREATE TRIGGER CaseCountTracker
    AFTER INSERT OR DELETE OR UPDATE OF locationID ON Cases  --OR AFTER UPDATE ON Cases.LocationID 
    FOR EACH ROW
    EXECUTE FUNCTION TriggerCallsCaseCountFixer();



SELECT * FROM Cases WHERE CaseID = 1;


BEGIN;

SELECT * FROM Locations;
INSERT INTO Cases(CaseID, title, isClosed, year, AgentID, LocationID)
VALUES(DEFAULT,'test case', false, 2021,1,91);
--ROLLBACK;

SELECT * FROM Locations;
SELECT * FROM Cases;

UPDATE Cases 
SET isClosed = false
WHERE CaseID = 1;
SELECT * FROM Cases;
--SELECT * FROM Locations;

--DELETE FROM InvolvedIn
--WHERE CaseID = 1;

--DELETE FROM Cases
--WHERE CaseID = 1;

--SELECT * FROM Locations;

ROLLBACK;

--7.
CREATE OR REPLACE function startInvestigation(
    agentID_in INT,
    personID_in INT,
    title_in varchar(255)) 
RETURNS void AS $$
DECLARE
person_location INT := (SELECT P.locationID
                        FROM People P
                        WHERE P.PersonID = personID_in);
agents_location INT := (SELECT P.locationID
                        FROM Agents A
                        INNER JOIN People P ON P.PersonID = A.secretIdentity
                        WHERE A.AgentID = agentID_in);
BEGIN
INSERT INTO Cases
VALUES
(default, title_in, FALSE, (SELECT date_part('year', now())), agentID_in, person_location);
IF (agents_location = person_location) THEN 
INSERT INTO InvolvedIn
    VALUES
    (personID_in, (
        SELECT MAX(CaseID)
        FROM Cases
    ), agentID_in, FALSE);
ELSE
INSERT INTO InvolvedIn
    VALUES
    (personID_in, (
        SELECT MAX(CaseID)
        FROM Cases
    ), agentID_in, NULL);
END IF;
END;
$$
LANGUAGE plpgsql;






--8.

CREATE OR REPLACE FUNCTION defectiveAgentArrangements()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- the cases the old agent led goes to the agent with the fewest cases to lead
    UPDATE CASES C
    SET AgentID = (SELECT A.AgentID
                    FROM Agents A 
                    INNER JOIN Cases Ca ON Ca.AgentID = A.AgentID
                    GROUP BY A.AgentID 
                    ORDER BY COUNT(A.AgentID), A.designation ASC 
                    LIMIT 1)
    WHERE C.AgentID = OLD.AgentID;

    -- The people who the agent was investigating will not be investigated by anyone anymore
    -- but is still in the InvolvedIn table
    UPDATE InvolvedIn I 
    SET AgentID = NULL
    WHERE I.AgentID = OLD.AgentID;


    -- Remove any secret identity of the agent from the invloved in table
    DELETE FROM InvolvedIn Iin
    WHERE Iin.PersonID = OLD.secretIdentity;

    RETURN OLD;
END;
$$;




CREATE OR REPLACE FUNCTION afterDeleteArrangements()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN


-- Delete any secret identity of the agent 
    DELETE FROM People P 
    WHERE P.PersonID = OLD.secretIdentity;


    -- Adding the agent back to the database with status ghost and reversed codename after it is deleted
    INSERT INTO Agents(AgentID, codename, designation, killLicense, status, secretIdentity, GenderID)
    VALUES(default, recurReverseCodename(OLD.codename), OLD.designation, OLD.killLicense, 'ghost', NULL, OLD.GenderID);

    RETURN OLD;
END;
$$;


CREATE OR REPLACE FUNCTION recurReverseCodename(oldCodename varchar(255))
RETURNS varchar(255)
LANGUAGE plpgsql
AS $$
BEGIN
    IF (length(oldCodename) = 1) THEN RETURN oldCodename;
    END IF;
    RETURN CONCAT(SUBSTRING(oldCodename, length(oldCodename) , 1), recurReverseCodename(SUBSTRING(oldCodename, 1, length(oldCodename)-1)));

END;
$$;



DROP TRIGGER IF EXISTS defectiveAgentTrigger ON Agents;
CREATE TRIGGER defectiveAgentTrigger
    BEFORE DELETE ON Agents
    FOR EACH ROW
    EXECUTE FUNCTION defectiveAgentArrangements();


DROP TRIGGER IF EXISTS afterDefectiveAgentTrigger ON Agents;
CREATE TRIGGER afterDefectiveAgentTrigger
    AFTER DELETE ON Agents
    FOR EACH ROW
    EXECUTE FUNCTION afterDeleteArrangements();


BEGIN;

SELECT * FROM Agents A WHERE A.AgentID = 1;

SELECT CaseID FROM Cases where AgentID =1;
SELECT CaseID FROM Cases where AgentID =73;

DELETE FROM Agents A WHERE A.AgentID = 1;
SELECT * FROM Agents A WHERE A.secretIdentity = 4941;
SELECT * FROM Cases C where C.AgentID = 1;
SELECT * FROM InvolvedIn WHERe PersonID = 4941;

SELECT * FROM Agents WHERE AgentID = 73;

SELECT C1.AgentID, COUNT(C1.AgentID)
                    FROM Cases C1
                    GROUP BY C1.AgentID
                    ORDER BY COUNT(C1.AgentID) ASC;

SELECT CaseID FROM Cases where AgentID =1;
SELECT * FROM Agents where status = 'ghost';



DELETE FROM Agents A WHERE A.status = 'ghost';
SELECT * FROM Agents where status = 'ghost';

ROLLBACK;




-- 9.
CREATE OR REPLACE FUNCTION yearsSinceCaseInTown(town VARCHAR(255))
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    townID INT;
    yearNow INT;
BEGIN
    townID := (SELECT L.locationID 
                FROM Locations L   
                WHERE L.location = town);

    yearNow := (SELECT date_part('year', now()));

    RETURN yearNow - (SELECT C.year 
            FROM Cases C 
            WHERE C.locationID = townID AND C.year <= yearNow
            ORDER BY C.year DESC Limit 1);

END;
$$;

BEGIN;
SELECT * FROM yearsSinceCaseInTown('Fosshóll');
SELECT * FROM Cases where locationID = 47;
ROLLBACK;



-- 10.

CREATE OR REPLACE FUNCTION FrenemiesOfFrenemies(PersonID_in INT)
RETURNS table
LANGUAGE plpgsql
AS $$
BEGIN
     RETURN (SELECT * 
            FROM InvolvedIn I
            WHERE)



END;
$$;