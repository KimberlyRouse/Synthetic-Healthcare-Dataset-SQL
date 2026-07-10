-- Healthcare Dataset Cleaning Project
-- Dataset: Synthetic Healthcare Dataset (Kaggle)
-- Source: https://www.kaggle.com/datasets/prasad22/healthcare-dataset
-- Tools: MySQL 9.7, TablePlus (for CSV import on Mac)
--
-- This project cleans a synthetic healthcare dataset containing 55,500 
-- patient admission records. Primary cleaning tasks include name field 
-- parsing into components, date type conversion, age range categorization,
-- and data quality investigation of Hospital and Doctor columns.
-- Original data preserved in healthcare_dataset; all cleaning performed 
-- on health_staging.
-- ============================================
-- SECTION 1: SETUP & STAGING TABLE CREATION
-- ============================================

CREATE SCHEMA `healthcare` ;

-- Inspecting the data set
DESCRIBE healthcare.healthcare_dataset;

SELECT *
FROM healthcare.healthcare_dataset
LIMIT 10;

SELECT COUNT(*)
FROM healthcare.healthcare_dataset;
-- 55,500 rows in dataset

CREATE TABLE `health_staging` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `Name` text,
  `Age` int DEFAULT NULL,
  `Gender` text,
  `Blood Type` text,
  `Medical Condition` text,
  `Date of Admission` text,
  `Doctor` text,
  `Hospital` text,
  `Insurance Provider` text,
  `Billing Amount` float DEFAULT NULL,
  `Room Number` int DEFAULT NULL,
  `Admission Type` text,
  `Discharge Date` text,
  `Medication` text,
  `Test Results` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO healthcare.health_staging
SELECT NULL, healthcare.healthcare_dataset.*
FROM healthcare.healthcare_dataset;

SELECT *
FROM healthcare.health_staging
LIMIT 10;

-- ============================================
-- SECTION 2: DUPLICATE DETECTION & REMOVAL
-- ============================================

-- Check for duplicate records
WITH duplicate_check AS (
    SELECT Name, Age, Gender, `Blood Type`, 
           `Medical Condition`, `Date of Admission`, 
           Doctor, Hospital, `Insurance Provider`,
           `Billing Amount`, `Room Number`, `Admission Type`,
           `Discharge Date`, Medication, `Test Results`,
           COUNT(*) AS row_count
    FROM healthcare.health_staging
    GROUP BY Name, Age, Gender, `Blood Type`,
             `Medical Condition`, `Date of Admission`,
             Doctor, Hospital, `Insurance Provider`,
             `Billing Amount`, `Room Number`, `Admission Type`,
             `Discharge Date`, Medication, `Test Results`
    HAVING row_count > 1
)
SELECT COUNT(*) AS duplicate_groups
FROM duplicate_check;

-- There are 534 duplicates. Since this is synthetic Faker data duplicates are 
-- 	expected based on the result.

-- See the actual duplicate records
WITH duplicate_check AS (
    SELECT Name, Age, Gender, `Blood Type`, 
           `Medical Condition`, `Date of Admission`, 
           Doctor, Hospital, `Insurance Provider`,
           `Billing Amount`, `Room Number`, `Admission Type`,
           `Discharge Date`, Medication, `Test Results`,
           COUNT(*) AS row_count
    FROM healthcare.health_staging
    GROUP BY Name, Age, Gender, `Blood Type`,
             `Medical Condition`, `Date of Admission`,
             Doctor, Hospital, `Insurance Provider`,
             `Billing Amount`, `Room Number`, `Admission Type`,
             `Discharge Date`, Medication, `Test Results`
    HAVING row_count > 1
)
SELECT hs.*
FROM healthcare.health_staging AS hs
JOIN duplicate_check AS dc
    ON hs.Name = dc.Name
    AND hs.Age = dc.Age
    AND hs.`Medical Condition` = dc.`Medical Condition`
    AND hs.`Date of Admission` = dc.`Date of Admission`
    AND hs.`Billing Amount` = dc.`Billing Amount`
LIMIT 20;

