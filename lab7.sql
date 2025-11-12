DROP TABLE IF EXISTS employees;
CREATE TABLE IF NOT EXISTS employees(
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50),
    dept_id INT,
    salary DECIMAL(10,2)
);
DROP TABLE IF EXISTS departments;
CREATE TABLE IF NOT EXISTS departments(
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
);
DROP TABLE IF EXISTS projects;
CREATE TABLE IF NOT EXISTS projects (
    project_id INT PRIMARY KEY,
    project_name VARCHAR(50),
    dept_id INT,
    budget decimal(10, 2)
);

-- Insert data into employees
 INSERT INTO employees (emp_id, emp_name, dept_id, salary)
VALUES
 (1, 'John Smith', 101, 50000),
 (2, 'Jane Doe', 102, 60000),
 (3, 'Mike Johnson', 101, 55000),
 (4, 'Sarah Williams', 103, 65000),
 (5, 'Tom Brown', NULL, 45000);-- Insert data into departments
 INSERT INTO departments (dept_id, dept_name, location) VALUES
 (101, 'IT', 'Building A'),
 (102, 'HR', 'Building B'),
 (103, 'Finance', 'Building C'),
 (104, 'Marketing', 'Building D');-- Insert data into projects
 INSERT INTO projects (project_id, project_name, dept_id,
budget) VALUES
 (1, 'Website Redesign', 101, 100000),
 (2, 'Employee Training', 102, 50000),
 (3, 'Budget Analysis', 103, 75000),
 (4, 'Cloud Migration', 101, 150000),
 (5, 'AI Research', NULL, 200000);

-- part 2
-- 2.1
CREATE OR REPLACE VIEW employee_details AS
SELECT
    e.emp_name,
    e.salary,
    d.dept_name,
    d.location
FROM employees e
JOIN departments d
  ON e.dept_id = d.dept_id;

SELECT * FROM employee_details;
--вернётся 4 строки

-- 2.2
CREATE OR REPLACE VIEW dept_statistics AS
    SELECT
        d.dept_id,
        d.dept_name,
        COUNT(e.emp_id)   AS employee_count,
        AVG(e.salary)::numeric(10,2) AS avg_salary,
        MAX(e.salary) AS max_salary,
        MIN(e.salary)  AS min_salary
FROM departments d
Left JOIN employees e
    ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name;

SELECT * FROM dept_statistics
ORDER BY employee_count DESC;

-- 2.3
CREATE OR REPLACE VIEW project_overview AS
SELECT
    p.project_id,
    p.project_name,
    p.budget,
    d.dept_name,
    d.location,
    COALESCE(ts.team_size, 0) AS team_size
FROM projects p
LEFT JOIN departments d
  ON p.dept_id = d.dept_id
LEFT JOIN (
    SELECT e.dept_id, COUNT(*) AS team_size
    FROM employees e
    GROUP BY e.dept_id
) ts
  ON ts.dept_id = p.dept_id;

SELECT * FROM project_overview
ORDER BY team_size DESC, project_id;

--2.4
CREATE OR REPLACE VIEW high_earners AS
SELECT
    e.emp_name,
    e.salary,
    d.dept_name
FROM employees e
LEFT JOIN departments d
  ON d.dept_id = e.dept_id
WHERE e.salary > 55000;

SELECT * FROM high_earners
ORDER BY salary DESC, emp_name;

--Показываются все сотрудники с зарплатой > 55000, а dept_name подставляется из departments. Если у кого-то нет отдела, он всё равно появится, но с dept_name = NULL
--да, видны все, в том числе с NULL в dept_id. c INNER JOIN, сотрудники без отдела исчезли бы из результата, даже если их зарплата > 55000.

--part 3
--3.1
CREATE OR REPLACE VIEW employee_details AS
SELECT
    e.emp_name,
    e.salary,
    d.dept_name,
    d.location,
    CASE
        WHEN e.salary > 60000 THEN 'High'
        WHEN e.salary > 50000 THEN 'Medium'
        ELSE 'Standard'
    END AS salary_grade
FROM employees e
JOIN departments d
  ON e.dept_id = d.dept_id;
SELECT * FROM employee_details
ORDER BY salary DESC;

--3.2
-- Переименовать представление
--ALTER VIEW high_earners RENAME TO top_performers;
--SELECT * FROM top_performers;
--После переименования старое имя high_earners больше не существует.будет ошибка

--3.3
CREATE OR REPLACE VIEW temp_view AS
SELECT
    emp_name,
    salary,
    dept_id
FROM employees
WHERE salary < 50000;
SELECT * FROM temp_view;
DROP VIEW IF EXISTS temp_view;

--part 4
--4.1
CREATE OR REPLACE VIEW employee_salaries AS
SELECT
    emp_id,
    emp_name,
    dept_id,
    salary
