--Part A: Database and Table Setup

CREATE DATABASE advanced_lab;
CREATE TABLE employees (
    emp_id SERIAL PRIMARY KEY,
    first_name VARCHAR,
    last_name VARCHAR,
    department VARCHAR,
    salary INT,
    hire_date DATE,
    status VARCHAR DEFAULT 'Active'
);

CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR,
    budget INT,
    manager_id INT
);

CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    project_name VARCHAR,
    dept_id INT,
    start_date DATE,
    end_date DATE,
    budget INT
);

--Part B: Advanced INSERT Operations

INSERT INTO employees (emp_id, first_name, last_name, department)
VALUES (DEFAULT, 'Make', 'Murat', 'Audit');

INSERT INTO employees (first_name, last_name, department, salary, status)
VALUES ('yahi', 'nurbek', 'IT', DEFAULT, DEFAULT);
SELECT * FROM employees;
INSERT INTO departments (dept_name, budget, manager_id)
VALUES
    ('IT', 10000000, NULL),
    ('Audit',200000, NULL),
    ('Finance', 2000000, NULL);

INSERT INTO employees (first_name, last_name, department, salary, hire_date)
VALUES ('Ryan', 'Gosling', 'Finance', (50000 * 1.1)::INT, CURRENT_DATE);

CREATE TEMPORARY TABLE temp_employees AS SELECT * FROM employees WHERE department = 'IT';

--Part C: Complex UPDATE Operations

UPDATE employees
SET salary = (salary * 1.10)::INT;

UPDATE employees
SET status = 'Senior' WHERE (salary > 60000) AND (hire_date < DATE '2020-01-01');

UPDATE employees
SET department = CASE
    WHEN salary > 80000 THEN department = 'Management'
    WHEN (salary > 50000 AND salary < 80000) THEN department =  'Senior'
    ELSE department = 'Junior'
END;

UPDATE employees
SET department = DEFAULT WHERE status = 'Inactive';

UPDATE departments d
SET budget = (s.avg_salary * 1.20)::int
FROM (
    SELECT department AS dept_name, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department
) s
WHERE d.dept_name = s.dept_name;

UPDATE employees
SET salary = salary * 1.15 AND status = 'Promoted' WHERE department = 'Sales';

--Part D: Advanced DELETE Operations
DELETE FROM employees WHERE status = 'Terminated';

DELETE FROM  employees WHERE (salary < 40000 AND hire_date > DATE '2023-01-01' AND department IS NULL);

DELETE FROM departments d
WHERE NOT EXISTS (
  SELECT 1
  FROM employees e
  WHERE e.department = d.dept_name
);

DELETE FROM projects WHERE end_date< '2023-01-01'
RETURNING *;

--Part E: Operations with NULL Values
INSERT INTO employees (first_name, last_name, department, salary)
VALUES ('Aibek', 'Mamour',NULL, NULL);

UPDATE employees
SET department = 'Unassigned' WHERE department ISNULL;

DELETE FROM employees
WHERE department ISNULL  OR salary ISNULL;

--Part F: RETURNING Clause Operations
INSERT INTO employees (first_name, last_name, department, salary)
VALUES ('Nusipkhodza', 'Bekzhan', 'IT', 400001)
RETURNING emp_id, (first_name || ' ' || last_name) AS full_name;

UPDATE employees
SET salary = (salary + 5000) WHERE department = 'IT'
RETURNING emp_id, salary - 5000 AS old_salary, salary AS new_salary;

DELETE FROM employees WHERE hire_date < DATE '2020-01-01'
RETURNING *;

--Part G: Advanced DML Patterns
INSERT INTO employees (first_name, last_name, department)
SELECT 'The', 'Weekend', 'Management'
WHERE NOT EXISTS (
    SELECT 1 FROM employees
    WHERE first_name = 'The' AND last_name = 'Weekend'
);

UPDATE employees e
SET salary = (
  salary * CASE
    WHEN (SELECT d.budget FROM departments d
          WHERE d.dept_name = e.department) > 100000 THEN 1.10
    ELSE 1.05
  END
)::int;

INSERT INTO employees (first_name, last_name, department, salary)
VALUES
    ('Eldos','MAxmud', 'IT', 50000),
    ('MAmut', 'Rahal', 'IT', 51000),
    ('PUdj', 'NUrmagemodov', 'Management',52000),
    ('Madiyar', 'Murat', 'Audit', 53000),
    ('Aldiyar', 'Nurmak', 'Finance', 54000);

UPDATE employees
SET salary = salary * 1.1
WHERE (first_name, last_name) IN (
    ('Eldos','MAxmud'),('MAmut', 'Ibrayev'),('PUdj', 'NUrmagemodov'),('Madiyar', 'Murat'),('Aldiyar', 'Nurmak')
    );

CREATE TABLE employee_archive AS SELECT * FROM employees WHERE status = 'Inactive';
DELETE FROM employees WHERE status = 'Inacive';

UPDATE projects p
SET end_date = COALESCE(p.end_date, CURRENT_DATE) + INTERVAL '30 days'
WHERE p.budget > 50000
  AND EXISTS (
      SELECT 1
      FROM departments d
      JOIN employees e ON e.department = d.dept_name
      WHERE d.dept_id = p.dept_id
      GROUP BY d.dept_id
      HAVING COUNT(*) > 3
  );