-- verify before deletion using row_num to identify duplicates 
WITH ranked AS (
    SELECT id,
           ROW_NUMBER() OVER(
               PARTITION BY Name, Age, Gender, `Blood Type`,
                            `Medical Condition`, `Date of Admission`,
                            Doctor, Hospital, `Insurance Provider`,
                            `Billing Amount`, `Room Number`, `Admission Type`,
                            `Discharge Date`, Medication, `Test Results`
               ORDER BY id
           ) AS row_num
    FROM health_staging
)
SELECT COUNT(*) AS rows_to_delete
FROM ranked
WHERE row_num > 1;
-- 534 rows

DELETE FROM health_staging
WHERE id IN (
    SELECT id FROM (
        WITH ranked AS (
            SELECT id,
                   ROW_NUMBER() OVER(
                       PARTITION BY Name, Age, Gender, `Blood Type`,
                                    `Medical Condition`, `Date of Admission`,
                                    Doctor, Hospital, `Insurance Provider`,
                                    `Billing Amount`, `Room Number`, `Admission Type`,
                                    `Discharge Date`, Medication, `Test Results`
                       ORDER BY id
                   ) AS row_num
            FROM health_staging
        )
        SELECT id FROM ranked WHERE row_num > 1
    ) AS to_delete
);

-- Verify deletion
SELECT COUNT(*) FROM health_staging;
-- count in now 54,966 which calculates, 55,500 - 534 = 54,966

-- ============================================
-- SECTION 3: NAME FIELD PARSING (PATIENT)
-- ============================================

-- Start with the Name column first now that duplicates are gone

-- The first 10 entries in the data set didn't have Prefix or Suffix in the data
-- 		so verifing if there are a Prefix and Suffix in columns.
SELECT Name, LENGTH(Name)
FROM healthcare.health_staging
WHERE LENGTH(Name) > 20
LIMIT 20;

-- Check last word of each name for suffixes
SELECT DISTINCT 
    SUBSTRING_INDEX(Name, ' ', -1) AS last_word,
    COUNT(*) AS count
FROM healthcare.health_staging
GROUP BY last_word
ORDER BY count DESC;

-- Check first word for prefixes
SELECT DISTINCT
    SUBSTRING_INDEX(Name, ' ', 1) AS first_word,
    COUNT(*) AS count,
    LENGTH(SUBSTRING_INDEX(Name, ' ', 1)) AS length_first
FROM healthcare.health_staging
GROUP BY first_word, length_first
ORDER BY length_first;

-- get a word count for the Name field
SELECT 
    LENGTH(Name) - LENGTH(REPLACE(Name, ' ', '')) + 1 AS word_count,
    COUNT(*) AS total_rows
FROM healthcare.health_staging
GROUP BY word_count
ORDER BY word_count;

-- There are 52,870 2 word names, 1,824 3 word names and 272 4 word names.
-- 		This comes out to 54,966

-- How many 3-word names start with a known prefix
SELECT COUNT(*) AS has_prefix
FROM healthcare.health_staging
WHERE LENGTH(Name) - LENGTH(REPLACE(Name, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Name, ' ', 1)) IN ('mr.', 'mrs.', 'ms.', 'miss', 'dr.');

-- How many 3-word names end with a known suffix
SELECT COUNT(*) AS has_suffix
FROM healthcare.health_staging
WHERE LENGTH(Name) - LENGTH(REPLACE(Name, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Name, ' ', -1)) IN ('md', 'dvm', 'dds', 'phd', 'jr.', 'ii', 'iii', 'iv', 'v');

-- Prefix 835, Suffix 989. Total 1,824 correct

-- Add columns to staging table
ALTER TABLE healthcare.health_staging
ADD COLUMN prefix VARCHAR(10),
ADD COLUMN first_name VARCHAR(50),
ADD COLUMN last_name VARCHAR(50),
ADD COLUMN suffix VARCHAR(10);

-- Pattern 1: first last (52,870 rows)
UPDATE healthcare.health_staging
SET first_name = SUBSTRING_INDEX(Name, ' ', 1),
    last_name = SUBSTRING_INDEX(Name, ' ', -1)
WHERE LENGTH(Name) - LENGTH(REPLACE(Name, ' ', '')) + 1 = 2;