FROM employees;

UPDATE employee_salaries
SET salary = 52000
WHERE emp_name = 'John Smith';

SELECT * FROM employees
WHERE emp_name = 'John Smith';

--4.2
UPDATE employee_salaries
SET salary = 52000
WHERE emp_name = 'John Smith';
SELECT * FROM employees
WHERE emp_name = 'John Smith';
--employee_salaries действует как «прозрачное окно» в таблицу employees: всё, что ты изменяе через view, изменяет реальные данные.

--4.3
CREATE OR REPLACE VIEW employee_salaries AS
SELECT
    emp_id,
    emp_name,
    dept_id,
    salary
FROM employees;

INSERT INTO employee_salaries (emp_id, emp_name, dept_id, salary)
VALUES (6, 'Alice Johnson', 102, 58000);

SELECT * FROM employees
WHERE emp_name = 'Alice Johnson';
--Вставка будет успешной, потому что employee_salaries — это обновляемое view, напрямую связанное с таблицей employees.

--4.4
CREATE OR REPLACE VIEW it_employees AS
SELECT
    emp_id,
    emp_name,
    dept_id,
    salary
FROM employees
WHERE dept_id = 101
WITH LOCAL CHECK OPTION;
INSERT INTO it_employees (emp_id, emp_name, dept_id, salary)
VALUES (8, 'Kevin Parker', 101, 57000);

--INSERT INTO it_employees (emp_id, emp_name, dept_id, salary)
--VALUES (7, 'Bob Wilson', 103, 60000); -- id != 103!!!

--В представлении задано условие WHERE dept_id = 101 — оно показывает только IT-сотрудников.
--Добавлен параметр WITH LOCAL CHECK OPTION, который запрещает вставку или обновление строк, которые не удовлетворяют условию WHERE.
-- PostgreSQL проверяет каждую новую строку перед вставкой, и если dept_id ≠ 101, выбрасывает ошибку.

SELECT * FROM it_employees;

--part 5
-- 5.1
CREATE MATERIALIZED VIEW dept_summary_mv AS
SELECT
    d.dept_id,
    d.dept_name,
    COALESCE(COUNT(DISTINCT e.emp_id), 0) AS total_employees,
    COALESCE(SUM(e.salary), 0)            AS total_salaries,
    COALESCE(COUNT(DISTINCT p.project_id), 0) AS total_projects,
    COALESCE(SUM(p.budget), 0)            AS total_project_budget
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
LEFT JOIN projects p  ON p.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
WITH DATA;

SELECT * FROM dept_summary_mv ORDER BY dept_id;
-- 5.2
DELETE FROM employees WHERE emp_id = 8;
INSERT INTO employees (emp_id, emp_name, dept_id, salary)
VALUES (8, 'Charlie Brown', 101, 54000);

SELECT * FROM dept_summary_mv WHERE dept_id = 101;

REFRESH MATERIALIZED VIEW dept_summary_mv;

SELECT * FROM dept_summary_mv WHERE dept_id = 101;
-- До REFRESH Charlie Brown не отображается,
-- после REFRESH — total_employees и total_salaries обновляются.

-- 5.3
CREATE UNIQUE INDEX IF NOT EXISTS dept_summary_mv_dept_id_idx
ON dept_summary_mv (dept_id);

REFRESH MATERIALIZED VIEW CONCURRENTLY dept_summary_mv;
-- CONCURRENTLY позволяет обновлять без блокировки чтения —
-- пользователи могут продолжать SELECT, пока идёт обновление.

-- 5.4
CREATE MATERIALIZED VIEW project_stats_mv AS
SELECT
    p.project_name,
    p.budget,
    d.dept_name,
    COUNT(e.emp_id) AS assigned_employees
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id
LEFT JOIN employees e   ON e.dept_id = d.dept_id
GROUP BY p.project_name, p.budget, d.dept_name
WITH NO DATA;

-- Следующий запрос выдаст ошибку:
-- SELECT * FROM project_stats_mv;
-- "materialized view project_stats_mv has not been populated"
-- Исправление:
REFRESH MATERIALIZED VIEW project_stats_mv;
SELECT * FROM project_stats_mv;

--part 6
-- 6.1
CREATE ROLE analyst;
CREATE ROLE data_viewer LOGIN PASSWORD 'viewer123';
CREATE ROLE report_user LOGIN PASSWORD 'report456';

SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg_%';

-- 6.2
CREATE ROLE db_creator LOGIN CREATEDB PASSWORD 'creator789';
CREATE ROLE user_manager LOGIN CREATEROLE PASSWORD 'manager101';
CREATE ROLE admin_user LOGIN SUPERUSER PASSWORD 'admin999';

