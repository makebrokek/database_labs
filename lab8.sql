/*1. B-tree: Default type, good for equality and range queries
2. Hash: Only for equality comparisons
3. GiST: For geometric and full-text search data
4. GIN: For array and full-text search operations*/
--part 1
-- Create tables
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
CREATE TABLE departments (
dept_id INT PRIMARY KEY,
dept_name VARCHAR(50),
location VARCHAR(50)
);
CREATE TABLE employees (
emp_id INT PRIMARY KEY,
emp_name VARCHAR(100),
dept_id INT,
salary DECIMAL(10,2),
FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);
CREATE TABLE projects (
proj_id INT PRIMARY KEY,
proj_name VARCHAR(100),
budget DECIMAL(12,2),
dept_id INT,
FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);
-- Insert sample data
INSERT INTO departments VALUES
(101, 'IT', 'Building A'),
(102, 'HR', 'Building B'),
(103, 'Operations', 'Building C');
INSERT INTO employees VALUES
(1, 'John Smith', 101, 50000),
(2, 'Jane Doe', 101, 55000),
(3, 'Mike Johnson', 102, 48000),
(4, 'Sarah Williams', 102, 52000),
(5, 'Tom Brown', 103, 60000);
INSERT INTO projects VALUES
(201, 'Website Redesign', 75000, 101),
(202, 'Database Migration', 120000, 101),
(203, 'HR System Upgrade', 50000, 102);

--part 2
--2,1
CREATE INDEX emp_salary_idx ON employees(salary);

SELECT pg_indexes.indexname,pg_indexes.indexdef FROM pg_indexes WHERE tablename='employees';
--Question: How many indexes exist on the employees table? 2

--2,2
CREATE INDEX emp_dept_idx ON employees(dept_id);

SELECT *FROM employees WHERE dept_id=101;

--2,3
SELECT
    pg_indexes.tablename,
    pg_indexes.indexname,
    pg_indexes.indexdef
FROM pg_indexes WHERE schemaname='public'
ORDER BY tablename,indexdef;
--Question: List all the indexes you see. Which ones were created automatically? primary keys

--part 3
--3,1
CREATE INDEX emp_dept_salary_idx ON employees(dept_id, salary);

SELECT emp_name, salary
FROM employees
WHERE dept_id = 101 AND salary > 52000;
--Question: Would this index be useful for a query that only filters by salary (without dept_id)? Why or why not?
--Not useful if filtering ONLY salary (because dept_id is first)

--3.2
CREATE INDEX emp_salary_dept_idx ON employees(salary, dept_id);

SELECT * FROM employees WHERE dept_id = 102 AND salary > 50000;
SELECT * FROM employees WHERE salary > 50000 AND dept_id = 102;
--Question: Does the order of columns in a multicolumn index matter? Explain.
--Yes. Index works best by the first column.

--part 4
--4.1
ALTER TABLE employees ADD COLUMN email VARCHAR(100);
UPDATE employees SET email = 'john.smith@company.com' WHERE emp_id = 1;
UPDATE employees SET email = 'jane.doe@company.com' WHERE emp_id = 2;
UPDATE employees SET email = 'mike.johnson@company.com' WHERE emp_id = 3;
UPDATE employees SET email = 'sarah.williams@company.com' WHERE emp_id = 4;
UPDATE employees SET email = 'tom.brown@company.com' WHERE emp_id = 5;

INSERT INTO employees (emp_id, emp_name, dept_id, salary, email)
VALUES (6, 'New Employee', 101, 55000, 'john.smith@company.com');
--answer: ERROR: duplicate key value violates unique constraint

--4.2
ALTER TABLE employees ADD COLUMN phone VARCHAR(20) UNIQUE;
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees' AND indexname LIKE '%phone%';
--Question: Did PostgreSQL automatically create an index? What type of index?
--answer:  PostgreSQL creates B-TREE index automatically.

--part 5
--5,1
CREATE INDEX emp_salary_desc_idx ON employees(salary DESC);

