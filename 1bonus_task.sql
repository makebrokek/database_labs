
-- KAZFINANCE BANK - BANKING TRANSACTION SYSTEM
-- Complete PostgreSQL Solution with Transactions, Stored Procedures, Views, and Indexes


-- Clean up existing objects (for development purposes)
DROP MATERIALIZED VIEW IF EXISTS salary_batch_summary CASCADE;
DROP VIEW IF EXISTS suspicious_activity_view CASCADE;
DROP VIEW IF EXISTS daily_transaction_report CASCADE;
DROP VIEW IF EXISTS customer_balance_summary CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS exchange_rates CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- SECTION 1: DATABASE SCHEMA CREATION
-- Create custom types for better data integrity
CREATE TYPE customer_status AS ENUM ('active', 'blocked', 'frozen');
CREATE TYPE currency_type AS ENUM ('KZT', 'USD', 'EUR', 'RUB');
CREATE TYPE transaction_type AS ENUM ('transfer', 'deposit', 'withdrawal', 'salary');
CREATE TYPE transaction_status AS ENUM ('pending', 'completed', 'failed', 'reversed');
CREATE TYPE audit_action AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- Customers Table
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    iin VARCHAR(12) NOT NULL UNIQUE CHECK (iin ~ '^\d{12}$'),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255) UNIQUE,
    status customer_status DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    daily_limit_kzt NUMERIC(15, 2) DEFAULT 10000000.00 CHECK (daily_limit_kzt > 0)
);

COMMENT ON TABLE customers IS 'Customer information for KazFinance Bank';
COMMENT ON COLUMN customers.iin IS 'Individual Identification Number - 12 digits';
COMMENT ON COLUMN customers.daily_limit_kzt IS 'Daily transaction limit in KZT';

-- Accounts Table
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    account_number VARCHAR(34) NOT NULL UNIQUE CHECK (account_number ~ '^KZ[0-9]{2}[A-Z0-9]{16}$'),
    currency currency_type NOT NULL DEFAULT 'KZT',
    balance NUMERIC(18, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP WITH TIME ZONE
);

COMMENT ON TABLE accounts IS 'Customer bank accounts with multi-currency support';
COMMENT ON COLUMN accounts.account_number IS 'IBAN format account number for Kazakhstan';

-- Transactions Table
CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
    currency currency_type NOT NULL,
    exchange_rate NUMERIC(12, 6) DEFAULT 1.0,
    amount_kzt NUMERIC(18, 2) NOT NULL,
    type transaction_type NOT NULL,
    status transaction_status DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    description TEXT,
    batch_id UUID,
    CONSTRAINT valid_accounts CHECK (
        (type = 'deposit' AND to_account_id IS NOT NULL) OR
        (type = 'withdrawal' AND from_account_id IS NOT NULL) OR
        (type IN ('transfer', 'salary') AND from_account_id IS NOT NULL AND to_account_id IS NOT NULL)
    )
);

COMMENT ON TABLE transactions IS 'All financial transactions with full audit trail';

-- Exchange Rates Table
CREATE TABLE exchange_rates (
    rate_id SERIAL PRIMARY KEY,
    from_currency currency_type NOT NULL,
    to_currency currency_type NOT NULL,
    rate NUMERIC(12, 6) NOT NULL CHECK (rate > 0),
    valid_from TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMP WITH TIME ZONE,
    CONSTRAINT unique_rate_period UNIQUE (from_currency, to_currency, valid_from),
    CONSTRAINT valid_period CHECK (valid_to IS NULL OR valid_to > valid_from)
);

COMMENT ON TABLE exchange_rates IS 'Currency exchange rates with validity periods';

-- Audit Log Table
CREATE TABLE audit_log (
    log_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(63) NOT NULL,
    record_id INTEGER NOT NULL,
    action audit_action NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(63) DEFAULT CURRENT_USER,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    session_id TEXT DEFAULT pg_backend_pid()::TEXT,
    error_message TEXT
);

COMMENT ON TABLE audit_log IS 'Complete audit trail for all database operations';

--INITIAL DATA POPULATION


-- Insert Customers 
INSERT INTO customers (iin, full_name, phone, email, status, daily_limit_kzt) VALUES
('010101500001', 'Алмас Сериков', '+77001234501', 'almas.serikov@mail.kz', 'active', 15000000.00),
('020202500002', 'Айгуль Нурланова', '+77001234502', 'aigul.nurlanova@mail.kz', 'active', 20000000.00),
('030303500003', 'Бауыржан Касымов', '+77001234503', 'baurzhan.kasymov@mail.kz', 'active', 10000000.00),
('040404500004', 'Гульнара Ахметова', '+77001234504', 'gulnara.akhmetova@mail.kz', 'blocked', 10000000.00),
('050505500005', 'Дәурен Оспанов', '+77001234505', 'dauren.ospanov@mail.kz', 'active', 25000000.00),
('060606500006', 'Еркін Мұратов', '+77001234506', 'erkin.muratov@mail.kz', 'frozen', 10000000.00),
('070707500007', 'Жансая Төлеуова', '+77001234507', 'zhansaya.toleuova@mail.kz', 'active', 50000000.00),
('080808500008', 'Ибрагим Жұмабаев', '+77001234508', 'ibragim.zhumabaev@mail.kz', 'active', 10000000.00),
('090909500009', 'Қарлығаш Сейітова', '+77001234509', 'karlygash.seitova@mail.kz', 'active', 30000000.00),
('101010500010', 'Ләззат Берікова', '+77001234510', 'lazzat.berikova@mail.kz', 'active', 10000000.00),
('111111500011', 'TechCorp Kazakhstan', '+77001234511', 'finance@techcorp.kz', 'active', 500000000.00),
('121212500012', 'Мұрат Назарбеков', '+77001234512', 'murat.nazarbekov@mail.kz', 'active', 10000000.00);

-- Insert Accounts 
INSERT INTO accounts (customer_id, account_number, currency, balance, is_active) VALUES
-- Customer 1 accounts
(1, 'KZ12KAZF0000000000001', 'KZT', 5000000.00, TRUE),
(1, 'KZ12KAZF0000000000002', 'USD', 10000.00, TRUE),
-- Customer 2 accounts
(2, 'KZ12KAZF0000000000003', 'KZT', 15000000.00, TRUE),
(2, 'KZ12KAZF0000000000004', 'EUR', 5000.00, TRUE),
-- Customer 3 accounts
(3, 'KZ12KAZF0000000000005', 'KZT', 2500000.00, TRUE),
(3, 'KZ12KAZF0000000000006', 'RUB', 100000.00, TRUE),
-- Customer 4 (blocked) accounts
(4, 'KZ12KAZF0000000000007', 'KZT', 8000000.00, TRUE),
-- Customer 5 accounts
(5, 'KZ12KAZF0000000000008', 'KZT', 25000000.00, TRUE),
(5, 'KZ12KAZF0000000000009', 'USD', 50000.00, TRUE),
-- Customer 6 (frozen) accounts
(6, 'KZ12KAZF0000000000010', 'KZT', 3000000.00, TRUE),
-- Customer 7 (high limit) accounts
(7, 'KZ12KAZF0000000000011', 'KZT', 100000000.00, TRUE),
(7, 'KZ12KAZF0000000000012', 'USD', 200000.00, TRUE),
-- Customer 8 accounts
(8, 'KZ12KAZF0000000000013', 'KZT', 1500000.00, TRUE),
-- Customer 9 accounts
(9, 'KZ12KAZF0000000000014', 'KZT', 20000000.00, TRUE),
(9, 'KZ12KAZF0000000000015', 'EUR', 10000.00, TRUE),
-- Customer 10 accounts
(10, 'KZ12KAZF0000000000016', 'KZT', 500000.00, TRUE),
-- Customer 11 (Company) accounts
(11, 'KZ12KAZF0000000000017', 'KZT', 1000000000.00, TRUE),
(11, 'KZ12KAZF0000000000018', 'USD', 2000000.00, TRUE),
-- Customer 12 accounts
(12, 'KZ12KAZF0000000000019', 'KZT', 3500000.00, TRUE),
-- Inactive account
(1, 'KZ12KAZF0000000000020', 'KZT', 0.00, FALSE);

