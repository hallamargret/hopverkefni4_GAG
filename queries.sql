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
CREATE OR REPLACE FUNCTION StartInvestigation()






--8.
