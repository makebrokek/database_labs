-- Part 1 – CHECK Constraints
CREATE TABLE employees (
    employee_id int PRIMARY KEY,
    first_name text,
    last_name text,
    age int CHECK (age BETWEEN 18 and 65),
    salary numeric CHECK (salary > 0)
);

CREATE TABLE products_catalog (
    product_id int PRIMARY KEY,
    product_name text,
    regular_price numeric,
    discount_price numeric,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0 AND
        discount_price > 0 AND
        discount_price < regular_price
    )
);

CREATE TABLE bookings (
    booking_id int PRIMARY KEY,
    check_in_date date,
    check_out_date date,
    num_guests int,
    CONSTRAINT booking_valid CHECK (
        num_guests BETWEEN 1 AND 10 AND
        check_out_date > check_in_date
    )
);

-- Part 2 – NOT NULL Constraints
CREATE TABLE customers_nn (
    customer_id int NOT NULL PRIMARY KEY,
    email text NOT NULL,
    phone text,
    registration_date date NOT NULL
);

CREATE TABLE inventory (
    item_id int NOT NULL PRIMARY KEY,
    item_name text NOT NULL,
    quantity int NOT NULL CHECK (quantity >= 0),
    unit_price numeric NOT NULL CHECK (unit_price > 0),
    last_updated timestamp NOT NULL
);

-- Part 3 – UNIQUE Constraints
CREATE TABLE users (
    user_id int PRIMARY KEY,
    username text,
    email text UNIQUE,
    created_at timestamp
);

ALTER TABLE users
ADD CONSTRAINT unique_username UNIQUE (username);

CREATE TABLE course_enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    student_id int,
    course_code text,
    semester text,
    CONSTRAINT unique_enrollment UNIQUE (student_id, course_code, semester)
);

-- Part 4 – PRIMARY KEY Constraints
CREATE TABLE departments (
    dept_id int PRIMARY KEY,
    dept_name text NOT NULL,
    location text
);

CREATE TABLE student_courses (
    student_id int,
    course_id int,
    enrollment_date date,
    grade text,
    PRIMARY KEY (student_id, course_id)
);

-- Part 5 – FOREIGN KEY Constraints
CREATE TABLE employees_dept (
    emp_id int PRIMARY KEY,
    emp_name text NOT NULL,
    dept_id int REFERENCES departments,
    hire_date date
);

CREATE TABLE authors (
    author_id int PRIMARY KEY,
    author_name text NOT NULL,
    country text
);

CREATE TABLE publishers (
    publisher_id int PRIMARY KEY,
    publisher_name text NOT NULL,
    city text
);

CREATE TABLE books (
    book_id int PRIMARY KEY,
    title text NOT NULL,
    author_id int REFERENCES authors(author_id),
    publisher_id int REFERENCES publishers(publisher_id),
    publication_year int,
    isbn text UNIQUE
);

-- Insert with explicit IDs
INSERT INTO authors (author_id, author_name, country) VALUES
(1, 'George Orwell', 'United Kingdom'),
(2, 'Haruki Murakami', 'Japan'),
(3, 'Mukagali Makataev', 'Kazakhstan');

INSERT INTO publishers (publisher_id, publisher_name, city) VALUES
(1, 'Penguin Books', 'London'),
(2, 'Vintage', 'New York'),
(3, 'HarperCollins', 'London');

INSERT INTO books (book_id, title, author_id, publisher_id, publication_year, isbn) VALUES
(1, '1984', 1, 1, 1949, '9780451524935'),
(2, 'Animal Farm', 1, 1, 1945, '9780451526342'),
(3, 'Norwegian Wood', 2, 2, 1987, '9780375704024'),
(4, 'Kafka on the Shore', 2, 2, 2002, '9781400079278'),
(5, 'Pride and Prejudice', 3, 3, 1813, '9780062870600');

-- Foreign Keys with RESTRICT and CASCADE
CREATE TABLE categories (
    category_id int PRIMARY KEY,
    category_name text NOT NULL
);

CREATE TABLE products_fk (
    product_id int PRIMARY KEY,
    product_name text NOT NULL,
    category_id int REFERENCES categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE orders_fk (
    order_id int PRIMARY KEY,
    order_date date NOT NULL
);

CREATE TABLE order_items (
    item_id int PRIMARY KEY,
    order_id int REFERENCES orders_fk(order_id) ON DELETE CASCADE,
    product_id int REFERENCES products_fk(product_id),
    quantity int CHECK (quantity > 0)
);

-- Part 6 – Practical Application (E-commerce)
DROP TABLE IF EXISTS order_details CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id) ON DELETE RESTRICT,
    order_date DATE NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

CREATE TABLE order_details (
    order_detail_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0)
);  