-- Pattern 2: prefix first last (835 rows)
UPDATE healthcare.health_staging
SET prefix = SUBSTRING_INDEX(Name, ' ', 1),
    first_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Name, ' ', 2), ' ', -1),
    last_name = SUBSTRING_INDEX(Name, ' ', -1)
WHERE LENGTH(Name) - LENGTH(REPLACE(Name, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Name, ' ', 1)) IN ('mr.', 'mrs.', 'ms.', 'miss', 'dr.');

-- Pattern 3: first last suffix (989 rows)
UPDATE healthcare.health_staging
SET first_name = SUBSTRING_INDEX(Name, ' ', 1),
    last_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Name, ' ', 2), ' ', -1),
    suffix = SUBSTRING_INDEX(Name, ' ', -1)
WHERE LENGTH(Name) - LENGTH(REPLACE(Name, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Name, ' ', -1)) IN ('md', 'dvm', 'dds', 'phd', 'jr.', 'ii', 'iii', 'iv', 'v');

-- Pattern 4: prefix first last suffix (272 rows)
UPDATE healthcare.health_staging
SET prefix = SUBSTRING_INDEX(Name, ' ', 1),
    first_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Name, ' ', 2), ' ', -1),
    last_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Name, ' ', 3), ' ', -1),
    suffix = SUBSTRING_INDEX(Name, ' ', -1)
WHERE LENGTH(Name) - LENGTH(REPLACE(Name, ' ', '')) + 1 = 4;

-- Verify the parsing occurred correctly.
SELECT prefix, first_name, last_name, suffix
FROM healthcare.health_staging;

-- ============================================
-- SECTION 4: CASE STANDARDIZATION & CATEGORICAL QA
-- ============================================

-- Apply proper case to first_name
UPDATE healthcare.health_staging
SET first_name = CONCAT(UPPER(LEFT(first_name, 1)), LOWER(SUBSTRING(first_name, 2)))
WHERE first_name IS NOT NULL;

-- Apply proper case to last_name
UPDATE healthcare.health_staging
SET last_name = CONCAT(UPPER(LEFT(last_name, 1)), LOWER(SUBSTRING(last_name, 2)))
WHERE last_name IS NOT NULL;

-- Standardize prefix to proper format
UPDATE healthcare.health_staging
SET prefix = CASE LOWER(prefix)
    WHEN 'mr.' THEN 'Mr.'
    WHEN 'mrs.' THEN 'Mrs.'
    WHEN 'ms.' THEN 'Ms.'
    WHEN 'miss' THEN 'Miss'
    WHEN 'dr.' THEN 'Dr.'
    ELSE prefix
END
WHERE prefix IS NOT NULL;

-- Standardize suffix to proper format
UPDATE healthcare.health_staging
SET suffix = CASE LOWER(suffix)
    WHEN 'md' THEN 'MD'
    WHEN 'dvm' THEN 'DVM'
    WHEN 'dds' THEN 'DDS'
    WHEN 'phd' THEN 'PhD'
    WHEN 'jr.' THEN 'Jr.'
    WHEN 'ii' THEN 'II'
    WHEN 'iii' THEN 'III'
    WHEN 'iv' THEN 'IV'
    WHEN 'v' THEN 'V'
    ELSE suffix
END
WHERE suffix IS NOT NULL;

-- Verify the casing occurred correctly.
SELECT prefix, first_name, last_name, suffix
FROM healthcare.health_staging;

-- Verify all rows have first_name populated
SELECT COUNT(*) AS has_first_name
FROM healthcare.health_staging
WHERE first_name IS NOT NULL;
-- This is 54,966 which is correct

-- Verify prefix count matches expectation
SELECT COUNT(*) AS has_prefix
FROM healthcare.health_staging
WHERE prefix IS NOT NULL;
-- This is 1,107 (835 + 272)

-- Verify suffix count matches expectation
SELECT COUNT(*) AS has_suffix
FROM healthcare.health_staging
WHERE suffix IS NOT NULL;
-- This is 1,261 (989 + 272)

-- Verify rows with BOTH prefix and suffix
SELECT COUNT(*) AS has_both
FROM healthcare.health_staging
WHERE prefix IS NOT NULL AND suffix IS NOT NULL;
-- This is 272

