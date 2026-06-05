-- ===========================================================================================
-- DENTAL CLINIC DATABASE - FINAL PROJECT
-- ===========================================================================================
-- Student: Zholgali Dias
-- Domain: Dental Clinic Management System
-- Database: dental_clinic_db
-- Schema: dental_clinic
-- ===========================================================================================

-- ===========================================================================================
-- PART 1: DATABASE AND SCHEMA SETUP
-- ===========================================================================================

DO $$
BEGIN
    -- Create schema if not exists
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'dental_clinic') THEN
        CREATE SCHEMA dental_clinic;
    END IF;
END $$;

SET search_path TO dental_clinic;

-- ===========================================================================================
-- PART 2: CREATE TABLES WITH CONSTRAINTS
-- ===========================================================================================

CREATE TABLE IF NOT EXISTS dental_clinic.insurance_plan (
    plan_id SERIAL PRIMARY KEY,
    plan_name VARCHAR(100) NOT NULL UNIQUE,
    provider_name VARCHAR(100) NOT NULL,
    coverage_percentage NUMERIC(5,2) NOT NULL CHECK (coverage_percentage >= 0 AND coverage_percentage <= 100),
    annual_maximum NUMERIC(10,2) NOT NULL CHECK (annual_maximum >= 0)
);

CREATE TABLE IF NOT EXISTS dental_clinic.dentist (
    dentist_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    full_name VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    specialization VARCHAR(50) NOT NULL CHECK (specialization IN ('General', 'Orthodontist', 'Endodontist', 'Periodontist', 'Oral Surgeon')),
    phone VARCHAR(15) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    license_number VARCHAR(30) NOT NULL UNIQUE,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS dental_clinic.patient (
    patient_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    full_name VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    date_of_birth DATE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(120) UNIQUE,
    address TEXT,
    plan_id INT,
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT fk_patient_plan FOREIGN KEY (plan_id) REFERENCES dental_clinic.insurance_plan(plan_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS dental_clinic.appointment (
    appointment_id SERIAL PRIMARY KEY,
    patient_id INT NOT NULL,
    dentist_id INT NOT NULL,
    appointment_date DATE NOT NULL CHECK (appointment_date > DATE '2026-01-01'),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL CHECK (end_time > start_time),
    status VARCHAR(20) NOT NULL DEFAULT 'Scheduled' CHECK (status IN ('Scheduled', 'Completed', 'Cancelled', 'No-Show')),
    notes TEXT,
    CONSTRAINT fk_appointment_patient FOREIGN KEY (patient_id) REFERENCES dental_clinic.patient(patient_id) ON DELETE CASCADE,
    CONSTRAINT fk_appointment_dentist FOREIGN KEY (dentist_id) REFERENCES dental_clinic.dentist(dentist_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS dental_clinic.procedure_type (
    procedure_type_id SERIAL PRIMARY KEY,
    procedure_name VARCHAR(100) NOT NULL UNIQUE,
    base_price NUMERIC(10,2) NOT NULL CHECK (base_price >= 0),
    estimated_duration INT NOT NULL CHECK (estimated_duration >= 0),
    description TEXT
);

CREATE TABLE IF NOT EXISTS dental_clinic.treatment_history (
    treatment_id SERIAL PRIMARY KEY,
    appointment_id INT NOT NULL,
    procedure_type_id INT NOT NULL,
    tooth_number INT CHECK (tooth_number >= 1 AND tooth_number <= 32),
    actual_price NUMERIC(10,2) NOT NULL CHECK (actual_price >= 0),
    notes TEXT,
    CONSTRAINT fk_treatment_appointment FOREIGN KEY (appointment_id) REFERENCES dental_clinic.appointment(appointment_id) ON DELETE CASCADE,
    CONSTRAINT fk_treatment_procedure FOREIGN KEY (procedure_type_id) REFERENCES dental_clinic.procedure_type(procedure_type_id) ON DELETE RESTRICT,
    CONSTRAINT uq_treatment_unique UNIQUE (appointment_id, procedure_type_id, tooth_number)
);

CREATE TABLE IF NOT EXISTS dental_clinic.invoice (
    invoice_id SERIAL PRIMARY KEY,
    patient_id INT NOT NULL,
    appointment_id INT NOT NULL UNIQUE,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL CHECK (due_date >= issue_date),
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    insurance_covered NUMERIC(10,2) NOT NULL CHECK (insurance_covered >= 0 AND insurance_covered <= total_amount),
    patient_owes NUMERIC(10,2) GENERATED ALWAYS AS (total_amount - insurance_covered) STORED,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Paid', 'Overdue', 'Cancelled')),
    CONSTRAINT fk_invoice_patient FOREIGN KEY (patient_id) REFERENCES dental_clinic.patient(patient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_invoice_appointment FOREIGN KEY (appointment_id) REFERENCES dental_clinic.appointment(appointment_id) ON DELETE RESTRICT
);

-- ===========================================================================================
-- PART 3: ALTER TABLE OPERATIONS
-- ===========================================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='dental_clinic' AND table_name='patient' AND column_name='emergency_contact') THEN
        ALTER TABLE dental_clinic.patient ADD COLUMN emergency_contact VARCHAR(100);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='dental_clinic' AND table_name='dentist' AND column_name='phone'
               AND character_maximum_length=15) THEN
        ALTER TABLE dental_clinic.dentist ALTER COLUMN phone TYPE VARCHAR(20);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='uq_no_double_booking') THEN
        ALTER TABLE dental_clinic.appointment ADD CONSTRAINT uq_no_double_booking UNIQUE (patient_id, appointment_date, start_time);
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='dental_clinic' AND table_name='appointment' AND column_name='notes') THEN
        ALTER TABLE dental_clinic.appointment DROP COLUMN notes;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='dental_clinic' AND table_name='procedure_type' AND column_name='estimated_duration') THEN
        ALTER TABLE dental_clinic.procedure_type RENAME COLUMN estimated_duration TO duration_minutes;
    END IF;
END $$;

-- ===========================================================================================
-- PART 4: INSERT DATA
-- ===========================================================================================

INSERT INTO dental_clinic.insurance_plan (plan_name, provider_name, coverage_percentage, annual_maximum)
SELECT * FROM (VALUES
    ('Basic Dental Coverage', 'HealthCare Kazakhstan', 50.00, 150000.00),
    ('Premium Family Plan', 'MedLife Insurance', 80.00, 500000.00),
    ('Student Dental Plan', 'UniHealth', 60.00, 200000.00),
    ('Senior Care Plus', 'ElderCare Insurance', 75.00, 350000.00),
    ('Corporate Wellness Plan', 'BizHealth', 70.00, 400000.00)
) AS v(plan_name, provider_name, coverage_percentage, annual_maximum)
WHERE NOT EXISTS (SELECT 1 FROM dental_clinic.insurance_plan ip WHERE ip.plan_name = v.plan_name);

INSERT INTO dental_clinic.dentist (first_name, last_name, specialization, phone, email, license_number, hire_date)
SELECT * FROM (VALUES
    ('Asel', 'Nursultanova', 'General', '+77011234567', 'asel.nursultanova@dentalclinic.kz', 'DL-2023-001234', '2023-03-15'::DATE),
    ('Marat', 'Bekzhanov', 'Orthodontist', '+77012345678', 'marat.bekzhanov@dentalclinic.kz', 'DL-2021-005678', '2021-08-20'::DATE),
    ('Dana', 'Tulegenova', 'Endodontist', '+77013456789', 'dana.tulegenova@dentalclinic.kz', 'DL-2022-009012', '2022-05-10'::DATE),
    ('Erlan', 'Serikbayev', 'Periodontist', '+77014567890', 'erlan.serikbayev@dentalclinic.kz', 'DL-2024-002345', '2024-01-05'::DATE),
    ('Zhanna', 'Omarova', 'Oral Surgeon', '+77015678901', 'zhanna.omarova@dentalclinic.kz', 'DL-2020-007890', '2020-11-12'::DATE),
    ('Nurlan', 'Azamatov', 'General', '+77016789012', 'nurlan.azamatov@dentalclinic.kz', 'DL-2023-008901', '2023-07-22'::DATE)
) AS v(first_name, last_name, specialization, phone, email, license_number, hire_date)
WHERE NOT EXISTS (SELECT 1 FROM dental_clinic.dentist d WHERE d.email = v.email);

INSERT INTO dental_clinic.patient (first_name, last_name, date_of_birth, phone, email, address, plan_id, registration_date)
SELECT * FROM (VALUES
    ('Aigerim', 'Mukhanova', '1985-04-12'::DATE, '+77017890123', 'aigerim.mukhanova@mail.kz', 'Almaty, Dostyk Ave 123, apt 45',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Premium Family Plan'), '2026-02-10'::DATE),
    ('Bauyrzhan', 'Kairatov', '1990-09-25'::DATE, '+77018901234', 'bauyrzhan.k@gmail.com', 'Astana, Kabanbai Batyr 67',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Corporate Wellness Plan'), '2026-03-05'::DATE),
    ('Saule', 'Toktaganova', '1978-11-03'::DATE, '+77019012345', 'saule.toktaganova@yahoo.com', 'Shymkent, Tauke Khan Ave 234',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Basic Dental Coverage'), '2026-01-20'::DATE),
    ('Zholgali', 'Dias', '1995-06-18'::DATE, '+77010123456', 'zholgali.dias@outlook.com', 'Almaty, Al-Farabi 15',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Student Dental Plan'), '2026-04-12'::DATE),
    ('Madina', 'Sultanbekova', '1965-02-28'::DATE, '+77011234568', 'madina.sultanbekova@inbox.ru', 'Karaganda, Bukhar Zhyrau 89',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Senior Care Plus'), '2026-02-28'::DATE),
    ('Arman', 'Zhanabayev', '1988-07-14'::DATE, '+77012345679', 'arman.zhanabayev@gmail.com', 'Pavlodar, Satpayev St 56',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Premium Family Plan'), '2026-03-18'::DATE),
    ('Gulshat', 'Nurgaliyeva', '1992-12-05'::DATE, '+77013456780', 'gulshat.n@mail.kz', 'Aktobe, Abylai Khan 78',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Corporate Wellness Plan'), '2026-01-15'::DATE),
    ('Timur', 'Abdulov', '2001-03-22'::DATE, '+77014567891', 'timur.abdulov@student.kz', 'Almaty, Nazarbayev University campus',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Student Dental Plan'), '2026-05-02'::DATE),
    ('Roza', 'Karimova', '1982-08-30'::DATE, '+77015678902', 'roza.karimova@corp.kz', 'Astana, Mangilik El 12',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Basic Dental Coverage'), '2026-02-22'::DATE),
    ('Alibek', 'Serikbay', '1975-01-17'::DATE, '+77016789013', NULL, 'Taraz, Zhambyl St 34', NULL, '2026-04-08'::DATE),
    ('Kamila', 'Zhaksylykova', '1998-10-10'::DATE, '+77017890124', 'kamila.zh@mail.kz', 'Almaty, Rozybakiev 99',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Premium Family Plan'), '2026-03-30'::DATE),
    ('Yerbol', 'Moldakhanov', '1987-05-19'::DATE, '+77018901235', 'yerbol.moldakhanov@yandex.kz', 'Kostanay, Baitursynov 23',
        (SELECT plan_id FROM dental_clinic.insurance_plan WHERE plan_name='Corporate Wellness Plan'), '2026-01-28'::DATE)
) AS v(first_name, last_name, date_of_birth, phone, email, address, plan_id, registration_date)
WHERE NOT EXISTS (SELECT 1 FROM dental_clinic.patient p WHERE p.email=v.email OR (v.email IS NULL AND p.phone=v.phone));

INSERT INTO dental_clinic.procedure_type (procedure_name, base_price, duration_minutes, description)
SELECT * FROM (VALUES
    ('Routine Cleaning', 15000.00, 30, 'Professional teeth cleaning and polishing'),
    ('Dental Filling', 25000.00, 45, 'Cavity filling with composite resin'),
    ('Root Canal Treatment', 85000.00, 90, 'Endodontic treatment to save infected tooth'),
    ('Tooth Extraction', 35000.00, 30, 'Surgical removal of tooth'),
    ('Crown Installation', 120000.00, 60, 'Placement of dental crown on damaged tooth'),
    ('Teeth Whitening', 55000.00, 60, 'Professional bleaching treatment'),
    ('Orthodontic Consultation', 8000.00, 30, 'Initial assessment for braces or aligners'),
    ('Dental Implant', 250000.00, 120, 'Surgical placement of titanium implant'),
    ('Gum Disease Treatment', 45000.00, 60, 'Periodontal therapy for gum health'),
    ('Emergency Dental Exam', 12000.00, 20, 'Urgent examination for dental pain or trauma')
) AS v(procedure_name, base_price, duration_minutes, description)
WHERE NOT EXISTS (SELECT 1 FROM dental_clinic.procedure_type pt WHERE pt.procedure_name=v.procedure_name);

INSERT INTO dental_clinic.appointment (patient_id, dentist_id, appointment_date, start_time, end_time, status)
SELECT
    COALESCE((SELECT patient_id FROM dental_clinic.patient WHERE email=v.patient_email), (SELECT patient_id FROM dental_clinic.patient WHERE phone='+77016789013')),
    (SELECT dentist_id FROM dental_clinic.dentist WHERE email=v.dentist_email),
    v.appointment_date, v.start_time, v.end_time, v.status
FROM (VALUES
    ('aigerim.mukhanova@mail.kz', 'asel.nursultanova@dentalclinic.kz', '2026-06-10'::DATE, '09:00'::TIME, '09:30'::TIME, 'Scheduled'),
    ('bauyrzhan.k@gmail.com', 'marat.bekzhanov@dentalclinic.kz', '2026-06-12'::DATE, '10:00'::TIME, '10:30'::TIME, 'Scheduled'),
    ('saule.toktaganova@yahoo.com', 'dana.tulegenova@dentalclinic.kz', '2026-06-08'::DATE, '14:00'::TIME, '15:30'::TIME, 'Completed'),
    ('zholgali.dias@outlook.com', 'asel.nursultanova@dentalclinic.kz', '2026-06-05'::DATE, '11:00'::TIME, '11:45'::TIME, 'Completed'),
    ('madina.sultanbekova@inbox.ru', 'erlan.serikbayev@dentalclinic.kz', '2026-06-15'::DATE, '15:00'::TIME, '16:00'::TIME, 'Scheduled'),
    ('arman.zhanabayev@gmail.com', 'zhanna.omarova@dentalclinic.kz', '2026-06-07'::DATE, '13:00'::TIME, '14:00'::TIME, 'Completed'),
    ('gulshat.n@mail.kz', 'nurlan.azamatov@dentalclinic.kz', '2026-06-09'::DATE, '10:00'::TIME, '10:30'::TIME, 'Completed'),
    ('timur.abdulov@student.kz', 'asel.nursultanova@dentalclinic.kz', '2026-06-11'::DATE, '16:00'::TIME, '16:45'::TIME, 'Scheduled'),
    ('roza.karimova@corp.kz', 'marat.bekzhanov@dentalclinic.kz', '2026-06-14'::DATE, '09:30'::TIME, '10:00'::TIME, 'Scheduled'),
    (NULL, 'dana.tulegenova@dentalclinic.kz', '2026-06-06'::DATE, '11:00'::TIME, '12:30'::TIME, 'Completed'),
    ('kamila.zh@mail.kz', 'asel.nursultanova@dentalclinic.kz', '2026-06-13'::DATE, '14:30'::TIME, '15:00'::TIME, 'Scheduled'),
    ('yerbol.moldakhanov@yandex.kz', 'erlan.serikbayev@dentalclinic.kz', '2026-06-16'::DATE, '10:30'::TIME, '11:30'::TIME, 'Scheduled')
) AS v(patient_email, dentist_email, appointment_date, start_time, end_time, status)
WHERE NOT EXISTS (
    SELECT 1 FROM dental_clinic.appointment a
    WHERE a.patient_id=COALESCE((SELECT patient_id FROM dental_clinic.patient WHERE email=v.patient_email), (SELECT patient_id FROM dental_clinic.patient WHERE phone='+77016789013'))
    AND a.appointment_date=v.appointment_date AND a.start_time=v.start_time
);

INSERT INTO dental_clinic.treatment_history (appointment_id, procedure_type_id, tooth_number, actual_price, notes)
SELECT a.appointment_id, (SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Root Canal Treatment'),
       14, 85000.00, 'Root canal on upper right first molar'
FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id
WHERE p.email='saule.toktaganova@yahoo.com' AND a.appointment_date='2026-06-08'::DATE
AND NOT EXISTS (SELECT 1 FROM dental_clinic.treatment_history th WHERE th.appointment_id=a.appointment_id
                AND th.procedure_type_id=(SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Root Canal Treatment'));

INSERT INTO dental_clinic.treatment_history (appointment_id, procedure_type_id, tooth_number, actual_price, notes)
SELECT v.appointment_id, v.procedure_type_id, v.tooth_number, v.actual_price, v.notes
FROM (VALUES
    ((SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='zholgali.dias@outlook.com' AND a.appointment_date='2026-06-05'::DATE),
     (SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Dental Filling'), 18, 25000.00, 'Composite filling on lower left second molar'),
    ((SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='zholgali.dias@outlook.com' AND a.appointment_date='2026-06-05'::DATE),
     (SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Routine Cleaning'), NULL, 15000.00, 'Full mouth cleaning'),
    ((SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='arman.zhanabayev@gmail.com' AND a.appointment_date='2026-06-07'::DATE),
     (SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Tooth Extraction'), 32, 35000.00, 'Wisdom tooth extraction'),
    ((SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='gulshat.n@mail.kz' AND a.appointment_date='2026-06-09'::DATE),
     (SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Routine Cleaning'), NULL, 15000.00, 'Regular checkup and cleaning'),
    ((SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.phone='+77016789013' AND a.appointment_date='2026-06-06'::DATE),
     (SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Root Canal Treatment'), 21, 85000.00, 'Root canal on lower left first premolar'),
    ((SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.phone='+77016789013' AND a.appointment_date='2026-06-06'::DATE),
     (SELECT procedure_type_id FROM dental_clinic.procedure_type WHERE procedure_name='Crown Installation'), 21, 110000.00, 'Crown placed after root canal (10% discount applied)')
) AS v(appointment_id, procedure_type_id, tooth_number, actual_price, notes)
WHERE NOT EXISTS (SELECT 1 FROM dental_clinic.treatment_history th WHERE th.appointment_id=v.appointment_id
                  AND th.procedure_type_id=v.procedure_type_id
                  AND (th.tooth_number=v.tooth_number OR (th.tooth_number IS NULL AND v.tooth_number IS NULL)));

INSERT INTO dental_clinic.invoice (patient_id, appointment_id, issue_date, due_date, total_amount, insurance_covered, status)
SELECT v.patient_id, v.appointment_id, v.issue_date, v.due_date, v.total_amount, v.insurance_covered, v.status
FROM (VALUES
    ((SELECT patient_id FROM dental_clinic.patient WHERE email='saule.toktaganova@yahoo.com'),
     (SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='saule.toktaganova@yahoo.com' AND a.appointment_date='2026-06-08'::DATE),
     '2026-06-08'::DATE, '2026-07-08'::DATE, 85000.00,
     (85000.00 * (SELECT coverage_percentage FROM dental_clinic.insurance_plan WHERE plan_name='Basic Dental Coverage')/100), 'Pending'),
    ((SELECT patient_id FROM dental_clinic.patient WHERE email='zholgali.dias@outlook.com'),
     (SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='zholgali.dias@outlook.com' AND a.appointment_date='2026-06-05'::DATE),
     '2026-06-05'::DATE, '2026-07-05'::DATE, 40000.00,
     (40000.00 * (SELECT coverage_percentage FROM dental_clinic.insurance_plan WHERE plan_name='Student Dental Plan')/100), 'Paid'),
    ((SELECT patient_id FROM dental_clinic.patient WHERE email='arman.zhanabayev@gmail.com'),
     (SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='arman.zhanabayev@gmail.com' AND a.appointment_date='2026-06-07'::DATE),
     '2026-06-07'::DATE, '2026-07-07'::DATE, 35000.00,
     (35000.00 * (SELECT coverage_percentage FROM dental_clinic.insurance_plan WHERE plan_name='Premium Family Plan')/100), 'Paid'),
    ((SELECT patient_id FROM dental_clinic.patient WHERE email='gulshat.n@mail.kz'),
     (SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.email='gulshat.n@mail.kz' AND a.appointment_date='2026-06-09'::DATE),
     '2026-06-09'::DATE, '2026-07-09'::DATE, 15000.00,
     (15000.00 * (SELECT coverage_percentage FROM dental_clinic.insurance_plan WHERE plan_name='Corporate Wellness Plan')/100), 'Pending'),
    ((SELECT patient_id FROM dental_clinic.patient WHERE phone='+77016789013'),
     (SELECT a.appointment_id FROM dental_clinic.appointment a JOIN dental_clinic.patient p ON a.patient_id=p.patient_id WHERE p.phone='+77016789013' AND a.appointment_date='2026-06-06'::DATE),
     '2026-06-06'::DATE, '2026-07-06'::DATE, 195000.00, 0.00, 'Pending')
) AS v(patient_id, appointment_id, issue_date, due_date, total_amount, insurance_covered, status)
WHERE NOT EXISTS (SELECT 1 FROM dental_clinic.invoice i WHERE i.appointment_id=v.appointment_id);

-- ===========================================================================================
-- PART 5: UPDATE STATEMENTS
-- ===========================================================================================

UPDATE dental_clinic.procedure_type SET base_price = base_price * 0.85
WHERE procedure_name='Teeth Whitening' AND base_price > 46750.00;

UPDATE dental_clinic.appointment SET status = 'No-Show'
WHERE status='Scheduled' AND appointment_date < CURRENT_DATE;

-- ===========================================================================================
-- PART 6: DELETE STATEMENT
-- ===========================================================================================

BEGIN;
DELETE FROM dental_clinic.appointment WHERE status='Cancelled' AND appointment_date < CURRENT_DATE - INTERVAL '90 days'
RETURNING appointment_id, patient_id, appointment_date, status;
ROLLBACK;

-- ===========================================================================================
-- PART 7: GRANT AND REVOKE (DCL)
-- ===========================================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname='dental_readonly') THEN
        CREATE ROLE dental_readonly;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname='dental_writer') THEN
        CREATE ROLE dental_writer;
    END IF;
END $$;

GRANT USAGE ON SCHEMA dental_clinic TO dental_readonly, dental_writer;
GRANT SELECT ON ALL TABLES IN SCHEMA dental_clinic TO dental_readonly;
GRANT SELECT, INSERT ON dental_clinic.appointment, dental_clinic.treatment_history, dental_clinic.invoice TO dental_writer;

DO $$
BEGIN
    EXECUTE 'REVOKE UPDATE ON dental_clinic.invoice FROM dental_writer';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ===========================================================================================
-- END OF SCRIPT
-- ===========================================================================================
