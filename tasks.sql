/*
SQLite database containing a organizations data.

@version 19/11/22
 */
------------------------------------------------------------------------------------------------------------
-- Task 1
-- How many employees of for a project titled "A" are involved in its plan “B”?

-- Plans for project A
CREATE VIEW IF NOT EXISTS PLANS_PROJECT_A AS
    SELECT PID
    FROM Plan P
    WHERE P.PrID IN (SELECT PrID FROM Project WHERE name = 'A');

-- Employees working on project A
CREATE VIEW IF NOT EXISTS EMPLOYEES_PROJECT_A AS
    SELECT EID
    FROM "plan_activity_employee_relation" paer,PLANS_PROJECT_A pa
    WHERE pa.PID = paer.PID;

-- Plans for project B
CREATE VIEW IF NOT EXISTS PLANS_PROJECT_B AS
    SELECT PID
    FROM Plan P
    WHERE P.PrID IN (SELECT PrID FROM Project WHERE name = 'B');

-- Employees working on project B
CREATE VIEW IF NOT EXISTS EMPLOYEES_PROJECT_B AS
    SELECT DISTINCT EID
    FROM "plan_activity_employee_relation" paer,PLANS_PROJECT_B pb
    WHERE paer.PID = "pb".PID
    ORDER BY EID;

-- Main statement, counts every instance of an employee working on project A and also in Project B
CREATE VIEW IF NOT EXISTS NUMBER_EMPLOYEES_PROJECT_A_IN_PROJECT_B AS
    SELECT COUNT(*)
    FROM EMPLOYEES_PROJECT_A
    WHERE EMPLOYEES_PROJECT_A.EID IN EMPLOYEES_PROJECT_B;

---------------------------------------------------------------------------------------------------
/*
Task 2
Retrieve the names of plans made for project “A” with least cost.
Assuming the working time of a plan consists of the sum of the duration of all the activities it is made up of.
*/
-- All activities and their respective duration
CREATE VIEW IF NOT EXISTS ACTIVITIES_DURATION AS
    SELECT AID,end - start AS duration FROM Activities;

-- Employee's and their activities with the cost of respective activity
CREATE VIEW IF NOT EXISTS EMPLOYEE_ACTIVITY_COST AS
    SELECT E.EID,A.AID, E.Salary * A.duration AS Cost
    FROM ACTIVITIES_DURATION A, EMPLOYEE E, plan_activity_employee_relation paer
    WHERE e.EID = paer.EID AND paer.AID = A.AID
    ORDER BY e.EID;

-- All employees and their plans
CREATE VIEW IF NOT EXISTS EMPLOYEES_PLANS AS
    SELECT distinct e.EID, p.PID
    FROM plan_activity_employee_relation paer ,Plan p,EMPLOYEE e
    WHERE paer.PID = p.PID and paer.EID = e.EID
    ORDER BY E.EID;

-- All plans and their respective total cost
CREATE VIEW IF NOT EXISTS PLAN_COST AS
    SELECT distinct e.PID, SUM(Cost) as plan_cost
    FROM EMPLOYEE_ACTIVITY_COST ea, EMPLOYEES_PLANS e, plan_activity_employee_relation paer
    WHERE e.EID = ea.EID and paer.AID = ea.AID and e.PID = paer.PID
    GROUP BY e.PID;

-- The lowest cost plans for Project A
CREATE VIEW IF NOT EXISTS LOWEST_COST_PLAN_PROJECT_A AS
    SELECT PID, Cost
    FROM PLAN_COST ,(SELECT min(pc.plan_cost) AS Cost
                     FROM PLANS_PROJECT_A pa,PLAN_COST pc
                     WHERE pc.PID = pa.PID) AS MinimumPrice
    WHERE PLAN_COST.plan_cost = Cost;
--------------------------------------------------------------------------------------------------------------------
-- Task 3
-- For each employee retrieve the name, project name and plan name with the most
-- working time.

--Every plan and involved employee's working time
CREATE VIEW IF NOT EXISTS EMPLOYEE_PLAN_WORKING_TIME AS
SELECT paer.PID, paer.EID, SUM(duration) as working_time
FROM ACTIVITIES_DURATION ad, plan_activity_employee_relation paer
WHERE paer.AID = ad.AID
GROUP BY paer.EID,paer.PID
order by paer.EID;

-- Every employee and their plan with the most working time
CREATE VIEW IF NOT EXISTS EMPLOYEES_BUSIEST_PLAN AS
SELECT e.name,pr.name as Project, p.name as Plan, MAX(working_time) as Total_working_time
FROM EMPLOYEE_PLAN_WORKING_TIME epwt, EMPLOYEE e, Plan p, Project pr
WHERE epwt.EID = e.EID AND epwt.PID = P.PID AND P.PID = pr.PrID
GROUP BY e.EID;
--------------------------------------------------------------------------------------------------------------------
-- Task 4
-- Retrieve all the employee's name and their least working time with respect to different project
CREATE VIEW IF NOT EXISTS EMPLOYEE_LEAST_WORKING_TIME AS
    SELECT name, MIN(working_time) AS Least_Working_Time
    FROM EMPLOYEE_PLAN_WORKING_TIME
    INNER JOIN EMPLOYEE USING(EID)
    GROUP BY EID