-- Check for case issues in other text columns
SELECT DISTINCT Gender 
FROM healthcare.health_staging 
ORDER BY Gender;
-- Female, Male

SELECT DISTINCT `Blood Type` 
FROM healthcare.health_staging 
ORDER BY `Blood Type`;
-- A-, A+, AB-, AB+, B-, B+, O-, O+

SELECT DISTINCT `Medical Condition` 
FROM healthcare.health_staging 
ORDER BY `Medical Condition`;
-- Arthritis, Asthma, Cancer, Diabetes, Hypertension, Obesity

SELECT DISTINCT `Admission Type` 
FROM healthcare.health_staging 
ORDER BY `Admission Type`;
-- Elective, Emergency, Urgent

SELECT DISTINCT Medication 
FROM healthcare.health_staging 
ORDER BY Medication;
-- Aspirin, Ibuprofen, Lipitor, Paracetamol, Penicillin

SELECT DISTINCT `Test Results` 
FROM healthcare.health_staging 
ORDER BY `Test Results`;
-- Abnormal, Inconclusive, Normal

SELECT DISTINCT `Insurance Provider` 
FROM healthcare.health_staging 
ORDER BY `Insurance Provider`;
-- Aetna, Blue Cross, Cigna, Medicare, UnitedHealthcare

-- ============================================
-- SECTION 5: DATE CONVERSION & NULL CHECKS
-- ============================================

-- Check if dates are already in a clean format
SELECT 
    COUNT(*) AS total_rows,
    COUNT(`Date of Admission`) AS has_admission_date,
    COUNT(`Discharge Date`) AS has_discharge_date
FROM health_staging;

-- Check date format
SELECT `Date of Admission`, `Discharge Date`
FROM healthcare.health_staging
LIMIT 10;

SELECT `Date of Admission`, STR_TO_DATE(`Date of Admission`, '%Y-%m-%d'),
		`Discharge Date`, STR_TO_DATE(`Discharge Date`, '%Y-%m-%d')
FROM healthcare.health_staging
LIMIT 10;

ALTER TABLE health_staging
MODIFY COLUMN `Date of Admission` DATE;

ALTER TABLE health_staging
MODIFY COLUMN `Discharge Date` DATE;

SELECT 
    SUM(CASE WHEN `Name` IS NULL THEN 1 ELSE 0 END) AS null_name,
    SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN `Medical Condition` IS NULL THEN 1 ELSE 0 END) AS null_condition,
    SUM(CASE WHEN `Date of Admission` IS NULL THEN 1 ELSE 0 END) AS null_admission,
    SUM(CASE WHEN `Discharge Date` IS NULL THEN 1 ELSE 0 END) AS null_discharge,
    SUM(CASE WHEN `Billing Amount` IS NULL THEN 1 ELSE 0 END) AS null_billing,
    SUM(CASE WHEN Doctor IS NULL THEN 1 ELSE 0 END) AS null_doctor,
    SUM(CASE WHEN Hospital IS NULL THEN 1 ELSE 0 END) AS null_hospital,
    SUM(CASE WHEN `Room Number` IS NULL THEN 1 ELSE 0 END) AS null_room,
    SUM(CASE WHEN `Insurance Provider` IS NULL THEN 1 ELSE 0 END) AS null_insurance,
    SUM(CASE WHEN `Admission Type` IS NULL THEN 1 ELSE 0 END) AS null_admission_type,
    SUM(CASE WHEN Medication IS NULL THEN 1 ELSE 0 END) AS null_medication,
    SUM(CASE WHEN `Test Results` IS NULL THEN 1 ELSE 0 END) AS null_results
FROM healthcare.health_staging;
-- All results came back as 0

-- ============================================
-- SECTION 6: AGE RANGE BUCKETING
-- ============================================

-- Add a Age range column so that data will be assist in any analysis to be 
-- 		done on this data by creating bins of Ages
ALTER TABLE healthcare.health_staging
ADD COLUMN age_range VARCHAR(5);

