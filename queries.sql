CREATE DATABASE PIV;

SELECT A.AgentID, A.codename, A.status, COUNT(C.CaseID)
FROM Agents A
NATURAL JOIN Cases C
GROUP BY A.AgentID;