;
-------------------------------------------------------------------------------------------------------------------
-- TASK 5
-- Retrieve all the plans for project with order of their working period.

-- Project with the different plan table
CREATE VIEW IF NOT EXISTS EVERY_PLAN_FOR_PROJECT AS
    SELECT PrID, PID
    FROM Project
    INNER JOIN PLAN USING(PrID)
    GROUP BY PID
    ORDER BY PrID
;

-- Table that view every Plan with working periode
CREATE VIEW IF NOT EXISTS PLAN_WITH_WORKING_PERIODE AS
    SELECT PID, (end-start) AS Work_Periode
    FROM Plan
    GROUP BY PID
;

-- Main task. Show every plan for project with working periode in working periode order
CREATE VIEW IF NOT EXISTS PLANS_FOR_PROJECT_WORKING_ORDER AS
    SELECT PrID AS Project, EPFP.PID AS Plans, Work_Periode
    FROM EVERY_PLAN_FOR_PROJECT EPFP, PLAN_WITH_WORKING_PERIODE PWWP
    WHERE EPFP.PID = PWWP.PID
    GROUP BY EPFP.PID
    ORDER BY Work_Periode DESC
;

/*
 As there are limited security and integrity features in SQLite this represents the security and integrity measures
 taken with a DMBS that supports these features.
 */

-- Integrity 1: An activity can be planned to more than one employee, but not the same time period.

-- Integrity
CREATE TABLE IF NOT EXISTS PLAN (PID INTEGER PRIMARY KEY , PrID INTEGER FOREIGN KEY REFERENCES Project(PrID)

                    -- Checks that the start date is between the start and end of the project, and before end date.
                  , start datetime2 CONSTRAINT Valid_start_date
                      CHECK (start BETWEEN (SELECT Project.start
                                            FROM Project
                                            WHERE PrID = Project.PrID) AND
                                           (SELECT Project.end
                                            FROM Project
                                            WHERE PrID = Project.PrID
                                            AND start < end))

                  -- Checks that end date is between the plans start date and the project end date.
                  , end text CONSTRAINT Valid_end_date
                      CHECK(end BETWEEN plan.start AND
                                           (SELECT Project.end
                                            FROM Project
                                            WHERE PrID = Project.PrID)));

CREATE TABLE IF NOT EXISTS EMPLOYEE (
    EID INTEGER(10) PRIMARY KEY,
    NAME nchar(20),
    last_name nchar(20),
    Salary integer);

CREATE TABLE IF NOT EXISTS Activities (
    AID INTEGER(10) PRIMARY KEY,
    activity nchar(20),
    start datetime2,
    end datetime2
);

CREATE TABLE IF NOT EXISTS plan_activity_employee_relation (
    PID INTEGER(10),
    AID INTEGER(10),
    EID INTEGER(10),
    FOREIGN KEY(PID) REFERENCES Plan(PID),
    FOREIGN KEY(AID) REFERENCES Activities(AID),
    FOREIGN KEY(EID) REFERENCES EMPLOYEE(EID)
);

CREATE TABLE IF NOT EXISTS Project (
    PrID INTEGER(10) PRIMARY KEY,
    EID INTEGER(10),
    name nchar(20),
    start datetime2,
    end datetime2,
    budget INTEGER(10),
    FOREIGN KEY(EID) REFERENCES EMPLOYEE(EID)
);

-- A trigger which prohibits the insertion of a new activity in a plan if it goes over its respective project budget.
CREATE TRIGGER IF NOT EXISTS prevent_plan_cost_exceed_project_budget  AFTER INSERT ON plan_activity_employee_relation
    WHEN NEW.PID IN (SELECT plan_activity_employee_relation.PID
                     FROM plan_activity_employee_relation
                     INNER JOIN PLAN_COST PC on plan_activity_employee_relation.PID = PC.PID
                     INNER JOIN Plan P2 on plan_activity_employee_relation.PID = P2.PID
                     WHERE plan_cost > (SELECT budget FROM Project WHERE Project.PrID = P2.PrID))
    BEGIN
        DELETE FROM plan_activity_employee_relation WHERE AID = new.AID AND PID = NEW.PID AND EID = NEW.EID;
    end;

-- Prevents an employee from being assigned two activities at the same time
CREATE TRIGGER IF NOT EXISTS prevent_employee_same_activity_timeframe AFTER INSERT ON plan_activity_employee_relation
    WHEN NEW.AID IN (SELECT paer.AID
                     FROM plan_activity_employee_relation paer
                     INNER JOIN Activities A on paer.AID = A.AID
                     WHERE (A.start AND A.end) = (SELECT start,end FROM Activities WHERE AID = new.AID))
    BEGIN
        DELETE FROM plan_activity_employee_relation WHERE AID = new.AID AND PID = NEW.PID AND EID = NEW.EID;
    end;


SELECT * FROM plan_activity_employee_relation;

SELECT budget From Project;
-- Security: Employees as database users have the right to query the project information but not Employee Information
CREATE ROLE ProjectParticipant;

GRANT SELECT
ON TABLE Project, Plan, plan_activity_employee_relation, Activities
TO ProjectParticipant

REVOKE ALL PRIVILIGES
ON TABLE EMPLOYEE
TO ProjectParticipant

GRANT ProjectParticipant
TO Employee_USER