-- Verify that the age range works
SELECT Age, 
		CASE 
        WHEN Age < 20 THEN '13-19'
        WHEN Age < 30 THEN '20-29'
        WHEN Age < 40 THEN '30-39'
        WHEN Age < 50 THEN '40-49'
        WHEN Age < 60 THEN '50-59'
        WHEN Age < 70 THEN '60-69'
        WHEN Age < 80 THEN '70-79'
        WHEN Age < 90 THEN '80-89'
        ELSE 'Not Valid'
        END as Age_Range
FROM healthcare.health_staging;

-- Now insert them into the age range
UPDATE healthcare.health_staging
SET age_range = CASE 
        WHEN Age < 20 THEN '13-19'
        WHEN Age < 30 THEN '20-29'
        WHEN Age < 40 THEN '30-39'
        WHEN Age < 50 THEN '40-49'
        WHEN Age < 60 THEN '50-59'
        WHEN Age < 70 THEN '60-69'
        WHEN Age < 80 THEN '70-79'
        WHEN Age < 90 THEN '80-89'
        ELSE 'Not Valid'
        END 
;

-- Verify that it populated correctly
SELECT age_range, 
		MIN(Age) AS min_age,
        MAX(Age) AS max_age,
        COUNT(*) AS patient_count
FROM healthcare.health_staging
GROUP BY age_range
ORDER BY min_age;

-- ============================================
-- SECTION 7: DOCTOR FIELD PARSING & STANDARDIZATION
-- ============================================

SELECT COUNT(DISTINCT Doctor)
FROM healthcare.health_staging;
-- There are 40,341

SELECT DISTINCT Doctor
FROM health_staging
ORDER BY Doctor
LIMIT 20;

-- Check word count distribution for Doctor
SELECT 
    LENGTH(Doctor) - LENGTH(REPLACE(Doctor, ' ', '')) + 1 AS word_count,
    COUNT(*) AS total_rows
FROM health_staging
GROUP BY word_count
ORDER BY word_count;
-- There are 52,771 with 2 word names, 1901 with 3 word, and 294 with 4

-- Check if Doctor names contain prefixes or suffixes
SELECT COUNT(*) AS doctor_has_prefix
FROM health_staging
WHERE LENGTH(Doctor) - LENGTH(REPLACE(Doctor, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Doctor, ' ', 1)) IN 
			('mr.', 'mrs.', 'ms.', 'miss', 'dr.');
-- There are 818 doctors with these prefixes

SELECT COUNT(*) AS doctor_has_suffix
FROM health_staging
WHERE LENGTH(Doctor) - LENGTH(REPLACE(Doctor, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Doctor, ' ', -1)) IN 
			('md', 'dvm', 'dds', 'phd', 'jr.', 'ii', 'iii', 'iv', 'v');
-- There are 1083 doctors with these suffixes

-- Add columns to staging table
ALTER TABLE healthcare.health_staging
ADD COLUMN dr_prefix VARCHAR(10),
ADD COLUMN dr_first_name VARCHAR(50),
ADD COLUMN dr_last_name VARCHAR(50),
ADD COLUMN dr_suffix VARCHAR(10);

-- Pattern 1: first last (52,771 rows)
UPDATE healthcare.health_staging
SET dr_first_name = SUBSTRING_INDEX(Doctor, ' ', 1),
    dr_last_name = SUBSTRING_INDEX(Doctor, ' ', -1)
WHERE LENGTH(Doctor) - LENGTH(REPLACE(Doctor, ' ', '')) + 1 = 2;

-- Pattern 2: prefix first last (818 rows)
UPDATE healthcare.health_staging
SET dr_prefix = SUBSTRING_INDEX(Doctor, ' ', 1),
    dr_first_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Doctor, ' ', 2), ' ', -1),
    dr_last_name = SUBSTRING_INDEX(Doctor, ' ', -1)
WHERE LENGTH(Doctor) - LENGTH(REPLACE(Doctor, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Doctor, ' ', 1)) IN ('mr.', 'mrs.', 'ms.', 'miss', 'dr.');

-- Pattern 3: first last suffix (1083 rows)
UPDATE healthcare.health_staging
SET dr_first_name = SUBSTRING_INDEX(Doctor, ' ', 1),
    dr_last_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Doctor, ' ', 2), ' ', -1),
    dr_suffix = SUBSTRING_INDEX(Doctor, ' ', -1)