-- Insert Exchange Rates
INSERT INTO exchange_rates (from_currency, to_currency, rate, valid_from, valid_to) VALUES
-- KZT base rates
('USD', 'KZT', 450.50, '2024-01-01 00:00:00+06', NULL),
('EUR', 'KZT', 495.30, '2024-01-01 00:00:00+06', NULL),
('RUB', 'KZT', 4.95, '2024-01-01 00:00:00+06', NULL),
-- Reverse rates
('KZT', 'USD', 0.00222, '2024-01-01 00:00:00+06', NULL),
('KZT', 'EUR', 0.00202, '2024-01-01 00:00:00+06', NULL),
('KZT', 'RUB', 0.202, '2024-01-01 00:00:00+06', NULL),
-- Cross rates
('USD', 'EUR', 0.92, '2024-01-01 00:00:00+06', NULL),
('EUR', 'USD', 1.09, '2024-01-01 00:00:00+06', NULL),
('USD', 'RUB', 91.00, '2024-01-01 00:00:00+06', NULL),
('RUB', 'USD', 0.011, '2024-01-01 00:00:00+06', NULL),
-- Historical rates (for testing)
('USD', 'KZT', 440.00, '2023-12-01 00:00:00+06', '2023-12-31 23:59:59+06'),
('EUR', 'KZT', 485.00, '2023-12-01 00:00:00+06', '2023-12-31 23:59:59+06');