-- 6.3
GRANT SELECT ON employees, departments, projects TO analyst;
GRANT ALL PRIVILEGES ON employee_details TO data_viewer;
GRANT SELECT, INSERT ON employees TO report_user;

-- 6.4
CREATE ROLE hr_team;
CREATE ROLE finance_team;
CREATE ROLE it_team;

CREATE ROLE hr_user1 LOGIN PASSWORD 'hr001';
CREATE ROLE hr_user2 LOGIN PASSWORD 'hr002';
CREATE ROLE finance_user1 LOGIN PASSWORD 'fin001';

GRANT hr_team TO hr_user1, hr_user2;
GRANT finance_team TO finance_user1;

GRANT SELECT, UPDATE ON employees TO hr_team;
GRANT SELECT ON dept_statistics TO finance_team;

-- 6.5
REVOKE UPDATE ON employees FROM hr_team;
REVOKE hr_team FROM hr_user2;
REVOKE ALL PRIVILEGES ON employee_details FROM data_viewer;

-- 6.6
ALTER ROLE analyst LOGIN PASSWORD 'analyst123';
ALTER ROLE user_manager SUPERUSER;
ALTER ROLE analyst PASSWORD NULL;
ALTER ROLE data_viewer CONNECTION LIMIT 5;

--part 7
-- 7.1
CREATE ROLE read_only;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;

CREATE ROLE junior_analyst LOGIN PASSWORD 'junior123';
CREATE ROLE senior_analyst LOGIN PASSWORD 'senior123';

GRANT read_only TO junior_analyst, senior_analyst;
GRANT INSERT, UPDATE ON employees TO senior_analyst;
--  junior_analyst может только читать,
-- senior_analyst может читать, вставлять и обновлять сотрудников.

-- 7.2
CREATE ROLE project_manager LOGIN PASSWORD 'pm123';
ALTER VIEW dept_statistics OWNER TO project_manager;
ALTER TABLE projects OWNER TO project_manager;

SELECT tablename, tableowner
FROM pg_tables
WHERE schemaname = 'public';

-- 7.3
CREATE ROLE temp_owner LOGIN;
CREATE TABLE temp_table (id INT);
ALTER TABLE temp_table OWNER TO temp_owner;
REASSIGN OWNED BY temp_owner TO postgres;
DROP OWNED BY temp_owner;
DROP ROLE temp_owner;

-- 7.4
CREATE OR REPLACE VIEW hr_employee_view AS
SELECT * FROM employees
WHERE dept_id = 102;
GRANT SELECT ON hr_employee_view TO hr_team;

CREATE OR REPLACE VIEW finance_employee_view AS
SELECT emp_id, emp_name, salary
FROM employees;
GRANT SELECT ON finance_employee_view TO finance_team;

--part 8
-- 8.1
CREATE OR REPLACE VIEW dept_dashboard AS
SELECT
    d.dept_name,
    d.location,
    COUNT(e.emp_id)                      AS employee_count,
    ROUND(AVG(e.salary), 2)              AS avg_salary,
    COUNT(DISTINCT p.project_id)         AS active_projects,
    COALESCE(SUM(p.budget), 0)           AS total_budget,
    ROUND(COALESCE(SUM(p.budget), 0) /
           NULLIF(COUNT(e.emp_id), 0), 2) AS budget_per_employee
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN projects p  ON d.dept_id = p.dept_id
GROUP BY d.dept_name, d.location;

SELECT * FROM dept_dashboard;

-- 8.2
ALTER TABLE projects ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE VIEW high_budget_projects AS
SELECT
    p.project_name,
    p.budget,
    d.dept_name,
    p.created_date,
    CASE
        WHEN p.budget > 150000 THEN 'Critical Review Required'
        WHEN p.budget > 100000 THEN 'Management Approval Needed'
        ELSE 'Standard Process'
    END AS approval_status
FROM projects p
LEFT JOIN departments d ON p.dept_id = d.dept_id;

SELECT * FROM high_budget_projects;

-- 8.3
CREATE ROLE viewer_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO viewer_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO viewer_role;

CREATE ROLE entry_role;
GRANT viewer_role TO entry_role;
GRANT INSERT ON employees, projects TO entry_role;

CREATE ROLE analyst_role;
GRANT entry_role TO analyst_role;
GRANT UPDATE ON employees, projects TO analyst_role;

CREATE ROLE manager_role;
GRANT analyst_role TO manager_role;
GRANT DELETE ON employees, projects TO manager_role;

CREATE ROLE alice LOGIN PASSWORD 'alice123';
CREATE ROLE bob LOGIN PASSWORD 'bob123';
CREATE ROLE charlie LOGIN PASSWORD 'charlie123';

GRANT viewer_role  TO alice;
GRANT analyst_role TO bob;
GRANT manager_role TO charlie;