WHERE LENGTH(Doctor) - LENGTH(REPLACE(Doctor, ' ', '')) + 1 = 3
AND LOWER(SUBSTRING_INDEX(Doctor, ' ', -1)) IN ('md', 'dvm', 'dds', 'phd', 'jr.', 'ii', 'iii', 'iv', 'v');

-- Pattern 4: prefix first last suffix (294 rows)
UPDATE healthcare.health_staging
SET dr_prefix = SUBSTRING_INDEX(Doctor, ' ', 1),
    dr_first_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Doctor, ' ', 2), ' ', -1),
    dr_last_name = SUBSTRING_INDEX(SUBSTRING_INDEX(Doctor, ' ', 3), ' ', -1),
    dr_suffix = SUBSTRING_INDEX(Doctor, ' ', -1)
WHERE LENGTH(Doctor) - LENGTH(REPLACE(Doctor, ' ', '')) + 1 = 4;

-- Verify the parsing occurred correctly.
SELECT dr_prefix, dr_first_name, dr_last_name, dr_suffix
FROM healthcare.health_staging;
-- Parsing occurred correctly. 

-- Verify all rows have first_name populated
SELECT COUNT(*) AS has_first_name
FROM healthcare.health_staging
WHERE dr_first_name IS NOT NULL;
-- This is 54,966 which is correct

-- Verify prefix count matches expectation
SELECT COUNT(*) AS has_prefix
FROM healthcare.health_staging
WHERE dr_prefix IS NOT NULL;
-- This is 1,112 (818 + 294)

-- Verify suffix count matches expectation
SELECT COUNT(*) AS has_suffix
FROM healthcare.health_staging
WHERE dr_suffix IS NOT NULL;
-- This is 1,377 (1083 + 294)

-- Verify rows with BOTH prefix and suffix
SELECT COUNT(*) AS has_both
FROM healthcare.health_staging
WHERE dr_prefix IS NOT NULL AND dr_suffix IS NOT NULL;
-- This is 294

-- Standardize dr_prefix
UPDATE healthcare.health_staging
SET dr_prefix = CASE LOWER(dr_prefix)
    WHEN 'mr.' THEN 'Mr.'
    WHEN 'mrs.' THEN 'Mrs.'
    WHEN 'ms.' THEN 'Ms.'
    WHEN 'miss' THEN 'Miss'
    WHEN 'dr.' THEN 'Dr.'
    ELSE dr_prefix
END
WHERE dr_prefix IS NOT NULL;

-- Standardize dr_suffix
UPDATE healthcare.health_staging
SET dr_suffix = CASE LOWER(dr_suffix)
    WHEN 'md' THEN 'MD'
    WHEN 'dvm' THEN 'DVM'
    WHEN 'dds' THEN 'DDS'
    WHEN 'phd' THEN 'PhD'
    WHEN 'jr.' THEN 'Jr.'
    WHEN 'ii' THEN 'II'
    WHEN 'iii' THEN 'III'
    WHEN 'iv' THEN 'IV'
    WHEN 'v' THEN 'V'
    ELSE dr_suffix
END
WHERE dr_suffix IS NOT NULL;

SELECT COUNT(*) AS has_dr_first_name
FROM healthcare.health_staging
WHERE dr_first_name IS NOT NULL;
-- Should be 54,966

SELECT COUNT(*) AS has_dr_prefix
FROM healthcare.health_staging
WHERE dr_prefix IS NOT NULL;
-- Should be 818 + 294 = 1,112

SELECT COUNT(*) AS has_dr_suffix
FROM healthcare.health_staging
WHERE dr_suffix IS NOT NULL;
-- Should be 1,083 + 294 = 1,377

SELECT COUNT(*) AS has_both
FROM healthcare.health_staging
WHERE dr_prefix IS NOT NULL AND dr_suffix IS NOT NULL;
-- Should be 294