-- Insert sample transactions
INSERT INTO transactions (from_account_id, to_account_id, amount, currency, exchange_rate, amount_kzt, type, status, created_at, completed_at, description) VALUES
(1, 3, 100000.00, 'KZT', 1.0, 100000.00, 'transfer', 'completed', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days', 'Payment for services'),
(3, 1, 250000.00, 'KZT', 1.0, 250000.00, 'transfer', 'completed', NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days', 'Refund'),
(2, 8, 1000.00, 'USD', 450.50, 450500.00, 'transfer', 'completed', NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days', 'International transfer'),
(8, 5, 500000.00, 'KZT', 1.0, 500000.00, 'transfer', 'completed', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days', 'Personal transfer'),
(11, 13, 1500000.00, 'KZT', 1.0, 1500000.00, 'salary', 'completed', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', 'Monthly salary'),
(NULL, 1, 2000000.00, 'KZT', 1.0, 2000000.00, 'deposit', 'completed', NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days', 'Cash deposit'),
(5, NULL, 100000.00, 'KZT', 1.0, 100000.00, 'withdrawal', 'completed', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', 'ATM withdrawal'),
(1, 3, 50000.00, 'KZT', 1.0, 50000.00, 'transfer', 'failed', NOW() - INTERVAL '2 hours', NULL, 'Failed transfer - insufficient funds'),
(12, 14, 6000000.00, 'KZT', 1.0, 6000000.00, 'transfer', 'completed', NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '30 minutes', 'Large transfer'),
(11, 16, 200000.00, 'KZT', 1.0, 200000.00, 'salary', 'completed', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', 'Salary payment');

-- Insert audit log entries
INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by, changed_at) VALUES
('accounts', 1, 'UPDATE', '{"balance": 3000000.00}', '{"balance": 5000000.00}', 'system', NOW() - INTERVAL '6 days'),
('customers', 4, 'UPDATE', '{"status": "active"}', '{"status": "blocked"}', 'admin', NOW() - INTERVAL '10 days'),
('transactions', 1, 'INSERT', NULL, '{"amount": 100000.00, "status": "completed"}', 'system', NOW() - INTERVAL '5 days'),
('accounts', 3, 'UPDATE', '{"balance": 14750000.00}', '{"balance": 15000000.00}', 'system', NOW() - INTERVAL '4 days'),
('customers', 6, 'UPDATE', '{"status": "active"}', '{"status": "frozen"}', 'compliance', NOW() - INTERVAL '7 days'),
('exchange_rates', 1, 'UPDATE', '{"rate": 445.00}', '{"rate": 450.50}', 'treasury', NOW() - INTERVAL '1 day'),
('accounts', 17, 'INSERT', NULL, '{"balance": 1000000000.00, "currency": "KZT"}', 'admin', NOW() - INTERVAL '30 days'),
('transactions', 8, 'UPDATE', '{"status": "pending"}', '{"status": "failed"}', 'system', NOW() - INTERVAL '2 hours'),
('customers', 1, 'UPDATE', '{"daily_limit_kzt": 10000000.00}', '{"daily_limit_kzt": 15000000.00}', 'manager', NOW() - INTERVAL '15 days'),
('accounts', 20, 'UPDATE', '{"is_active": true}', '{"is_active": false}', 'admin', NOW() - INTERVAL '20 days');

-- SECTION 3: HELPER FUNCTIONS

-- Function to get current exchange rate
CREATE OR REPLACE FUNCTION get_exchange_rate(
    p_from_currency currency_type,
    p_to_currency currency_type
) RETURNS NUMERIC AS $$
DECLARE
    v_rate NUMERIC(12, 6);
BEGIN
    IF p_from_currency = p_to_currency THEN
        RETURN 1.0;
    END IF;
    
    SELECT rate INTO v_rate
    FROM exchange_rates
    WHERE from_currency = p_from_currency
      AND to_currency = p_to_currency
      AND valid_from <= CURRENT_TIMESTAMP
      AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
    ORDER BY valid_from DESC
    LIMIT 1;
    
    IF v_rate IS NULL THEN
        RAISE EXCEPTION 'Exchange rate not found for % to %', p_from_currency, p_to_currency
            USING ERRCODE = 'P0002';
    END IF;
    
    RETURN v_rate;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to convert amount to KZT
CREATE OR REPLACE FUNCTION convert_to_kzt(
    p_amount NUMERIC,
    p_currency currency_type
) RETURNS NUMERIC AS $$
BEGIN
    IF p_currency = 'KZT' THEN
        RETURN p_amount;
    END IF;
    RETURN p_amount * get_exchange_rate(p_currency, 'KZT');
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get daily transaction total for a customer
CREATE OR REPLACE FUNCTION get_daily_transaction_total(
    p_customer_id INTEGER
) RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(t.amount_kzt), 0)
    INTO v_total
    FROM transactions t
    JOIN accounts a ON t.from_account_id = a.account_id
    WHERE a.customer_id = p_customer_id
      AND t.status IN ('completed', 'pending')
      AND t.created_at::DATE = CURRENT_DATE;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql STABLE;


--TASK 1 - TRANSACTION MANAGEMENT
--process_transfer Stored Procedure

CREATE OR REPLACE FUNCTION process_transfer(
    p_from_account_number VARCHAR(34),
    p_to_account_number VARCHAR(34),
    p_amount NUMERIC,
    p_currency currency_type,
    p_description TEXT DEFAULT NULL
) RETURNS TABLE (
    success BOOLEAN,
    transaction_id INTEGER,
    error_code VARCHAR(10),
    error_message TEXT,
    from_new_balance NUMERIC,
    to_new_balance NUMERIC
) AS $$
DECLARE
    v_from_account RECORD;
    v_to_account RECORD;
    v_from_customer RECORD;
    v_to_customer RECORD;
    v_exchange_rate_from NUMERIC(12, 6);
    v_exchange_rate_to NUMERIC(12, 6);
    v_amount_in_from_currency NUMERIC(18, 2);
    v_amount_in_to_currency NUMERIC(18, 2);
    v_amount_kzt NUMERIC(18, 2);
    v_daily_total NUMERIC;
    v_transaction_id INTEGER;
    v_error_code VARCHAR(10);
    v_error_message TEXT;
BEGIN
    -- Initialize return values
    success := FALSE;
    error_code := NULL;
    error_message := NULL;
    
    -- Validate amount
    IF p_amount <= 0 THEN
        v_error_code := 'ERR001';
        v_error_message := 'Transfer amount must be positive';
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Start transaction block with explicit locking
    -- Lock accounts in consistent order to prevent deadlocks
    IF p_from_account_number < p_to_account_number THEN
        SELECT a.*, c.customer_id as cust_id, c.status as cust_status, c.daily_limit_kzt
        INTO v_from_account
        FROM accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        WHERE a.account_number = p_from_account_number
        FOR UPDATE;
        
        SELECT a.*, c.customer_id as cust_id, c.status as cust_status
        INTO v_to_account
        FROM accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        WHERE a.account_number = p_to_account_number
        FOR UPDATE;
    ELSE
        SELECT a.*, c.customer_id as cust_id, c.status as cust_status
        INTO v_to_account
        FROM accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        WHERE a.account_number = p_to_account_number
        FOR UPDATE;
        
        SELECT a.*, c.customer_id as cust_id, c.status as cust_status, c.daily_limit_kzt
        INTO v_from_account
        FROM accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        WHERE a.account_number = p_from_account_number
        FOR UPDATE;
    END IF;
    
    -- Validate source account exists
    IF v_from_account IS NULL THEN
        v_error_code := 'ERR002';
        v_error_message := 'Source account not found: ' || p_from_account_number;
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Validate destination account exists
    IF v_to_account IS NULL THEN
        v_error_code := 'ERR003';
        v_error_message := 'Destination account not found: ' || p_to_account_number;
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Check source account is active
    IF NOT v_from_account.is_active THEN
        v_error_code := 'ERR004';
        v_error_message := 'Source account is not active';
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Check destination account is active
    IF NOT v_to_account.is_active THEN
        v_error_code := 'ERR005';
        v_error_message := 'Destination account is not active';
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Check sender's customer status
    IF v_from_account.cust_status != 'active' THEN
        v_error_code := 'ERR006';
        v_error_message := 'Sender customer status is ' || v_from_account.cust_status || ', transfers not allowed';
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency, 'customer_status', v_from_account.cust_status),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Calculate amounts in different currencies
    BEGIN
        -- Get exchange rates
        v_exchange_rate_from := get_exchange_rate(p_currency, v_from_account.currency);
        v_exchange_rate_to := get_exchange_rate(p_currency, v_to_account.currency);
        
        -- Amount to deduct from source (in source account's currency)
        v_amount_in_from_currency := p_amount * v_exchange_rate_from;
        
        -- Amount to add to destination (in destination account's currency)
        v_amount_in_to_currency := p_amount * v_exchange_rate_to;
        
        -- Amount in KZT for record keeping and limit checking
        v_amount_kzt := convert_to_kzt(p_amount, p_currency);
        
    EXCEPTION WHEN OTHERS THEN
        v_error_code := 'ERR007';
        v_error_message := 'Currency conversion error: ' || SQLERRM;
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END;
    
    -- Check sufficient balance
    IF v_from_account.balance < v_amount_in_from_currency THEN
        v_error_code := 'ERR008';
        v_error_message := format('Insufficient balance. Available: %s %s, Required: %s %s',
                                  v_from_account.balance, v_from_account.currency,
                                  v_amount_in_from_currency, v_from_account.currency);
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency,
                                   'available_balance', v_from_account.balance),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- Check daily transaction limit
    v_daily_total := get_daily_transaction_total(v_from_account.cust_id);
    
    IF (v_daily_total + v_amount_kzt) > v_from_account.daily_limit_kzt THEN
        v_error_code := 'ERR009';
        v_error_message := format('Daily limit exceeded. Limit: %s KZT, Used today: %s KZT, Requested: %s KZT',
                                  v_from_account.daily_limit_kzt, v_daily_total, v_amount_kzt);
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', 0, 'INSERT', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency,
                                   'daily_limit', v_from_account.daily_limit_kzt,
                                   'daily_used', v_daily_total),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, NULL::INTEGER, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END IF;
    
    -- All validations passed, create SAVEPOINT for the transfer
    SAVEPOINT transfer_start;
    
    BEGIN
        -- Create pending transaction record
        INSERT INTO transactions (
            from_account_id, to_account_id, amount, currency, 
            exchange_rate, amount_kzt, type, status, description
        ) VALUES (
            v_from_account.account_id, v_to_account.account_id, p_amount, p_currency,
            get_exchange_rate(p_currency, 'KZT'), v_amount_kzt, 'transfer', 'pending', p_description
        ) RETURNING transactions.transaction_id INTO v_transaction_id;
        
        -- Deduct from source account
        UPDATE accounts 
        SET balance = balance - v_amount_in_from_currency
        WHERE account_id = v_from_account.account_id;
        
        SAVEPOINT after_debit;
        
        -- Add to destination account
        UPDATE accounts 
        SET balance = balance + v_amount_in_to_currency
        WHERE account_id = v_to_account.account_id;
        
        -- Mark transaction as completed
        UPDATE transactions 
        SET status = 'completed', completed_at = CURRENT_TIMESTAMP
        WHERE transactions.transaction_id = v_transaction_id;
        
        -- Get new balances
        SELECT balance INTO from_new_balance
        FROM accounts WHERE account_id = v_from_account.account_id;
        
        SELECT balance INTO to_new_balance
        FROM accounts WHERE account_id = v_to_account.account_id;
        
        -- Log successful transaction
        INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
        VALUES ('transactions', v_transaction_id, 'INSERT', 
                NULL,
                jsonb_build_object(
                    'from_account', p_from_account_number,
                    'to_account', p_to_account_number,
                    'amount', p_amount,
                    'currency', p_currency,
                    'amount_kzt', v_amount_kzt,
                    'from_old_balance', v_from_account.balance,
                    'from_new_balance', from_new_balance,
                    'to_old_balance', v_to_account.balance,
                    'to_new_balance', to_new_balance,
                    'status', 'completed'
                ));
        
        success := TRUE;
        transaction_id := v_transaction_id;
        
        RETURN QUERY SELECT TRUE, v_transaction_id, NULL::VARCHAR(10), NULL::TEXT, from_new_balance, to_new_balance;
        RETURN;
        
    EXCEPTION WHEN OTHERS THEN
        -- Rollback to savepoint on any error
        ROLLBACK TO SAVEPOINT transfer_start;
        
        v_error_code := 'ERR010';
        v_error_message := 'Transfer failed: ' || SQLERRM;
        
        -- Update transaction status to failed if it was created
        IF v_transaction_id IS NOT NULL THEN
            UPDATE transactions 
            SET status = 'failed', description = COALESCE(description, '') || ' [FAILED: ' || SQLERRM || ']'
            WHERE transactions.transaction_id = v_transaction_id;
        END IF;
        
        INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
        VALUES ('transactions', COALESCE(v_transaction_id, 0), 'UPDATE', 
                jsonb_build_object('from_account', p_from_account_number, 'to_account', p_to_account_number, 
                                   'amount', p_amount, 'currency', p_currency, 'status', 'failed'),
                v_error_message);
        
        RETURN QUERY SELECT FALSE, v_transaction_id, v_error_code, v_error_message, NULL::NUMERIC, NULL::NUMERIC;
        RETURN;
    END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION process_transfer IS 'Processes money transfer between accounts with full ACID compliance';


--TASK 2 - VIEWS FOR REPORTING


-- View 1: customer_balance_summary
CREATE OR REPLACE VIEW customer_balance_summary AS
WITH account_balances AS (
    SELECT 
        c.customer_id,
        c.iin,
        c.full_name,
        c.status AS customer_status,
        c.daily_limit_kzt,
        a.account_id,
        a.account_number,
        a.currency,
        a.balance,
        a.is_active,
        -- Convert balance to KZT
        CASE 
            WHEN a.currency = 'KZT' THEN a.balance
            ELSE a.balance * COALESCE(
                (SELECT rate FROM exchange_rates er 
                 WHERE er.from_currency = a.currency 
                   AND er.to_currency = 'KZT' 
                   AND er.valid_from <= CURRENT_TIMESTAMP 
                   AND (er.valid_to IS NULL OR er.valid_to > CURRENT_TIMESTAMP)
                 ORDER BY er.valid_from DESC LIMIT 1),
                1.0
            )
        END AS balance_kzt
    FROM customers c
    LEFT JOIN accounts a ON c.customer_id = a.customer_id AND a.is_active = TRUE
),
customer_totals AS (
    SELECT 
        customer_id,
        SUM(balance_kzt) AS total_balance_kzt
    FROM account_balances
    GROUP BY customer_id
),
daily_usage AS (
    SELECT 
        c.customer_id,
        COALESCE(SUM(t.amount_kzt), 0) AS daily_spent_kzt
    FROM customers c
    LEFT JOIN accounts a ON c.customer_id = a.customer_id
    LEFT JOIN transactions t ON t.from_account_id = a.account_id 
                              AND t.status IN ('completed', 'pending')
                              AND t.created_at::DATE = CURRENT_DATE
    GROUP BY c.customer_id
)
SELECT 
    ab.customer_id,
    ab.iin,
    ab.full_name,
    ab.customer_status,
    ab.account_number,
    ab.currency,
    ab.balance,
    ab.balance_kzt,
    ab.is_active,
    ct.total_balance_kzt,
    ab.daily_limit_kzt,
    du.daily_spent_kzt,
    ROUND((du.daily_spent_kzt / NULLIF(ab.daily_limit_kzt, 0)) * 100, 2) AS daily_limit_utilization_pct,
    -- Window functions to rank customers
    RANK() OVER (ORDER BY ct.total_balance_kzt DESC NULLS LAST) AS balance_rank,
    DENSE_RANK() OVER (ORDER BY ct.total_balance_kzt DESC NULLS LAST) AS balance_dense_rank,
    ROW_NUMBER() OVER (PARTITION BY ab.customer_id ORDER BY ab.balance_kzt DESC NULLS LAST) AS account_rank_within_customer,
    NTILE(4) OVER (ORDER BY ct.total_balance_kzt DESC NULLS LAST) AS balance_quartile
FROM account_balances ab
JOIN customer_totals ct ON ab.customer_id = ct.customer_id
JOIN daily_usage du ON ab.customer_id = du.customer_id
ORDER BY ct.total_balance_kzt DESC NULLS LAST, ab.customer_id, ab.balance_kzt DESC;

COMMENT ON VIEW customer_balance_summary IS 'Customer balance summary with all accounts, KZT conversion, daily limit utilization, and rankings';

-- View 2: daily_transaction_report
CREATE OR REPLACE VIEW daily_transaction_report AS
WITH daily_stats AS (
    SELECT 
        created_at::DATE AS transaction_date,
        type AS transaction_type,
        COUNT(*) AS transaction_count,
        SUM(amount_kzt) AS total_volume_kzt,
        AVG(amount_kzt) AS avg_amount_kzt,
        MIN(amount_kzt) AS min_amount_kzt,
        MAX(amount_kzt) AS max_amount_kzt,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_count,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count
    FROM transactions
    WHERE created_at >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY created_at::DATE, type
),
with_running_totals AS (
    SELECT 
        transaction_date,
        transaction_type,
        transaction_count,
        total_volume_kzt,
        avg_amount_kzt,
        min_amount_kzt,
        max_amount_kzt,
        completed_count,
        failed_count,
        -- Running totals using window functions
        SUM(transaction_count) OVER (
            PARTITION BY transaction_type 
            ORDER BY transaction_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_count,
        SUM(total_volume_kzt) OVER (
            PARTITION BY transaction_type 
            ORDER BY transaction_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_volume_kzt,
        -- Previous day values for growth calculation
        LAG(transaction_count) OVER (
            PARTITION BY transaction_type 
            ORDER BY transaction_date
        ) AS prev_day_count,
        LAG(total_volume_kzt) OVER (
            PARTITION BY transaction_type 
            ORDER BY transaction_date
        ) AS prev_day_volume
    FROM daily_stats
)
SELECT 
    transaction_date,
    transaction_type,
    transaction_count,
    total_volume_kzt,
    ROUND(avg_amount_kzt, 2) AS avg_amount_kzt,
    min_amount_kzt,
    max_amount_kzt,
    completed_count,
    failed_count,
    ROUND((failed_count::NUMERIC / NULLIF(transaction_count, 0)) * 100, 2) AS failure_rate_pct,
    running_count,
    running_volume_kzt,
    -- Day-over-day growth percentage
    CASE 
        WHEN prev_day_count IS NULL OR prev_day_count = 0 THEN NULL
        ELSE ROUND(((transaction_count - prev_day_count)::NUMERIC / prev_day_count) * 100, 2)
    END AS count_growth_pct,
    CASE 
        WHEN prev_day_volume IS NULL OR prev_day_volume = 0 THEN NULL
        ELSE ROUND(((total_volume_kzt - prev_day_volume) / prev_day_volume) * 100, 2)
    END AS volume_growth_pct,
    -- 7-day moving average
    ROUND(AVG(total_volume_kzt) OVER (
        PARTITION BY transaction_type 
        ORDER BY transaction_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS volume_7day_avg
FROM with_running_totals
ORDER BY transaction_date DESC, transaction_type;

COMMENT ON VIEW daily_transaction_report IS 'Daily transaction aggregates with running totals and growth metrics';

-- View 3: suspicious_activity_view (WITH SECURITY BARRIER)
CREATE OR REPLACE VIEW suspicious_activity_view 
WITH (security_barrier = true) AS
WITH large_transactions AS (
    -- Flag transactions over 5,000,000 KZT equivalent
    SELECT 
        t.transaction_id,
        t.from_account_id,
        t.to_account_id,
        t.amount,
        t.currency,
        t.amount_kzt,
        t.created_at,
        t.type,
        t.status,
        'LARGE_TRANSACTION' AS alert_type,
        'Transaction exceeds 5,000,000 KZT threshold' AS alert_reason
    FROM transactions t
    WHERE t.amount_kzt > 5000000
      AND t.status = 'completed'
),
high_frequency_customers AS (
    -- Identify customers with >10 transactions in a single hour
    SELECT 
        t.transaction_id,
        t.from_account_id,
        t.to_account_id,
        t.amount,
        t.currency,
        t.amount_kzt,
        t.created_at,
        t.type,
        t.status,
        'HIGH_FREQUENCY' AS alert_type,
        'Customer has more than 10 transactions in 1 hour' AS alert_reason
    FROM transactions t
    JOIN accounts a ON t.from_account_id = a.account_id
    WHERE t.status = 'completed'
      AND (
          SELECT COUNT(*) 
          FROM transactions t2 
          JOIN accounts a2 ON t2.from_account_id = a2.account_id
          WHERE a2.customer_id = a.customer_id
            AND t2.status = 'completed'
            AND t2.created_at BETWEEN t.created_at - INTERVAL '1 hour' AND t.created_at
      ) > 10
),
rapid_transfers AS (
    -- Detect rapid sequential transfers (same sender, <1 minute apart)
    SELECT 
        t.transaction_id,
        t.from_account_id,
        t.to_account_id,
        t.amount,
        t.currency,
        t.amount_kzt,
        t.created_at,
        t.type,
        t.status,
        'RAPID_TRANSFER' AS alert_type,
        'Rapid sequential transfers detected (less than 1 minute apart)' AS alert_reason
    FROM transactions t
    WHERE t.type = 'transfer'
      AND t.status = 'completed'
      AND EXISTS (
          SELECT 1 
          FROM transactions t2 
          WHERE t2.from_account_id = t.from_account_id
            AND t2.transaction_id != t.transaction_id
            AND t2.type = 'transfer'
            AND t2.status = 'completed'
            AND ABS(EXTRACT(EPOCH FROM (t2.created_at - t.created_at))) < 60
      )
)
SELECT 
    sa.transaction_id,
    sa.alert_type,
    sa.alert_reason,
    sa.from_account_id,
    fa.account_number AS from_account_number,
    fc.full_name AS from_customer_name,
    fc.iin AS from_customer_iin,
    sa.to_account_id,
    ta.account_number AS to_account_number,
    tc.full_name AS to_customer_name,
    sa.amount,
    sa.currency,
    sa.amount_kzt,
    sa.type AS transaction_type,
    sa.status,
    sa.created_at,
    CURRENT_TIMESTAMP AS report_generated_at
FROM (
    SELECT * FROM large_transactions
    UNION ALL
    SELECT * FROM high_frequency_customers
    UNION ALL
    SELECT * FROM rapid_transfers
) sa
LEFT JOIN accounts fa ON sa.from_account_id = fa.account_id
LEFT JOIN customers fc ON fa.customer_id = fc.customer_id
LEFT JOIN accounts ta ON sa.to_account_id = ta.account_id
LEFT JOIN customers tc ON ta.customer_id = tc.customer_id
ORDER BY sa.created_at DESC, sa.alert_type;

COMMENT ON VIEW suspicious_activity_view IS 'Suspicious activity monitoring with SECURITY BARRIER for regulatory compliance';


-- SECTION 6: TASK 3 - PERFORMANCE OPTIMIZATION WITH INDEXES

-- 1. B-tree Index (Standard) - For frequently queried columns
CREATE INDEX idx_transactions_created_at ON transactions (created_at DESC);
COMMENT ON INDEX idx_transactions_created_at IS 'B-tree index for transaction date queries and sorting';

-- 2. Composite Index - For combined queries
CREATE INDEX idx_transactions_account_status_date ON transactions (from_account_id, status, created_at DESC);
COMMENT ON INDEX idx_transactions_account_status_date IS 'Composite index for account transaction history queries';

-- 3. Partial Index - For active accounts only (most common queries)
CREATE INDEX idx_accounts_active ON accounts (customer_id, currency, balance) 
WHERE is_active = TRUE;
COMMENT ON INDEX idx_accounts_active IS 'Partial index for active accounts - reduces index size and improves query performance';

-- 4. Expression Index - For case-insensitive email search
CREATE INDEX idx_customers_email_lower ON customers (LOWER(email));
COMMENT ON INDEX idx_customers_email_lower IS 'Expression index for case-insensitive email lookups';

-- 5. Hash Index - For exact match lookups (account number)
CREATE INDEX idx_accounts_number_hash ON accounts USING HASH (account_number);
COMMENT ON INDEX idx_accounts_number_hash IS 'Hash index for exact account number lookups';

-- 6. GIN Index - For JSONB columns in audit_log
CREATE INDEX idx_audit_log_old_values ON audit_log USING GIN (old_values jsonb_path_ops);
CREATE INDEX idx_audit_log_new_values ON audit_log USING GIN (new_values jsonb_path_ops);
COMMENT ON INDEX idx_audit_log_old_values IS 'GIN index for querying old_values JSONB column';
COMMENT ON INDEX idx_audit_log_new_values IS 'GIN index for querying new_values JSONB column';

-- 7. Covering Index (INCLUDE) - For the most frequent query pattern
CREATE INDEX idx_transactions_covering ON transactions (from_account_id, created_at DESC) 
INCLUDE (amount, amount_kzt, status, type);
COMMENT ON INDEX idx_transactions_covering IS 'Covering index to avoid table lookups for common queries';

-- 8. Index for exchange rate lookups
CREATE INDEX idx_exchange_rates_lookup ON exchange_rates (from_currency, to_currency, valid_from DESC) 
WHERE valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP;
COMMENT ON INDEX idx_exchange_rates_lookup IS 'Index for current exchange rate lookups';

-- 9. Index for daily limit checks
CREATE INDEX idx_transactions_daily_limit ON transactions (from_account_id, (created_at::DATE), status) 
WHERE status IN ('completed', 'pending');
COMMENT ON INDEX idx_transactions_daily_limit IS 'Index for daily transaction limit calculations';

-- 10. Customer IIN lookup index
CREATE UNIQUE INDEX idx_customers_iin ON customers (iin);
COMMENT ON INDEX idx_customers_iin IS 'Unique index for IIN lookups';


-- SECTION 7: TASK 4 - BATCH PROCESSING PROCEDURE

CREATE OR REPLACE FUNCTION process_salary_batch(
    p_company_account_number VARCHAR(34),
    p_payments JSONB
) RETURNS TABLE (
    batch_id UUID,
    successful_count INTEGER,
    failed_count INTEGER,
    total_amount_processed NUMERIC,
    total_amount_failed NUMERIC,
    failed_details JSONB,
    processing_time_ms BIGINT
) AS $$
DECLARE
    v_batch_id UUID := gen_random_uuid();
    v_start_time TIMESTAMP := clock_timestamp();
    v_company_account RECORD;
    v_payment RECORD;
    v_recipient_account RECORD;
    v_recipient_customer RECORD;
    v_successful_count INTEGER := 0;
    v_failed_count INTEGER := 0;
    v_total_processed NUMERIC := 0;
    v_total_failed NUMERIC := 0;
    v_failed_details JSONB := '[]'::JSONB;
    v_total_batch_amount NUMERIC;
    v_exchange_rate NUMERIC;
    v_amount_kzt NUMERIC;
    v_payment_amount NUMERIC;
    v_payment_iin VARCHAR(12);
    v_payment_desc TEXT;
    v_lock_key BIGINT;
    v_lock_acquired BOOLEAN;
    v_updates JSONB := '[]'::JSONB;
BEGIN
    -- Generate lock key from company account number
    v_lock_key := hashtext(p_company_account_number)::BIGINT;
    
    -- Try to acquire advisory lock (prevent concurrent batch processing for same company)
    v_lock_acquired := pg_try_advisory_lock(v_lock_key);
    
    IF NOT v_lock_acquired THEN
        RAISE EXCEPTION 'Another batch process is running for this company account'
            USING ERRCODE = 'P0003';
    END IF;
    
    BEGIN
        -- Get and lock company account
        SELECT a.*, c.customer_id as cust_id, c.status as cust_status
        INTO v_company_account
        FROM accounts a
        JOIN customers c ON a.customer_id = c.customer_id
        WHERE a.account_number = p_company_account_number
          AND a.is_active = TRUE
        FOR UPDATE;
        
        IF v_company_account IS NULL THEN
            PERFORM pg_advisory_unlock(v_lock_key);
            RAISE EXCEPTION 'Company account not found or inactive: %', p_company_account_number
                USING ERRCODE = 'P0001';
        END IF;
        
        IF v_company_account.cust_status != 'active' THEN
            PERFORM pg_advisory_unlock(v_lock_key);
            RAISE EXCEPTION 'Company customer status is not active: %', v_company_account.cust_status
                USING ERRCODE = 'P0002';
        END IF;
        
        -- Calculate total batch amount
        SELECT COALESCE(SUM((elem->>'amount')::NUMERIC), 0)
        INTO v_total_batch_amount
        FROM jsonb_array_elements(p_payments) elem;
        
        -- Convert to company account currency if needed
        IF v_company_account.currency != 'KZT' THEN
            v_total_batch_amount := v_total_batch_amount * get_exchange_rate('KZT', v_company_account.currency);
        END IF;
        
        -- Validate total batch amount against company account balance
        IF v_company_account.balance < v_total_batch_amount THEN
            PERFORM pg_advisory_unlock(v_lock_key);
            RAISE EXCEPTION 'Insufficient balance for batch. Required: % %, Available: % %',
                v_total_batch_amount, v_company_account.currency,
                v_company_account.balance, v_company_account.currency
                USING ERRCODE = 'P0004';
        END IF;
        
        -- Process each payment
        FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments)
        LOOP
            v_payment_iin := v_payment.value->>'iin';
            v_payment_amount := (v_payment.value->>'amount')::NUMERIC;
            v_payment_desc := COALESCE(v_payment.value->>'description', 'Salary payment');
            
            -- Create savepoint for each individual payment
            SAVEPOINT payment_savepoint;
            
            BEGIN
                -- Find recipient by IIN
                SELECT c.* INTO v_recipient_customer
                FROM customers c
                WHERE c.iin = v_payment_iin
                  AND c.status = 'active';
                
                IF v_recipient_customer IS NULL THEN
                    RAISE EXCEPTION 'Recipient not found or inactive: %', v_payment_iin;
                END IF;
                
                -- Find recipient's KZT account (preferred) or first active account
                SELECT a.* INTO v_recipient_account
                FROM accounts a
                WHERE a.customer_id = v_recipient_customer.customer_id
                  AND a.is_active = TRUE
                ORDER BY CASE WHEN a.currency = 'KZT' THEN 0 ELSE 1 END, a.account_id
                LIMIT 1
                FOR UPDATE;
                
                IF v_recipient_account IS NULL THEN
                    RAISE EXCEPTION 'No active account found for recipient: %', v_payment_iin;
                END IF;
                
                -- Calculate exchange rates
                v_exchange_rate := get_exchange_rate('KZT', v_recipient_account.currency);
                v_amount_kzt := v_payment_amount;
                
                -- Store update info for batch update at the end
                v_updates := v_updates || jsonb_build_object(
                    'account_id', v_recipient_account.account_id,
                    'amount', v_payment_amount * v_exchange_rate,
                    'amount_kzt', v_amount_kzt,
                    'iin', v_payment_iin
                );
                
                -- Create transaction record (salary type bypasses daily limits)
                INSERT INTO transactions (
                    from_account_id, to_account_id, amount, currency,
                    exchange_rate, amount_kzt, type, status, description, batch_id
                ) VALUES (
                    v_company_account.account_id, v_recipient_account.account_id,
                    v_payment_amount, 'KZT', 1.0, v_amount_kzt,
                    'salary', 'pending', v_payment_desc, v_batch_id
                );
                
                v_successful_count := v_successful_count + 1;
                v_total_processed := v_total_processed + v_payment_amount;
                
            EXCEPTION WHEN OTHERS THEN
                -- Rollback to savepoint and continue
                ROLLBACK TO SAVEPOINT payment_savepoint;
                
                v_failed_count := v_failed_count + 1;
                v_total_failed := v_total_failed + COALESCE(v_payment_amount, 0);
                
                v_failed_details := v_failed_details || jsonb_build_object(
                    'iin', v_payment_iin,
                    'amount', v_payment_amount,
                    'error', SQLERRM
                );
                
                -- Log failed payment
                INSERT INTO audit_log (table_name, record_id, action, new_values, error_message)
                VALUES ('transactions', 0, 'INSERT',
                        jsonb_build_object('batch_id', v_batch_id, 'iin', v_payment_iin, 'amount', v_payment_amount),
                        'Salary payment failed: ' || SQLERRM);
            END;
        END LOOP;
        
        -- Atomic update of all balances at the end
        IF v_successful_count > 0 THEN
            -- Deduct total from company account
            UPDATE accounts
            SET balance = balance - (
                SELECT SUM((elem->>'amount_kzt')::NUMERIC * 
                       get_exchange_rate('KZT', v_company_account.currency))
                FROM jsonb_array_elements(v_updates) elem
            )
            WHERE account_id = v_company_account.account_id;
            
            -- Credit each recipient account
            UPDATE accounts a
            SET balance = balance + updates.amount
            FROM (
                SELECT (elem->>'account_id')::INTEGER as account_id,
                       (elem->>'amount')::NUMERIC as amount
                FROM jsonb_array_elements(v_updates) elem
            ) updates
            WHERE a.account_id = updates.account_id;
            
            -- Mark all pending salary transactions as completed
            UPDATE transactions
            SET status = 'completed', completed_at = CURRENT_TIMESTAMP
            WHERE transactions.batch_id = v_batch_id AND status = 'pending';
        END IF;
        
        -- Log successful batch processing
        INSERT INTO audit_log (table_name, record_id, action, new_values)
        VALUES ('transactions', 0, 'INSERT',
                jsonb_build_object(
                    'batch_id', v_batch_id,
                    'company_account', p_company_account_number,
                    'successful_count', v_successful_count,
                    'failed_count', v_failed_count,
                    'total_processed', v_total_processed,
                    'total_failed', v_total_failed
                ));
        
        -- Release advisory lock
        PERFORM pg_advisory_unlock(v_lock_key);
        
        -- Return results
        batch_id := v_batch_id;
        successful_count := v_successful_count;
        failed_count := v_failed_count;
        total_amount_processed := v_total_processed;
        total_amount_failed := v_total_failed;
        failed_details := v_failed_details;
        processing_time_ms := EXTRACT(MILLISECONDS FROM (clock_timestamp() - v_start_time))::BIGINT;
        
        RETURN NEXT;
        RETURN;
        
    EXCEPTION WHEN OTHERS THEN
        -- Release lock on error
        PERFORM pg_advisory_unlock(v_lock_key);
        RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION process_salary_batch IS 'Processes batch salary payments with advisory locks and partial failure handling';

-- Materialized view for salary batch summary
CREATE MATERIALIZED VIEW salary_batch_summary AS
SELECT 
    t.batch_id,
    MIN(t.created_at) AS batch_started_at,
    MAX(t.completed_at) AS batch_completed_at,
    fa.account_number AS company_account,
    fc.full_name AS company_name,
    COUNT(*) AS total_payments,
    SUM(CASE WHEN t.status = 'completed' THEN 1 ELSE 0 END) AS successful_payments,
    SUM(CASE WHEN t.status = 'failed' THEN 1 ELSE 0 END) AS failed_payments,
    SUM(CASE WHEN t.status = 'completed' THEN t.amount_kzt ELSE 0 END) AS total_amount_kzt,
    AVG(CASE WHEN t.status = 'completed' THEN t.amount_kzt END) AS avg_payment_kzt,
    MIN(CASE WHEN t.status = 'completed' THEN t.amount_kzt END) AS min_payment_kzt,
    MAX(CASE WHEN t.status = 'completed' THEN t.amount_kzt END) AS max_payment_kzt
FROM transactions t
JOIN accounts fa ON t.from_account_id = fa.account_id
JOIN customers fc ON fa.customer_id = fc.customer_id
WHERE t.type = 'salary' AND t.batch_id IS NOT NULL
GROUP BY t.batch_id, fa.account_number, fc.full_name;

CREATE UNIQUE INDEX idx_salary_batch_summary_batch_id ON salary_batch_summary (batch_id);

COMMENT ON MATERIALIZED VIEW salary_batch_summary IS 'Summary report for salary batch processing';

-- Function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_salary_batch_summary()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY salary_batch_summary;
END;
$$ LANGUAGE plpgsql;


-- AUDIT TRIGGERS

-- Trigger function for automatic audit logging
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_values)
        VALUES (TG_TABLE_NAME, NEW.customer_id, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
        VALUES (TG_TABLE_NAME, NEW.customer_id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values)
        VALUES (TG_TABLE_NAME, OLD.customer_id, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit trigger to customers table
CREATE TRIGGER customers_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON customers
FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();


-- TEST CASES

-- Test Case 1: Successful Transfer
DO $$
DECLARE
    result RECORD;
BEGIN
    RAISE NOTICE '=== TEST 1: Successful Transfer ===';
    SELECT * INTO result FROM process_transfer(
        'KZ12KAZF0000000000001',  -- From: Customer 1 KZT account
        'KZ12KAZF0000000000005',  -- To: Customer 3 KZT account
        100000.00,
        'KZT',
        'Test transfer - should succeed'
    );
    RAISE NOTICE 'Success: %, Transaction ID: %, From Balance: %, To Balance: %',
        result.success, result.transaction_id, result.from_new_balance, result.to_new_balance;
END $$;

-- Test Case 2: Transfer from blocked customer (should fail)
DO $$
DECLARE
    result RECORD;
BEGIN
    RAISE NOTICE '=== TEST 2: Transfer from Blocked Customer ===';
    SELECT * INTO result FROM process_transfer(
        'KZ12KAZF0000000000007',  -- From: Blocked customer
        'KZ12KAZF0000000000001',
        50000.00,
        'KZT',
        'Test transfer from blocked customer'
    );
    RAISE NOTICE 'Success: %, Error Code: %, Error Message: %',
        result.success, result.error_code, result.error_message;
END $$;

-- Test Case 3: Transfer with insufficient balance
DO $$
DECLARE
    result RECORD;
BEGIN
    RAISE NOTICE '=== TEST 3: Insufficient Balance Transfer ===';
    SELECT * INTO result FROM process_transfer(
        'KZ12KAZF0000000000016',  -- From: Customer 10 (low balance)
        'KZ12KAZF0000000000001',
        10000000.00,              -- More than available
        'KZT',
        'Test transfer with insufficient funds'
    );
    RAISE NOTICE 'Success: %, Error Code: %, Error Message: %',
        result.success, result.error_code, result.error_message;
END $$;

-- Test Case 4: Cross-currency transfer
DO $$
DECLARE
    result RECORD;
BEGIN
    RAISE NOTICE '=== TEST 4: Cross-Currency Transfer ===';
    SELECT * INTO result FROM process_transfer(
        'KZ12KAZF0000000000002',  -- From: Customer 1 USD account
        'KZ12KAZF0000000000004',  -- To: Customer 2 EUR account
        100.00,
        'USD',
        'Cross-currency transfer USD to EUR account'
    );
    RAISE NOTICE 'Success: %, Transaction ID: %, From Balance: %, To Balance: %',
        result.success, result.transaction_id, result.from_new_balance, result.to_new_balance;
END $$;

-- Test Case 5: Transfer to inactive account
DO $$
DECLARE
    result RECORD;
BEGIN
    RAISE NOTICE '=== TEST 5: Transfer to Inactive Account ===';
    SELECT * INTO result FROM process_transfer(
        'KZ12KAZF0000000000001',
        'KZ12KAZF0000000000020',  -- Inactive account
        10000.00,
        'KZT',
        'Transfer to inactive account'
    );
    RAISE NOTICE 'Success: %, Error Code: %, Error Message: %',
        result.success, result.error_code, result.error_message;
END $$;

-- Test Case 6: Salary Batch Processing
DO $$
DECLARE
    result RECORD;
    payments JSONB;
BEGIN
    RAISE NOTICE '=== TEST 6: Salary Batch Processing ===';
    
    payments := '[
        {"iin": "010101500001", "amount": 500000, "description": "January salary"},
        {"iin": "020202500002", "amount": 750000, "description": "January salary"},
        {"iin": "030303500003", "amount": 600000, "description": "January salary"},
        {"iin": "999999999999", "amount": 400000, "description": "Invalid IIN - should fail"},
        {"iin": "080808500008", "amount": 450000, "description": "January salary"}
    ]'::JSONB;
    
    SELECT * INTO result FROM process_salary_batch(
        'KZ12KAZF0000000000017',  -- TechCorp company account
        payments
    );
    
    RAISE NOTICE 'Batch ID: %, Successful: %, Failed: %, Total Processed: %, Processing Time: % ms',
        result.batch_id, result.successful_count, result.failed_count, 
        result.total_amount_processed, result.processing_time_ms;
    RAISE NOTICE 'Failed Details: %', result.failed_details;
END $$;

-- Test Case 7: View Tests
DO $$
BEGIN
    RAISE NOTICE '=== TEST 7: Testing Views ===';
    
    -- Test customer_balance_summary
    RAISE NOTICE 'Customer Balance Summary (Top 3):';
    PERFORM * FROM customer_balance_summary LIMIT 3;
    
    -- Test daily_transaction_report
    RAISE NOTICE 'Daily Transaction Report:';
    PERFORM * FROM daily_transaction_report LIMIT 5;
    
    -- Test suspicious_activity_view
    RAISE NOTICE 'Suspicious Activities:';
    PERFORM * FROM suspicious_activity_view LIMIT 5;
END $$;

-- Refresh materialized view
SELECT refresh_salary_batch_summary();


-- EXPLAIN ANALYZE FOR INDEX VERIFICATION

-- Query 1: Transaction lookup by account and date (uses composite index)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM transactions 
WHERE from_account_id = 1 
  AND status = 'completed' 
  AND created_at > CURRENT_DATE - INTERVAL '30 days'
ORDER BY created_at DESC;

-- Query 2: Active accounts lookup (uses partial index)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM accounts 
WHERE is_active = TRUE 
  AND customer_id = 1;

-- Query 3: Case-insensitive email search (uses expression index)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM customers 
WHERE LOWER(email) = 'almas.serikov@mail.kz';

-- Query 4: Account number lookup (uses hash index)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM accounts 
WHERE account_number = 'KZ12KAZF0000000000001';

-- Query 5: JSONB query on audit_log (uses GIN index)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM audit_log 
WHERE new_values @> '{"status": "completed"}'::JSONB;

-- Query 6: Exchange rate lookup (uses specialized index)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT rate FROM exchange_rates 
WHERE from_currency = 'USD' 
  AND to_currency = 'KZT' 
  AND valid_from <= CURRENT_TIMESTAMP 
  AND (valid_to IS NULL OR valid_to > CURRENT_TIMESTAMP)
ORDER BY valid_from DESC 
LIMIT 1;

-- Query 7: Covering index usage
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT from_account_id, created_at, amount, amount_kzt, status, type
FROM transactions
WHERE from_account_id = 1
ORDER BY created_at DESC
LIMIT 10;


--CONCURRENCY TEST SCRIPTS


/*

SESSION 1:
-----------
BEGIN;
SELECT * FROM process_transfer('KZ12KAZF0000000000001', 'KZ12KAZF0000000000005', 50000, 'KZT', 'Session 1 transfer');
-- Don't commit yet, wait for Session 2

SESSION 2:
-----------
-- This should wait until Session 1 commits or rolls back
SELECT * FROM process_transfer('KZ12KAZF0000000000001', 'KZ12KAZF0000000000003', 30000, 'KZT', 'Session 2 transfer');

SESSION 1:
-----------
COMMIT;
-- Now Session 2 should complete

-- Alternative test using explicit locking:
SESSION 1:
-----------
BEGIN;
SELECT * FROM accounts WHERE account_number = 'KZ12KAZF0000000000001' FOR UPDATE;
-- Hold lock...

SESSION 2:
-----------
-- This will wait
SELECT * FROM accounts WHERE account_number = 'KZ12KAZF0000000000001' FOR UPDATE;

SESSION 1:
-----------
COMMIT;
-- Session 2 proceeds
*/

-- ============================================================================
-- SECTION 12: DOCUMENTATION
-- ============================================================================

/*
DESIGN DECISIONS AND DOCUMENTATION
===================================

1. TRANSACTION MANAGEMENT (process_transfer)
   - Uses SELECT FOR UPDATE with consistent ordering to prevent deadlocks
   - Implements SAVEPOINT for granular rollback control
   - Returns detailed error information with specific error codes (ERR001-ERR010)
   - All operations are logged to audit_log, including failures
   - Currency conversion is handled dynamically using current exchange rates

2. VIEW DESIGN
   a) customer_balance_summary:
      - Uses CTEs for clarity and performance
      - Window functions: RANK(), DENSE_RANK(), ROW_NUMBER(), NTILE()
      - Calculates real-time daily limit utilization

   b) daily_transaction_report:
      - Uses LAG() for day-over-day comparisons
      - SUM() OVER() for running totals
      - 7-day moving average calculation

   c) suspicious_activity_view:
      - SECURITY BARRIER prevents information leakage in RLS scenarios
      - Implements three detection patterns: large transactions, high frequency, rapid transfers
      - Uses UNION ALL for combining alert types

3. INDEX STRATEGY
   - B-tree: Standard for range queries and ordering (transactions.created_at)
   - Hash: Optimized for exact match lookups (accounts.account_number)
   - Composite: Combined columns for multi-condition queries
   - Partial: Reduces index size by filtering (active accounts only)
   - Expression: Enables function-based lookups (LOWER(email))
   - GIN: Optimized for JSONB containment queries
   - Covering (INCLUDE): Eliminates table lookups for frequent queries

4. BATCH PROCESSING (process_salary_batch)
   - Advisory locks prevent concurrent batch processing for same company
   - SAVEPOINT per payment allows partial batch completion
   - Atomic balance updates at the end for consistency
   - Salary type transactions bypass daily limits
   - Materialized view provides summary reporting

5. CONCURRENCY HANDLING
   - Row-level locks via SELECT FOR UPDATE
   - Consistent lock ordering (by account_number) prevents deadlocks
   - Advisory locks for application-level coordination
   - All procedures are designed for high-concurrency environments

6. ERROR HANDLING
   - Custom SQLSTATE codes for specific error types
   - Detailed error messages with context
   - All errors are logged to audit_log
   - Graceful degradation in batch processing

7. AUDIT TRAIL
   - Complete logging of all operations
   - JSONB storage for flexible old/new values
   - Automatic triggers for customer table changes
   - Session and user tracking
*/

-- Final verification queries
SELECT 'Schema Created Successfully' as status;
SELECT COUNT(*) as customer_count FROM customers;
SELECT COUNT(*) as account_count FROM accounts;
SELECT COUNT(*) as transaction_count FROM transactions;
SELECT COUNT(*) as exchange_rate_count FROM exchange_rates;
SELECT COUNT(*) as audit_log_count FROM audit_log;
