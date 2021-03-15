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
SELECT A.AgentID, A.codename, P.PersonID, P.name, COUNT(P.PersonID)
FROM People P
INNER JOIN InvolvedIn I ON I.PersonID = P.PersonID
INNER JOIN Agents A ON I.AgentID = A.AgentID
GROUP BY P.PersonID, A.AgentID, I.isCulprit
HAVING I.isCulprit = TRUE AND COUNT(I.isCulprit = TRUE) > 1
ORDER BY COUNT(A.AgentID);

SELECT * FROM allNemeses;

BEGIN;
INSERT INTO InvolvedIn
VALUES(374, 1, 44, true);
INSERT INTO InvolvedIn
VALUES(374, 2, 44, true);

SELECT * FROM allNemeses;

ROLLBACK;

SELECT * FROM Cases C WHERE C.AgentID =22;



-- 4.

CREATE OR REPLACE PROCEDURE InsertPerson
-- check daematimaverkefni


-- 5.
CREATE OR REPLACE FUNCTION CaseCountFixer
RETURNS TRIGGER --CaseCountTracker
LANGUAGE plpgsql
AS $$
DECLARE r Locations%rowtype;
BEGIN 
    FOR r IN
        SELECT L.LocationID, L.caseCount 
        FROM Locations L
    LOOP
        r.caseCount = (SELECT COUNT(C.CaseID)
                        FROM Cases C
                        WHERE C.LocationID = r.LocationID) 

    RETURN NEW;
    --ATH
    --TODO: correct the caseCount
$$;



-- 6. Create a trigger CaseCountTracker that whenever a new case is created, deleted or its
-- location attribute is updated, runs CaseCountFixer
DROP TRIGGER IF EXISTS CaseCountTracker ON Cases;
CREATE TRIGGER CaseCountTracker
    AFTER INSERT OR DELETE ON Cases --OR AFTER UPDATE ON Cases.LocationID 
    FOR EACH ROW
    EXECUTE FUNCTION CaseCountFixer();






BEGIN;
INSERT INTO Cases
VALUES(DEFAULT,'test case', false, 2021,1,2);


ROLLBACK;

--7.


--8.