-- Doctor names were already in proper case unlike the Name column so no case 
-- 	standardization was required. Prefixes and suffixes were parsed and 
-- 	standardized to consistent format.

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT Doctor) AS distinct_doctors,
       MIN(patient_count) AS min_patients,
       MAX(patient_count) AS max_patients,
       ROUND(AVG(patient_count), 2) AS avg_patients
FROM (
    SELECT Doctor, COUNT(*) AS patient_count
    FROM health_staging
    GROUP BY Doctor
) AS doctor_counts;

-- The total rows is 40,341 with 40,341 distinct doctors (based on raw Doctor 
-- 	field). The minimum patient count is 1 and the maximum patients is 27 and 
-- 	the average number of patients per doctor is 1.38, calculated using the 
-- 	raw Doctor column as the grouping key. This is synthetic data generated 
-- 	by Faker. The data is clean but does not feel realistic. Without knowing 
-- 	the constraints given during the creation it is hard to know where the 
-- 	error lies.
-- Note: the companion EDA project recalculates this using the parsed 
-- 	dr_first_name/dr_last_name columns instead (39,677 distinct pairs), 
-- 	yielding a slightly different figure of 1.39. Both are valid -- the 
-- 	difference reflects the small number of raw Doctor values that collapse 
-- 	to the same first/last name pair after parsing.

-- ============================================
-- SECTION 8: HOSPITAL COLUMN INVESTIGATION
-- ============================================

SELECT COUNT(DISTINCT Hospital)
FROM healthcare.health_staging;
-- There are 39,876

SELECT DISTINCT Hospital
FROM health_staging
ORDER BY Hospital
LIMIT 20;

-- Count hospitals with trailing commas
SELECT COUNT(*) AS trailing_comma_count
FROM health_staging
WHERE Hospital LIKE '%,';
-- There are 4,736 with trailing commas

-- Count hospitals ending with 'and'
SELECT COUNT(*) AS ends_with_and
FROM health_staging
WHERE TRIM(Hospital) LIKE '% and';
-- There are 5,547 rows truncated during CSV import

-- See examples of truncated names
SELECT DISTINCT Hospital
FROM health_staging
WHERE Hospital LIKE '% and'
OR Hospital LIKE '%,'
ORDER BY Hospital
LIMIT 20;

-- The Hospital column has CSV import corruption affecting approximately 18.7% of rows
-- (10,283 out of 54,966). Hospital names containing commas were split incorrectly 
-- during import, leaving trailing commas and unrecoverable truncated names ending 
-- with 'and'. The missing text cannot be inferred from available data.
-- Decision: Hospital column will be flagged as unreliable and excluded from analysis.
-- The original raw table preserves the source data as imported.

SELECT COUNT(*) AS final_row_count 
FROM healthcare.health_staging;
-- There are 54,966 rows

-- ============================================
-- CLEANING SUMMARY
-- ============================================
-- Starting rows: 55,500
-- Final rows: 54,966 (only rows deleted were the duplicates
-- 						 synthetic data had no NULL rows)
--
-- Changes made:
-- 1. Name field parsed into prefix, first_name, last_name, suffix columns
--    - 52,870 two-word names (first last)
--    - 835 names with prefix only
--    - 989 names with suffix only  
--    - 272 names with both prefix and suffix
-- 2. Proper case applied to first_name and last_name
-- 3. Prefix and suffix standardized to consistent format
-- 4. Date of Admission and Discharge Date converted from TEXT to DATE
-- 5. Age range buckets added as age_range column
-- 6. Doctor column parsed into dr_prefix, dr_first_name, dr_last_name, dr_suffix
--    - 52,771 two-word names
--    - 818 names with prefix only
--    - 1,083 names with suffix only
--    - 294 names with both prefix and suffix
--    Note: high cardinality (40,341 distinct doctors, avg 1.38 patients each)
--    limits analytical usefulness but column is now properly standardized
-- 7. Hospital column flagged as unreliable (~18.7% CSV import corruption)
-- 8. Columns verified clean with no changes required:
--    - Gender, Blood Type, Medical Condition, Admission Type,
--    - Medication, Test Results, Insurance Provider, Room Number,
--    - Billing Amount, Age
--     All returned consistent values with no case issues,
-- 			unexpected values, or NULL entries.