SELECT employees.emp_name,employees.salary FROM employees ORDER BY salary DESC
--Question: How does this index help with ORDER BY queries?
--answer:Index avoids sorting, speeds up ORDER BY DESC

--5.2
CREATE INDEX proj_budget_nulls_first_idx ON projects(budget NULLS FIRST);

SELECT proj_name, budget
FROM projects
ORDER BY budget NULLS FIRST;

--part 6
--6.1
CREATE INDEX emp_name_lower_idx ON employees(LOWER(employees.emp_name));
SELECT * FROM employees WHERE LOWER(emp_name) = 'john smith';
--Question: Without this index, how would PostgreSQL search for names case-insensitively?
--ANswer:  PostgreSQL will scan all rows

--6.2
ALTER TABLE employees ADD COLUMN hire_date DATE;

UPDATE employees SET hire_date='2020-01-15' WHERE emp_id=1;
UPDATE employees SET hire_date='2019-06-20' WHERE emp_id=2;
UPDATE employees SET hire_date='2021-03-10' WHERE emp_id=3;
UPDATE employees SET hire_date='2020-11-05' WHERE emp_id=4;
UPDATE employees SET hire_date='2018-08-25' WHERE emp_id=5;

CREATE INDEX emp_hire_year_idx ON employees(EXTRACT(YEAR FROM hire_date));

SELECT emp_name, hire_date
FROM employees
WHERE EXTRACT(YEAR FROM hire_date)=2020;

--part7 Managing Indexes
--7.1
ALTER INDEX emp_salary_idx RENAME TO employees_salary_index;
SELECT indexname FROM pg_indexes WHERE tablename = 'employees';

--7.2
DROP INDEX emp_salary_idx;
--Question: Why might you want to drop an index? Because its what task asked and Drop index if unused, duplicate, or slows writes

--7.3
REINDEX INDEX employees_salary_index;

--part 8 Practical Scenarios
--8.1
SELECT e.emp_name, e.salary, d.dept_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 50000
ORDER BY e.salary DESC;

CREATE INDEX emp_salary_filter_idx ON employees(salary) WHERE salary>50000;

--8.2
CREATE INDEX proj_high_budget_idx ON projects(budget)
WHERE budget > 8000;

SELECT proj_name, budget
FROM projects
WHERE budget > 80000;
--answer: Partial index = smaller, faster, only for needed rows

--8.3
EXPLAIN SELECT * FROM employees WHERE salary > 52000;
--seq scan

--part 9 Index Types Comparison Exercise
--9.1
CREATE INDEX dept_name_hash ON departments USING HASH(dept_name);
SELECT * FROM departments WHERE dept_name = 'IT';
-- Use HASH only for equality =, not for ranges

--9.2
CREATE INDEX proj_name_btree_idx ON projects(proj_name);
CREATE INDEX proj_name_hash_idx ON projects USING HASH (proj_name);

SELECT * FROM projects WHERE proj_name='Website Redesign';
SELECT * FROM projects WHERE proj_name > 'Database';
-- ANSWER: Range queries work only on B-tree

--part 10 Cleanup and Best Practices
--10.1
SELECT
    pg_indexes.schemaname,
    pg_indexes.tablename,
    pg_indexes.indexname,
    pg_size_pretty(pg_relation_size(pg_indexes.indexname::regclass)) as index_size
FROM pg_indexes WHERE schemaname='Public' ORDER BY tablename,indexname;
--on columns with biggest data or long strings

--10.2
DROP INDEX IF EXISTS proj_name_hash_idx;

--10.3
CREATE VIEW index_documentation AS
SELECT tablename, indexname, indexdef,
       'Improves salary-based queries' AS purpose
FROM pg_indexes
WHERE schemaname='public' AND indexname LIKE '%salary%';

SELECT * FROM index_documentation;

-- 1. ANSWER: Default index type = B-tree
-- 2. ANSWER: Use index for WHERE, JOIN, ORDER BY
-- 3. ANSWER: Do NOT index small tables or rarely-used columns
-- 4. ANSWER: INSERT/UPDATE/DELETE slow down because index updates
-- 5. ANSWER: Use EXPLAIN or EXPLAIN ANALYZE

