--CREATE DATABASE PIV;

-- Eva Sól Pétursdóttir og Halla Margrét Jónsdóttir

-- 1.
select
    1 as Query;

CREATE OR REPLACE VIEW infoAgent AS
SELECT 
    A.codename, 
    A.status, 
    COUNT(C.CaseID) AS "Number of cases", 
    ARRAY(SELECT L1.location 
        FROM Locations L1
        INNER JOIN Cases C1 ON C1.locationID = L1.locationID
        GROUP BY C1.AgentID, L1.LocationID HAVING C1.AgentID = A.AgentID AND COUNT(C1.LocationID) >= ALL (
                    SELECT COUNT(C2.locationID)
                    FROM Cases C2
                    GROUP BY C2.AgentID, C2.locationID HAVING C2.AgentID = A.AgentID
)) AS "Most common locations led cases"
FROM Agents A
NATURAL JOIN Cases C
GROUP BY A.AgentID;

--SELECT * FROM infoAgent;


select
    2 as Query;

CREATE OR REPLACE VIEW top3subjectsStokkseyri AS
SELECT 
    P.PersonID, 
    P.name, 
    L.location
FROM People P
INNER JOIN Locations L ON P.LocationID = L.LocationID
INNER JOIN InvolvedIn I ON P.PersonID = I.PersonID
GROUP BY 
    P.PersonID, 
    L.LocationID
HAVING L.location = 'Stokkseyri'
ORDER BY COUNT(distinct I.CaseID) DESC
LIMIT 3;

--SELECT * FROM top3subjectsStokkseyri;


select
    3 as Query;

CREATE OR REPLACE VIEW allNemeses AS
SELECT 
    DISTINCT ON (P.PersonId) A.AgentID, 
    A.codename, 
    P.PersonID, 
    P.name
FROM People P
INNER JOIN InvolvedIn I ON I.PersonID = P.PersonID
INNER JOIN Agents A ON I.AgentID = A.AgentID
GROUP BY 
    P.PersonID, 
    A.AgentID, 
    I.isCulprit
HAVING I.isCulprit = TRUE AND COUNT(I.isCulprit = TRUE) > 1
ORDER BY P.PersonID, COUNT(A.AgentID) DESC;


--SELECT * FROM allNemeses;

select
    4 as Query;

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


select
    5 as Query;

--DROP PROCEDURE IF EXISTS CaseCountFixer();

CREATE OR REPLACE PROCEDURE CaseCountFixer()
LANGUAGE SQL
AS $$
    UPDATE Locations L
    SET caseCount = (
        SELECT COUNT(C.CaseID)
        FROM Cases C 
        WHERE C.LocationID = L.LocationID);
$$;



select
    6 as Query;

CREATE OR REPLACE FUNCTION TriggerCallsCaseCountFixer()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    Call CaseCountFixer();
    RETURN NEW;
END;
$$;

--DROP TRIGGER IF EXISTS CaseCountTracker ON Cases;

CREATE TRIGGER CaseCountTracker
    AFTER INSERT OR DELETE OR UPDATE OF locationID ON Cases
    FOR EACH ROW
    EXECUTE FUNCTION TriggerCallsCaseCountFixer();



select
    7 as Query;

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



select
    8 as Query;

CREATE OR REPLACE FUNCTION defectiveAgentArrangements()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE currCase INT;
BEGIN
    -- the cases the old agent led goes to the agent with the fewest cases to lead
    
    FOR currCase in (SELECT C.CaseID 
                    FROM Cases C 
                    WHERE C.AgentID = OLD.AgentID) loop
        UPDATE CASES C
        SET AgentID = (SELECT A.AgentID
                        FROM Agents A 
                        INNER JOIN Cases Ca ON Ca.AgentID = A.AgentID
                        GROUP BY A.AgentID 
                        HAVING A.AgentID != OLD.AgentID
                        ORDER BY COUNT(A.AgentID), A.designation ASC 
                        LIMIT 1)
        WHERE C.CaseID = currCase;
    END LOOP;

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


--DROP TRIGGER IF EXISTS defectiveAgentTrigger ON Agents;
CREATE TRIGGER defectiveAgentTrigger
    BEFORE DELETE ON Agents
    FOR EACH ROW
    EXECUTE FUNCTION defectiveAgentArrangements();


--DROP TRIGGER IF EXISTS afterDefectiveAgentTrigger ON Agents;
CREATE TRIGGER afterDefectiveAgentTrigger
    AFTER DELETE ON Agents
    FOR EACH ROW
    EXECUTE FUNCTION afterDeleteArrangements();


select
    9 as Query;

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

select
    10 as Query;

CREATE OR REPLACE FUNCTION FrenemiesOfFrenemiesHelper(PersonID_in_helper INT)
RETURNS TABLE(personID INT, name VARCHAR(255), proffID INT, genderID INT, LocID INT)
LANGUAGE plpgsql
AS $$
DECLARE CURRENT_PERSONID INT;
BEGIN
    for CURRENT_PERSONID in (SELECT distinct P.PersonID
        FROM InvolvedIn I
        INNER JOIN People P ON P.PersonID = I.PersonID
        WHERE I.CaseID IN (SELECT I2.CaseID
                            FROM InvolvedIn I2
                            WHERE I2.PersonID = personID_in_helper))
        loop
        RETURN QUERY (SELECT distinct P1.*
                    FROM People P1
                    INNER JOIN InvolvedIn I3 ON P1.PersonID = I3.PersonID
                    WHERE P1.PersonID <> PersonID_in_helper AND I3.CaseID IN (SELECT I4.CaseID
                                        FROM InvolvedIn I4
                                        WHERE I4.PersonID = CURRENT_PERSONID));
        END LOOP;
END;
$$;


CREATE OR REPLACE FUNCTION FrenemiesOfFrenemies(PersonID_in INT)
RETURNS TABLE(personID INT, name VARCHAR(255), proffID INT, genderID INT, LocID INT)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY (SELECT distinct * FROM FrenemiesOfFrenemiesHelper(PersonID_in));

END;
$$;

SELECT * FROM FrenemiesOfFrenemies(4256);