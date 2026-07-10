-- Healthcare Dataset Exploratory Data Analysis
-- Dataset: Synthetic Healthcare Dataset (Kaggle)
-- Source: https://www.kaggle.com/datasets/prasad22/healthcare-dataset
-- Tools: MySQL 9.7
--
-- This project explores a synthetic healthcare dataset containing 54,966
-- patient admission records cleaned in the companion cleaning project.
-- Analysis covers patient demographics, clinical patterns, billing,
-- length of stay, and time-based admission trends.
-- Hospital column excluded due to CSV import corruption (~18.7% of rows affected).

-- ============================================
-- DATA SOURCES FOR REAL-WORLD COMPARISONS
-- ============================================
-- Blood type distribution:
--   American Red Cross, Blood Types Explained
--   https://www.redcrossblood.org/donate-blood/blood-types.html
--   (AB- rarity figure of 0.6% from Stanford Blood Center, cited via
--   secondary sources; Red Cross gives O+ at 37% directly)
--
-- Health insurance market share:
--   American Medical Association, Competition in Health Insurance:
--   A Comprehensive Study of US Markets (2024 Edition)
-- 	 https://www.ama-assn.org/system/files/competition-health-insurance-us-markets.pdf
--
-- Hospital admission type patterns (weekday vs weekend):
--   Agency for Healthcare Research and Quality (AHRQ),
--   Healthcare Cost and Utilization Project (HCUP)
--   https://www.ncbi.nlm.nih.gov/books/NBK53602/
--
-- Average length of stay benchmark:
--   CDC/NCHS Data Query System (sources American Hospital Association data)
--   https://www.cdc.gov/nchs/dqs/topics/healthcare-use.html
--   Queried values: 6.3 days (2020), 6.5 days (2021), 6.6 days (2022),
--   6.5 days (2023). Data available only through 2023 at time of query.
--
-- Medical inflation rate reference:
--   CMS National Health Expenditure (NHE) Fact Sheet
--   https://www.cms.gov/data-research/statistics-trends-and-reports/national-health-expenditure-data/nhe-fact-sheet
--   Hospital services rose 6.9% from 2023-2024, outpacing overall CPI (3.0%)
--   Overall NHE growth was 7.2% in 2024, vs ~4.2% average during the 2010s
--   Secondary analysis: Peterson-KFF Health System Tracker
--   https://www.healthsystemtracker.org/chart-collection/u-s-spending-healthcare-changed-time/
-- ============================================

-- ============================================
-- SECTION 1: DATA OVERVIEW & QUALITY CHECKS
-- ============================================

DESCRIBE healthcare.health_staging;

SELECT COUNT(*)
FROM healthcare.health_staging;
-- 54,966 rows

SELECT MIN(`Date of Admission`) AS earliest_admit,
		MAX(`Date of Admission`) AS latest_admit,
        MIN(`Discharge Date`) AS earliest_discharge,
		MAX(`Discharge Date`) AS latest_discharge
FROM healthcare.health_staging;

-- The dataset covers Admissions from May 2019 to May 2024 with discharge from
-- 	May 2019 to June 2024. 

SELECT COUNT(DISTINCT `Name`)
FROM healthcare.health_staging;
-- 40,235

SELECT COUNT(DISTINCT first_name, last_name)
FROM healthcare.health_staging;
-- 39,617 distinct patients this difference from the Name field is most likely 
-- 	from the cleaning of the data and converting the data to proper case.  

-- This is most likely admitting data since the patient can be entered into the 
-- 	file multiple times.

-- Find first_name/last_name pairs that map to more than one distinct raw Name
SELECT first_name, last_name, COUNT(DISTINCT `Name`) AS distinct_name_variants
FROM healthcare.health_staging
GROUP BY first_name, last_name
HAVING COUNT(DISTINCT `Name`) > 1
ORDER BY distinct_name_variants DESC
LIMIT 10;

-- first_name, last_name, distinct_name_variations
-- Anthony	, Johnson	,		3
-- Brian		, Hamilton	,		3
-- Brittany	, Brown		,		3
-- Christoher, Smith		,		3
-- Cynthia	, Smith		,		3
-- Edward	, Smith		,		3
-- Elizabeth , Davis		,		3
-- James		, Williams	,		3
-- Jennifer	, White		,		3
-- Jessica	, Williams  ,		3

-- This confirms that multiple people had different case conversions in the 
-- 	original field.

SELECT COUNT(DISTINCT Doctor)
FROM healthcare.health_staging;
-- 40,341

SELECT COUNT(DISTINCT dr_first_name, dr_last_name)
FROM healthcare.health_staging;
-- 39,677 distinct doctors this difference from Doctor field is most likely from
-- 	the cleaning of the data and converting the data to proper case.

SELECT Doctor, dr_prefix, dr_first_name, dr_last_name, dr_suffix
FROM healthcare.health_staging
LIMIT 10;

-- Find first_name/last_name pairs that map to more than one distinct raw Name
SELECT dr_first_name, dr_last_name, COUNT(DISTINCT Doctor) AS distinct_name_variants
FROM healthcare.health_staging
GROUP BY dr_first_name, dr_last_name
HAVING COUNT(DISTINCT Doctor) > 1
ORDER BY distinct_name_variants DESC
LIMIT 10;

-- dr_first_name	, dr_last_name	, distinct_name_variations
-- Amanda		, White			,		3
-- Amber			, Johnson		,		3
-- Anthony		, Carter		,		3
-- Brian			, Brown			,		3
-- Cindy			, Wright		,		3
-- David			, Cook			,		3
-- David			, Gonzalez		,		3
-- David			, Lee			,		3
-- David			, Martinez		,		3
-- David			, Murray		,		3

-- This confirms that multiple people had different case conversions in the 
-- 	original field.

-- Verify "avg patients per doctor" stat referenced in summary
SELECT ROUND(COUNT(*) / COUNT(DISTINCT dr_first_name, dr_last_name), 2) AS avg_admissions_per_doctor
FROM healthcare.health_staging;

-- 1.39 patients per doctor in this data set, calculated using parsed 
-- 	dr_first_name/dr_last_name (39,677 distinct pairs) rather than the raw 
-- 	Doctor field. The companion cleaning project calculates this as 1.38 
-- 	using the raw Doctor column (40,341 distinct values) as the grouping key 
-- 	-- both are correct, the small difference reflects doctors whose raw 
-- 	name values collapse to the same parsed first/last name pair.

-- ============================================
-- SECTION 2: PATIENT DEMOGRAPHICS
-- ============================================

SELECT age_range, 
		MIN(Age) AS min_age,
        MAX(Age) AS max_age,
        COUNT(*) AS patient_count
FROM healthcare.health_staging
GROUP BY age_range
ORDER BY min_age;
-- 13-19 1,677, 20-29 7,928, 30-39 8,195, 40-49 8,045, 50-59 8,063
-- 		60-69 8,099, 70-79 7,999, 80-89 4,850
-- Age distribution is relatively uniform across the 20-79 range (7,928 to 8,195 patients
-- 	 per decade), with expected drop-offs in the youngest (13-19: 1,677) and oldest 
-- 	 (80-89: 4,850) brackets. This is consistent with synthetic data generation 
-- 	 rather than real-world healthcare utilization patterns where middle-aged and 
-- 	 elderly patients typically dominate admissions.

SELECT Gender, Count(Gender)
FROM (SELECT DISTINCT Gender, first_name, last_name 
		FROM healthcare.health_staging) AS unique_gender
GROUP BY Gender;

-- There are approximately 21,574 male and 21,699 female unique patients.
-- 	 Counts are based on distinct name combinations and may include minor 
-- 	 inaccuracies where different patients share the same name.
-- 	 The gender split is nearly even at 49.6% male and 50.4% female,
-- 	 consistent with synthetic data generation.

SELECT `Blood Type`, Count(`Blood Type`)
FROM (SELECT DISTINCT `Blood Type`, first_name, last_name 
		FROM healthcare.health_staging) AS unique_blood_type
GROUP BY `Blood Type`
ORDER BY `Blood Type`;

-- A- 5,995, A+ 5,969, AB- 5,961, AB+ 6,006, B- 5,990, B+ 6,023, O- 5,913, O+ 5,952

-- The synthetic data assigns blood types with near-equal distribution (~12.5% each).
-- 	This contrasts sharply with real US population distributions where O+ is the 
-- 	most common at 37% and AB- is the rarest at just 0.6% (American Red Cross;
-- 	AB- figure per Stanford Blood Center). Any analysis using blood type from this 
-- 	dataset should not be used to draw clinical conclusions.

-- Data quality check: confirm no NULLs in name fields that could 
-- silently affect COUNT(DISTINCT first_name, last_name) throughout this script
SELECT 
    SUM(CASE WHEN first_name IS NULL THEN 1 ELSE 0 END) AS null_first,
    SUM(CASE WHEN last_name IS NULL THEN 1 ELSE 0 END) AS null_last,
    SUM(CASE WHEN dr_first_name IS NULL THEN 1 ELSE 0 END) AS null_dr_first,
    SUM(CASE WHEN dr_last_name IS NULL THEN 1 ELSE 0 END) AS null_dr_last
FROM healthcare.health_staging;
-- Confirmed 0 NULLs across all four name fields -- COUNT(DISTINCT) 
-- 	figures throughout this script are not affected.

-- ============================================
-- SECTION 3: CLINICAL PATTERNS
-- ============================================

-- Unique patient-condition combinations
SELECT `Medical Condition`, COUNT(*) AS patient_condition_count
FROM (SELECT DISTINCT first_name, last_name, `Medical Condition`
      FROM healthcare.health_staging) AS unique_medical_cond
GROUP BY `Medical Condition`
ORDER BY patient_condition_count DESC;

-- vs total admissions per condition
SELECT `Medical Condition`, COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY `Medical Condition`
ORDER BY total_admissions DESC;

-- Average admissions per patient per condition
SELECT `Medical Condition`,
       COUNT(DISTINCT first_name, last_name) AS unique_patients,
       COUNT(*) AS total_admissions,
       ROUND(COUNT(*) / COUNT(DISTINCT first_name, last_name), 2) AS avg_admissions_per_patient
FROM healthcare.health_staging
GROUP BY `Medical Condition`
ORDER BY avg_admissions_per_patient DESC;

-- Medicaal Condition, patient count condition, total admissions, admission/patient
-- 	Arthritis		,		7989			,		9218		,		1.15
-- 	Asthma			,		7802			,		9095		,		1.17
-- 	Cancer			,		7829			,		9140		,		1.17
-- 	Diabetes		,		7909			,		9216		,		1.17
-- 	Hypertension	,		7835			,		9151		,		1.17
-- 	Obesity			,		7817			,		9146		,		1.17

-- The ratio of total admissions to unique patient-condition pairs ranges from 
-- 1.16 to 1.18 across all conditions, meaning patients average slightly more 
-- than one admission per condition. The distribution across conditions is 
-- remarkably even — consistent with synthetic data generation. In real 
-- healthcare data significant variation between conditions would be expected,
-- with chronic conditions like diabetes and hypertension showing much higher
-- repeat admission rates than acute conditions.

-- Unique patient-Insurance provider combinations
SELECT `Insurance Provider`, COUNT(*) AS patient_insurance_count
FROM (SELECT DISTINCT first_name, last_name, `Insurance Provider`
      FROM healthcare.health_staging) AS unique_insurer
GROUP BY `Insurance Provider`
ORDER BY patient_insurance_count DESC;

-- vs total admissions per Insurance provider
SELECT `Insurance Provider`, COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY `Insurance Provider`
ORDER BY total_admissions DESC;

-- Average admissions per patient per insurance provider
SELECT `Insurance Provider`,
       COUNT(DISTINCT first_name, last_name) AS unique_patients,
       COUNT(*) AS total_admissions,
       ROUND(COUNT(*) / COUNT(DISTINCT first_name, last_name), 2) AS avg_admissions_per_patient
FROM healthcare.health_staging
GROUP BY `Insurance Provider`
ORDER BY avg_admissions_per_patient DESC;

-- Insurance provider, patient count insurer, total admissions, admission/insurer
-- 	Aetna		,		9,191			,		10,822		,		1.18
-- 	Blue Cross	,		9,336			,		10,952		,		1.17
-- 	Cigna		,		9,433			,		11,139		,		1.18
-- 	Medicare	,		9,407			,		11,039		,		1.17
-- 	UnitedHealthcare,	9,315			,		11,014		,		1.18

-- The synthetic data distributes patients nearly equally across all five insurers
-- 	(~20% each). This contrasts sharply with real-world market concentration where
-- 	per the AMA's 2025 Update to the Competition in Health Insurance report, UnitedHealth Group
-- 	holds 16% of the commercial market, followed by Elevance (Anthem) and Aetna
-- 	at ~12% each, and Cigna at 9%. Blue Cross Blue Shield plans collectively
-- 	control ~43% of the commercial market. Medicare is a federal program rather
-- 	than a private insurer and operates differently from the commercial carriers
-- 	included alongside it in this dataset. The even distribution confirms this
-- 	data should not be used for insurance market analysis.

-- Unique patient-Admission Type combinations
SELECT `Admission Type`, COUNT(*) AS patient_admit_type_count
FROM (SELECT DISTINCT first_name, last_name, `Admission Type`
      FROM healthcare.health_staging) AS unique_admit_type
GROUP BY `Admission Type`
ORDER BY patient_admit_type_count DESC;

-- vs total admissions per admission type
SELECT `Admission Type`, COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY `Admission Type`
ORDER BY total_admissions DESC;

-- Average admissions per patient per 
SELECT `Admission Type`,
       COUNT(DISTINCT first_name, last_name) AS unique_patients,
       COUNT(*) AS total_admissions,
       ROUND(COUNT(*) / COUNT(DISTINCT first_name, last_name), 2) AS avg_admissions_per_patient
FROM healthcare.health_staging
GROUP BY `Admission Type`
ORDER BY avg_admissions_per_patient DESC;

-- Admission Type, patient count insurer, total admissions, admission/insurer
-- 	Elective	,		15,146			,		18,473		,		1.22
-- 	Emergency	,		14,770			,		18,102		,		1.23
-- 	Urgent		,		18,391			,		18,391		,		1.21

-- The synthetic data distributes admission types nearly equally (~33% each).
-- 	Real-world hospital data shows a very different pattern — per HCUP/NCBI research,
-- 	elective admissions represent roughly 28% of weekday admissions while emergency
-- 	admissions dominate, particularly on weekends (65% of weekend admissions).
-- 	The equal synthetic distribution does not reflect the emergency-heavy reality
-- 	of hospital admission patterns.

-- Unique patient-Test Result combinations
SELECT `Test Results`, COUNT(*) AS patient_test_result_count
FROM (SELECT DISTINCT first_name, last_name, `Test Results`
      FROM healthcare.health_staging) AS unique_test_result
GROUP BY `Test Results`
ORDER BY patient_test_result_count DESC;

-- vs total admissions per test result type
SELECT `Test Results`, COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY `Test Results`
ORDER BY total_admissions DESC;

-- Average admissions per patient per 
SELECT `Test Results`,
       COUNT(DISTINCT first_name, last_name) AS unique_patients,
       COUNT(*) AS total_admissions,
       ROUND(COUNT(*) / COUNT(DISTINCT first_name, last_name), 2) AS avg_admissions_per_patient
FROM healthcare.health_staging
GROUP BY `Test Results`
ORDER BY avg_admissions_per_patient DESC;

-- Test Result	, patient count results , total admissions , admission/insurer
-- Abnormal		,		15,114			,		18,437		,		1.22
-- Inconclusive	,		14,930			,		18,198		,		1.22
-- Normal		,		15,015			,		18,331		,		1.22

-- The synthetic data distributes test results nearly equally (~33% each across
-- 	Normal, Abnormal, and Inconclusive). Real-world clinical test result distributions
-- 	vary significantly by test type, patient population, and condition being tested.
-- 	No universal benchmark exists for comparison, but equal distribution across
-- 	all three outcomes is unlikely in any real clinical setting and confirms the
-- 	synthetic nature of this dataset.

-- ============================================
-- SECTION 4: BILLING ANALYSIS
-- ============================================

SELECT ROUND(MIN(`Billing Amount`), 2) AS min_billed, 
		ROUND(MAX(`Billing Amount`), 2) AS max_billed,
        ROUND(AVG(`Billing Amount`), 2) AS avg_billed
FROM healthcare.health_staging;
-- The minimum is -2,008.49, average is 25,544.31 and maximum is 52,764.28

-- Check how many negative billing amounts there are
SELECT COUNT(`Billing Amount`) AS negative_billed
FROM healthcare.health_staging
WHERE `Billing Amount` < 0;

-- Note: 106 negative billing amounts were identified during EDA that were not
-- 	caught during the cleaning phase. Negative billing amounts are not clinically
-- 	valid for patient admissions. These may represent data entry errors, credits,
-- 	or Faker generation artifacts. These rows are excluded from billing analysis
-- 	using WHERE Billing Amount >= 0.

SELECT ROUND(MIN(`Billing Amount`), 2) AS min_billed, 
		ROUND(MAX(`Billing Amount`), 2) AS max_billed,
        ROUND(AVG(`Billing Amount`), 2) AS avg_billed
FROM healthcare.health_staging
WHERE `Billing Amount` >= 0;
-- Removing the negative values the minimum is 0.24, average is 25,594.63 and 
-- 	maximum is 52,764.28

-- Billing amount by medical condition
SELECT `Medical Condition`,
       ROUND(MIN(`Billing Amount`), 2) AS min_billed,
       ROUND(AVG(`Billing Amount`), 2) AS avg_billed,
       ROUND(MAX(`Billing Amount`), 2) AS max_billed,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
WHERE `Billing Amount` >= 0
GROUP BY `Medical Condition`
ORDER BY avg_billed DESC;

-- Medical Condition	, min_billed, avg_billed	, max_billed	, total_admissions
-- Arthritis			,	32.63	,	25,542.9	,	52,170.04	,	9207
-- Asthma			, 	42.51	, 	25,685.39	,	52,181.84	,	9077
-- Cancer			,	 9.24	, 	25,205.92	, 	52,373.03	,	9121
-- Diabetes			,	31.03	, 	25,714.33	, 	52,211.85	,	9197
-- Hypertension		, 	68.91	, 	25,559.84	, 	52,764.28	, 	9131
-- Obesity			, 	53.93	, 	25,859.22	, 	52,024.73	, 	9127

-- Billing by medical condition shows minimal variation in average billing
-- 	(range: $25,205 to $25,859) across all six conditions. In real healthcare
-- 	data significant cost differences would be expected — cancer treatment
-- 	and chronic disease management typically generate far higher billing than
-- 	asthma or obesity management. The near-identical averages confirm
-- 	synthetic data generation with no cost modeling by condition.

-- Billing amount by admission type
SELECT `Admission Type`,
       ROUND(MIN(`Billing Amount`), 2) AS min_billed,
       ROUND(AVG(`Billing Amount`), 2) AS avg_billed,
       ROUND(MAX(`Billing Amount`), 2) AS max_billed,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
WHERE `Billing Amount` >= 0
GROUP BY `Admission Type`
ORDER BY avg_billed DESC;

-- Admission 	, min_billed, avg_billed, max_billed, total_admissions
-- 	Type
-- Elective		,  9.24		, 25,663.34	, 52,764.28	, 	18,437
-- Emergency		, 23.73		, 25,551.13	, 52,271.66	, 	18,070
-- Urgent		, 31.03		, 25,568.44	, 52,373.03	, 	18,353

-- Billing by admission type shows virtually no difference in average billing
-- 	(Elective $25,663, Emergency $25,551, Urgent $25,568). In real healthcare
-- 	data emergency admissions typically generate 2-3x higher billing than
-- 	elective procedures due to intensive resource utilization. The flat
-- 	distribution confirms no cost modeling by admission type in the dataset.

-- Billing amount by insurance provider
SELECT `Insurance Provider`,
       ROUND(MIN(`Billing Amount`), 2) AS min_billed,
       ROUND(AVG(`Billing Amount`), 2) AS avg_billed,
       ROUND(MAX(`Billing Amount`), 2) AS max_billed,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
WHERE `Billing Amount` >= 0
GROUP BY `Insurance Provider`
ORDER BY avg_billed DESC;

-- Insurance Provider, min_billed, avg_billed, max_billed, total_admissions
-- Aetna				, 	32.63	, 25,615.26	, 52,211.85	, 	10,795
-- Blue Cross		, 	42.51	, 25,639.27	, 52,764.28	, 	10,937
-- Cigna				, 	38.97	, 25,582.23	, 52,170.04	, 	11,115
-- Medicare			, 	90.83	, 25,678.09	, 52,092.67	, 	11,018
-- UnitedHealthcare	, 	 9.24	, 25,458.89	, 52,373.03	, 	10,995

-- Billing by insurance provider shows near-identical averages across all
-- 	five providers (range: $25,458 to $25,678). Real-world billing varies
-- 	significantly by insurance negotiated rates and coverage type. Medicare
-- 	in particular operates under fixed reimbursement schedules that would
-- 	produce very different billing patterns than commercial insurers.

-- Billing amount by age range
SELECT age_range,
       ROUND(AVG(`Billing Amount`), 2) AS avg_billed,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
WHERE `Billing Amount` >= 0
GROUP BY age_range
ORDER BY MIN(Age);

-- age_range	, avg_billed, total_admissions
-- 	13-19	, 26,369.03	, 	1,674
-- 	20-29	, 25,463.19	, 	7,915
-- 	30-39	, 25,739.39	,	8,088
-- 	40-49	, 25,515.01	, 	8,028
-- 	50-59	, 25,577.77	,	8,247
-- 	60-69	, 25,637.07	, 	8,085
-- 	70-79	, 25,619.93	, 	7,985
-- 	80-89	, 25,347.96	, 	4,838

-- Billing by age range shows minimal variation ($25,347 to $26,369).
-- 	The 13-19 age group shows the highest average at $26,369 which is
-- 	counterintuitive since younger patients typically generate lower
-- 	healthcare costs. The 80-89 group shows the lowest average at $25,347
-- 	which contradicts real-world patterns where elderly patients typically
-- 	have the highest healthcare utilization and costs. Both observations
-- 	confirm the synthetic nature of the data.

-- ============================================
-- SECTION 5: LENGTH OF STAY ANALYSIS
-- ============================================

SELECT 
    ROUND(AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)), 1) AS avg_stay_days,
    MIN(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS min_stay_days,
    MAX(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS max_stay_days
FROM healthcare.health_staging;

-- The average stay in days is 15.5 days, The minimum is 1 and max is 30 days.

-- Length of stay by medical condition
SELECT `Medical Condition`,
       ROUND(AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)), 1) AS avg_stay_days,
       MIN(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS min_stay_days,
       MAX(DATEDIFF(`Discharge Date`, `Date of Admission`)) AS max_stay_days
FROM healthcare.health_staging
GROUP BY `Medical Condition`
ORDER BY avg_stay_days DESC;

-- The minimum stay for all conditions is 1 day and maximum stay for all conditions is 30
-- 	days.  The average for all is very close they range from 15.4 - 15.7 days.  This is 
-- 	likely an artifact of this being synthetic data.  

-- Length of stay by admission type
SELECT `Admission Type`,
       ROUND(AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)), 1) AS avg_stay_days
FROM healthcare.health_staging
GROUP BY `Admission Type`
ORDER BY avg_stay_days DESC;

-- The average stays based on admission types are elective 15.5 days, emergency
-- 	15.6 days and urgent care 15.4 days.  

-- ============================================
-- SECTION 6: MEDICATION ANALYSIS
-- ============================================

-- Overall medication distribution
SELECT Medication,
       COUNT(*) AS total_prescriptions,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM healthcare.health_staging
GROUP BY Medication
ORDER BY total_prescriptions DESC;

-- Medication	,total_prescriptions, pct_of_total
-- Aspirin		, 	10,984			, 	20.0
-- Ibuprofen		, 	11,023			, 	20.1
-- Lipitor		,	11,038			, 	20.1
-- Paracetamol	, 	10,965			, 	19.9
-- Penicillin	, 	10,956			, 	19.9

-- Medications are distributed nearly equally across all five options (~20% each).
-- 	This is clinically unrealistic — in real healthcare settings medication 
-- 	prescribing patterns are driven by diagnosis, patient history, allergies,
-- 	and clinical guidelines. The flat distribution confirms random assignment
-- 	by the Faker library with no clinical modeling.

-- Medication by medical condition
-- Shows which medications are most commonly prescribed for each condition
SELECT `Medical Condition`,
       Medication,
       COUNT(*) AS prescription_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY `Medical Condition`), 1) AS pct_within_condition
FROM healthcare.health_staging
GROUP BY `Medical Condition`, Medication
ORDER BY `Medical Condition`, prescription_count DESC;

-- Medivsl Condition	,	Medication	,	prescription_count	, pct_within_condition
-- Arthritis			,	Aspirin		,			1901		,		20.6
-- Arthritis 		,	Paracetamol	,			1858		,		20.2
-- Arthritis			,	Penicillin	,			1844		,		20
-- Arthritis			,	Lipitor		,			1810		,		19.6
-- Arthritis			,	Ibuprofen	,			1805		,		19.6
-- Asthma			,	Paracetamol	,			1870		,		20.6
-- Asthma			,	Penicillin	,			1828		,		20.1
-- Asthma			,	Lipitor		,			1814		,		19.9
-- Asthma			,	Ibuprofen	,			1802		,		19.8
-- Asthma			,	Aspirin		,			1781		,		19.6
-- Cancer			,	Lipitor		,			1904		,		20.8
-- Cancer			,	Ibuprofen	,			1862		,		20.4
-- Cancer			,	Paracetamol	,			1829		,		20
-- Cancer			,	Penicillin	,			1777		,		19.4
-- Cancer			,	Aspirin		,			1768		,		19.3
-- Diabetes			,	Lipitor		,			1875		,		20.3
-- Diabetes			,	Penicillin	,			1865		,		20.2
-- Diabetes			,	Ibuprofen	,			1846		,		20
-- Diabetes			,	Aspirin		,			1836		,		19.9
-- Diabetes			,	Paracetamol	,			1794		,		19.5
-- Hypertension		,	Ibuprofen	,			1874		,		20.5
-- Hypertension		,	Aspirin		,			1845		,		20.2
-- Hypertension		,	Paracetamol	,			1839		,		20.1
-- Hypertension		,	Lipitor		,			1823		,		19.9
-- Hypertension		,	Penicillin	,			1770		,		19.3
-- Obesity			,	Penicillin	,			1872		,		20.5
-- Obesity			,	Aspirin		,			1853		,		20.3
-- Obesity			,	Ibuprofen	,			1834		,		20.1
-- Obesity			,	Lipitor		,			1812		,		19.8
-- Obesity			,	Paracetamol	,			1775		,		19.4

-- Each condition shows near-equal distribution across all five medications
-- 	(~20% each). Clinically this makes no sense — Penicillin is an antibiotic
-- 	inappropriate for chronic conditions like arthritis or diabetes, and Lipitor
-- 	(a cholesterol medication) would not typically be the top prescription for
-- 	cancer. The random assignment across conditions confirms this dataset cannot
-- 	be used for clinical prescribing pattern analysis.

-- Most common medication per condition
WITH medication_ranks AS (
    SELECT `Medical Condition`,
           Medication,
           COUNT(*) AS prescription_count,
           RANK() OVER(PARTITION BY `Medical Condition` 
                       ORDER BY COUNT(*) DESC) AS med_rank
    FROM healthcare.health_staging
    GROUP BY `Medical Condition`, Medication
)
SELECT `Medical Condition`, Medication, prescription_count
FROM medication_ranks
WHERE med_rank = 1
ORDER BY `Medical Condition`;

-- Medical Condition	,	Medication	, prescription_count
-- Arthritis			, Aspirin		, 		1901
-- Asthma			, Paracetamol	, 		1870
-- Cancer			, Lipitor		, 		1904
-- Diabetes			, Lipitor		, 		1875
-- Hypertension		, Ibuprofen		, 		1874
-- Obesity			, Penicillin	, 		1872

-- The "most common" medication per condition varies only due to random noise
-- 	in the data — the differences between medications within each condition
-- 	are statistically insignificant (all within 1-2% of each other).
-- 	More importantly, the top prescribed medications are clinically inappropriate
-- 	for their assigned conditions:
-- 		- Aspirin as the top medication for Arthritis: while aspirin has some 
-- 		  	anti-inflammatory properties, it is not a first-line arthritis treatment
-- 		- Paracetamol as top for Asthma: pain relief medication unrelated to 
--   		respiratory treatment
-- 		- Lipitor (cholesterol medication) as top for both Cancer and Diabetes:
--   		while Lipitor may be prescribed alongside these conditions it would not
--   		be the primary treatment medication
-- 		- Ibuprofen as top for Hypertension: clinically contraindicated as NSAIDs
--   		like Ibuprofen can raise blood pressure and reduce effectiveness of
--   		hypertension medications
-- 		- Penicillin (antibiotic) as top for Obesity: an antibiotic has no role
--   		in obesity treatment whatsoever
-- 	This confirms random medication assignment with no clinical logic applied
-- 	and reinforces that this dataset cannot be used for prescribing analysis.

-- Medication by admission type
SELECT `Admission Type`,
       Medication,
       COUNT(*) AS prescription_count
FROM healthcare.health_staging
GROUP BY `Admission Type`, Medication
ORDER BY `Admission Type`, prescription_count DESC;

-- Admission Type, 	Medication	,	prescription_count
-- Elective		,	Aspirin		,		3740
-- Elective		, 	Paracetamol	,		3703
-- Elective		,	Penicillin	,		3701
-- Elective		,	Ibuprofen	,		3694
-- Elective		,	Lipitor		,		3635
-- Emergency		,	Paracetamol	,		3642
-- Emergency		,	Lipitor		,		3627
-- Emergency		,	Ibuprofen	,		3626
-- Emergency		,	Penicillin	,		3612
-- Emergency		,	Aspirin		,		3595
-- Urgent		,	Lipitor		,		3776
-- Urgent		,	Ibuprofen	,		3703
-- Urgent		,	Aspirin		,		3649
-- Urgent		,	Penicillin	,		3643
-- Urgent		,	Paracetamol	,		3620

-- Medication distribution by admission type shows near-equal prescribing
-- 	across all five medications regardless of whether the admission was
-- 	elective, emergency, or urgent. In real clinical settings admission
-- 	type significantly influences medication choice — emergency admissions
-- 	often require immediate intervention medications very different from
-- 	planned elective procedure protocols.

-- ============================================
-- SECTION 7: TEST RESULTS ANALYSIS
-- ============================================

-- Overall test result distribution
SELECT `Test Results`,
       COUNT(*) AS total,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM healthcare.health_staging
GROUP BY `Test Results`
ORDER BY total DESC;

-- Test Results	, 	total	,	percent of total
-- Abnormal		,	18,437	,		33.5%
-- Inconclusive	,	18,198	,		33.1%
-- Normal		,	18,331	,		33.3%

-- Test results are distributed almost equally across all three outcomes
-- 	(~33% each). In real clinical settings Normal results typically dominate
-- 	most screening tests, with Abnormal and Inconclusive results representing
-- 	smaller proportions that vary significantly by test type and patient population.
-- 	The equal distribution confirms random assignment with no clinical modeling.

-- Test results by medical condition
SELECT `Medical Condition`,
       `Test Results`,
       COUNT(*) AS result_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY `Medical Condition`), 1) AS pct_within_condition
FROM healthcare.health_staging
GROUP BY `Medical Condition`, `Test Results`
ORDER BY `Medical Condition`, result_count DESC;

-- Medical Condition	,	Test Results,	result_count,	pct_within_condition
-- Arthritis			,	Abnormal	,		3156	,		34.2
-- Arthritis			,	Inconclusive,		3062	,		33.2
-- Arthritis			,	Normal		,		3000	,		32.5
-- Asthma			,	Normal		,		3116	,		34.3
-- Asthma			,	Inconclusive,		2999	,		33
-- Asthma			,	Abnormal	,		2980	,		32.8
-- Cancer			,	Abnormal	,		3089	,		33.8
-- Cancer			,	Inconclusive,		3033	,		33.2
-- Cancer			,	Normal		,		3018	,		33
-- Diabetes			,	Abnormal	,		3131	,		34
-- Diabetes			,	Normal		,		3061	,		33.2
-- Diabetes			,	Inconclusive,		3024	,		32.8
-- Hypertension		,	Normal		,		3106	,		33.9
-- Hypertension		,	Inconclusive,		3068	,		33.5
-- Hypertension		,	Abnormal	,		2977	,		32.5
-- Obesity			,	Abnormal	,		3104	,		33.9
-- Obesity			,	Normal		,		3030	,		33.1
-- Obesity			,	Inconclusive,		3012	,		32.9

-- No meaningful pattern exists between medical condition and test results —
-- 	each condition shows approximately equal distribution across Normal, Abnormal,
-- 	and Inconclusive (~33% each). In real healthcare data test results would be
-- 	strongly correlated with the presenting condition — cancer patients would
-- 	show significantly higher Abnormal rates while routine monitoring of stable
-- 	chronic conditions might show predominantly Normal results.

-- Test results by medication
-- Shows whether certain medications correlate with better test outcomes
SELECT Medication,
       `Test Results`,
       COUNT(*) AS result_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY Medication), 1) AS pct_within_medication
FROM healthcare.health_staging
GROUP BY Medication, `Test Results`
ORDER BY Medication, result_count DESC;

-- Medication,	Test Results,	result_count,	pct_within_medication
-- Aspirin	,	Abnormal	,		3700	,		33.7
-- Aspirin	,	Normal		,		3696	,		33.6
-- Aspirin	,	Inconclusive,		3588	,		32.7
-- Ibuprofen	,	Abnormal	,		3711	,		33.7
-- Ibuprofen	,	Normal		,		3699	,		33.6
-- Ibuprofen	,	Inconclusive,		3613	,		32.8
-- Lipitor	,	Inconclusive,		3720	,		33.7
-- Lipitor	,	Abnormal	,		3670	,		33.2
-- Lipitor	,	Normal		,		3648	,		33
-- Paracetamol,	Abnormal	,		3695	,		33.7
-- Paracetamol,	Inconclusive,		3646	,		33.3
-- Paracetamol,	Normal		,		3624	,		33.1
-- Penicillin,	Normal		,		3664	,		33.4
-- Penicillin,	Abnormal	,		3661	,		33.4
-- Penicillin,	Inconclusive,		3631	,		33.1

-- No correlation exists between medication and test outcomes — all medications
-- 	show ~33% distribution across all three result types. In real clinical data
-- 	medication effectiveness would be reflected in test results, with treated
-- 	patients trending toward Normal outcomes over time.

-- Test results by admission type
SELECT `Admission Type`,
       `Test Results`,
       COUNT(*) AS result_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY `Admission Type`), 1) AS pct_within_admission_type
FROM healthcare.health_staging
GROUP BY `Admission Type`, `Test Results`
ORDER BY `Admission Type`, result_count DESC;

-- Admission Type,	Test Results, result_count	, % within admission type
-- Elective		,	Abnormal	,	6232		,		33.7%
-- Elective		,	Normal		,	6187		,		33.5%
-- Elective		,	Inconclusive,	6054		,		32.8%
-- Emergency		,	Normal		,	6044		,		33.4%
-- Emergency		,	Abnormal	,	6038		,		33.4%
-- Emergency		,	Inconclusive,	6020		,		33.3%
-- Urgent		,	Abnormal	,	6167		,		33.5%
-- Urgent		,	Inconclusive,	6124		,		33.3%
-- Urgent		,	Normal		,	6100		,		33.2%

-- Test results show no meaningful variation by admission type (~33% each across
-- 	all three admission types). Emergency admissions in real healthcare settings
-- 	would be expected to show significantly higher Abnormal rates given the acute
-- 	nature of emergency presentations.

-- Test results by age range
SELECT age_range,
       `Test Results`,
       COUNT(*) AS result_count,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY age_range), 1) AS pct_within_age_range
FROM healthcare.health_staging
GROUP BY age_range, `Test Results`
ORDER BY MIN(Age), `Test Results`;

-- age_range	,	Test Results,	result_count,	pct_within_age_range
-- 13-19		,	Abnormal	,		562		,		33.5
-- 13-19		,	Inconclusive,		532		,		31.7
-- 13-19		,	Normal		,		583		,		34.8
-- 20-29		,	Abnormal	,		2601	,		32.8
-- 20-29		,	Inconclusive,		2601	,		32.8
-- 20-29		,	Normal		,		2726	,		34.4
-- 30-39		,	Abnormal	,		2723	,		33.6
-- 30-39		,	Inconclusive,		2653	,		32.7
-- 30-39		,	Normal		,		2729	,		33.7
-- 40-49		,	Abnormal	,		2702	,		33.6
-- 40-49		,	Inconclusive,		2691	,		33.4
-- 40-49		,	Normal		,		2652	,		33
-- 50-59		,	Abnormal	,		2815	,		34.1
-- 50-59		,	Inconclusive,		2749	,		33.3
-- 50-59		,	Normal		,		2699	,		32.7
-- 60-69		,	Abnormal	,		2702	,		33.4
-- 60-69		,	Inconclusive,		2723	,		33.6
-- 60-69		,	Normal		,		2674	,		33
-- 70-79		,	Abnormal	,		2711	,		33.9
-- 70-79		,	Inconclusive,		2601	,		32.5
-- 70-79		,	Normal		,		2687	,		33.6
-- 80-89		,	Abnormal	,		1621	,		33.4
-- 80-89		,	Inconclusive,		1648	,		34
-- 80-89		,	Normal		,		1581	,		32.6

-- Test results show no meaningful variation across age ranges (~33% each).
-- 	In real healthcare data older patients typically show higher rates of Abnormal
-- 	results due to increased prevalence of chronic conditions and age-related
-- 	health changes. The flat distribution across all age groups from 13-19 through
-- 	80-89 confirms no age-related clinical modeling in the synthetic data.

-- Summary observation: medication and test result independence
-- Running a cross-tabulation confirms no correlation between medication 
-- prescribed and test result outcome
SELECT Medication,
       `Test Results`,
       `Medical Condition`,
       COUNT(*) AS count
FROM healthcare.health_staging
GROUP BY Medication, `Test Results`, `Medical Condition`
ORDER BY count DESC
LIMIT 10;

-- Medication	,  Test Results	, Medical Condition	,  count
-- Aspirin		,	Abnormal	,	Arthritis		,	665
-- Aspirin		,	Normal		,	Hypertension	,	658
-- Paracetamol	,	Abnormal	,	Arthritis		,	652
-- Lipitor		,	Inconclusive,	Cancer			,	652
-- Ibuprofen		,	Normal		,	Hypertension	,	651
-- Lipitor		,	Inconclusive,	Hypertension	,	648
-- Penicillin	,	Abnormal	,	Obesity			,	644
-- Paracetamol	,	Inconclusive,	Asthma			.	643
-- Lipitor		,	Abnormal	,	Diabetes		,	642
-- Lipitor		,	Normal		,	Cancer			,	641

-- The top 10 medication-result-condition combinations all show counts between
-- 	641 and 665 out of 54,966 total records. With 5 medications, 3 test results,
-- 	and 6 conditions there are 90 possible combinations, and 54,966 / 90 = 611
-- 	expected count per combination if distribution were perfectly random.
-- 	The actual counts (641-665) fall very close to that expected random value,
-- 	confirming complete independence between medication, test result, and medical
-- 	condition. 
-- Notable observations in the top combinations:
-- 	- Aspirin + Abnormal + Arthritis appearing at the top is coincidental noise
--   	not a clinical signal — the same medication appears with Normal results
--   	for Hypertension at nearly the same count
-- 	- Penicillin + Abnormal + Obesity appearing confirms the random assignment —
--   	an antibiotic producing abnormal test results in obesity patients has no
--   	clinical basis
-- In real healthcare data these three variables would be strongly 
-- 	interdependent — specific conditions drive specific medications which in
-- 	turn influence specific test outcome distributions. The near-uniform
-- 	distribution across all 90 combinations confirms this dataset is unsuitable
-- 	for any clinical correlation analysis.

-- Time-Based Admission Analysis

-- Admissions by year
SELECT YEAR(`Date of Admission`) AS admission_year,
       COUNT(*) AS total_admissions,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM healthcare.health_staging
GROUP BY YEAR(`Date of Admission`)
ORDER BY admission_year;

-- admission_year, total_admissions	, pct_of_total
-- 	2019		,		 7300		,	13.3
-- 	2020		, 		11172		, 	20.3
-- 	2021		, 		10816		, 	19.7
-- 	2022		, 		10915		, 	19.9
-- 	2023		, 		10936		, 	19.9
-- 	2024		, 		 3827		, 	 7.0

-- 2019 (13.3%) and 2024 (7.0%) are partial years — the dataset begins in 
-- 	May 2019 and ends in May 2024, so these years represent approximately 
-- 	8 and 5 months of data respectively. The four complete years 2020-2023 
-- 	show remarkably consistent admission volumes (~10,800-11,200 per year, 
-- 	~20% each). In real healthcare data year-over-year variation would be 
-- 	expected due to seasonal illness patterns, population growth, and external
-- 	events. The flat distribution across complete years confirms synthetic 
-- 	data generation with no temporal modeling.

-- ============================================
-- SECTION 8: TIME-BASED ADMISSION ANALYSIS
-- ============================================

-- Admissions by month (across all years)
SELECT MONTH(`Date of Admission`) AS month_num,
       DATE_FORMAT(`Date of Admission`, '%M') AS month_name,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY MONTH(`Date of Admission`), DATE_FORMAT(`Date of Admission`, '%M')
ORDER BY month_num;

-- month_num	, month_name, total_admissions
-- 	1		, 	January	, 		4655
-- 	2		, 	February, 		4210
-- 	3		, 	March	, 		4622
-- 	4		,	April	,		4478
-- 	5		, 	May		, 		4555
-- 	6		,	June	,		4650
-- 	7		,	July	,		4765
-- 	8		,	August	,		4785
-- 	9		, 	September, 		4508
--  10		,	October	,		4613
-- . 11		,	November,		4508
--  12		,	December,		4617

-- Monthly admissions show minimal variation (4,210 in February to 4,785 
-- 	in August). February's lower count is likely explained by it being the 
-- 	shortest month rather than any clinical pattern. Real healthcare data 
-- 	typically shows winter spikes for respiratory conditions and influenza, 
-- 	and summer dips for elective procedures. The near-flat monthly 
-- 	distribution confirms random date assignment with no seasonal modeling.
-- 	Note: July and August show the highest admission counts which is the 
-- 	opposite of real-world patterns where summer typically sees fewer 
-- 	elective admissions.


-- Admissions by year and month (monthly trend)
SELECT DATE_FORMAT(`Date of Admission`, '%Y-%m') AS `year_month`,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY DATE_FORMAT(`Date of Admission`, '%Y-%m')
ORDER BY `year_month`;

-- Rolling 3-month average of admissions
WITH monthly_admissions AS (
    SELECT DATE_FORMAT(`Date of Admission`, '%Y-%m') AS `year_month`,
           COUNT(*) AS total_admissions
    FROM healthcare.health_staging
    GROUP BY DATE_FORMAT(`Date of Admission`, '%Y-%m')
)
SELECT `year_month`,
       total_admissions,
       ROUND(AVG(total_admissions) OVER(
           ORDER BY `year_month`
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 0) AS rolling_3mo_avg
FROM monthly_admissions
ORDER BY `year_month`;

-- 	year_month	,	total_admissions,	rolling_3mo_avg
-- 	2019-05		,		 677			,		677
-- 	2019-06		,		 899			,		788
-- 	2019-07		,		 951			,		842
-- 	2019-08		,		 985			,		945
-- 	2019-09		,		 924			,		953
-- 	2019-10		,		 993			,		967
-- 	2019-11		,		 950			,		956
-- 	2019-12		,		 921			,		955
-- 	2020-01		,		 942			,		938
-- 	2020-02		,		 868			,		910
-- 	2020-03		,		 924			,		911
-- 	2020-04		,		 911			,		901
-- 	2020-05		,		 970			,		935
-- 	2020-06		,		 924			,		935
-- 	2020-07		,		1000			,		965
-- 	2020-08		,		1003			,		976
-- 	2020-09		,		 899			,		967
-- 	2020-10		,		 948			,		950
-- 	2020-11		,		 900			,		916
-- 	2020-12		,		 883			,		910
-- 	2021-01		,		 924			,		902
-- 	2021-02		,		 828			,		878
-- 	2021-03		,		 953			,		902
-- 	2021-04		,		 862			,		881
-- 	2021-05		,		 893			,		903
-- 	2021-06		,		 915			,		890
-- 	2021-07		,		 966			,		925
-- 	2021-08		,		 887			,		923
-- 	2021-09		,		 860			,		904
-- 	2021-10		,		 885			,		877
-- 	2021-11		,		 899			,		881
-- 	2021-12		,		 944			,		909
-- 	2022-01		,		 960			,		934
-- 	2022-02		,		 772			,		892
-- 	2022-03		,		 931			,		888
-- 	2022-04		,		 871			,		858
-- 	2022-05		,		 885			,		896
-- 	2022-06		,		 959			,		905
-- 	2022-07		,		 935			,		926
-- 	2022-08		,		 948			,		947
-- 	2022-09		,		 912			,		932
-- 	2022-10		,		 903			,		921
-- 	2022-11		,		 886			,		900
-- 	2022-12		,		 953			,		914
-- 	2023-01		,		 926			,		922
-- 	2023-02		,		 873			,		917
-- 	2023-03		,		 912			,		904
-- 	2023-04		,		 893			,		893
-- 	2023-05		,		 918			,		908
-- 	2023-06		,		 953			,		921
-- 	2023-07		,		 913			,		928
-- 	2023-08		,		 962			,		943
-- 	2023-09		,		 913			,		929
-- 	2023-10		,		 884			,		920
-- 	2023-11		,		 873			,		890
-- 	2023-12		,		 916			,		891
-- 	2024-01		,		 903			,		897
-- 	2024-02		,		 869			,		896
-- 	2024-03		,		 902			,		891
-- 	2024-04		,		 941			,		904
-- 	2024-05		,		 212			,		685

-- The rolling 3-month average confirms the flat admission trend throughout
-- 	the dataset. After the initial ramp-up in mid-2019 (partial first year),
-- 	monthly admissions stabilize around 900-960 per month with no sustained
-- 	upward or downward trend across the full 2020-2023 period. The sharp 
-- 	drop in May 2024 (212 admissions) reflects the dataset ending mid-month.
-- 	In real healthcare data a rolling average would typically reveal seasonal
-- 	waves and year-over-year growth trends.


-- Admissions by day of week
SELECT DAYOFWEEK(`Date of Admission`) AS day_num,
       DATE_FORMAT(`Date of Admission`, '%W') AS day_name,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY DAYOFWEEK(`Date of Admission`), DATE_FORMAT(`Date of Admission`, '%W')
ORDER BY day_num;

-- day_num, day_name, total_admissions
-- 	1	,	Sunday	,	 7850
-- 	2	,	Monday	,	 7781
-- 	3	,	Tuesday	,	 7913
-- 	4	, Wednesday	,	 7873
-- 	5	, 	Thursday,	 7909
-- 	6	, 	Friday	,	 7818
-- 	7	, 	Saturday,	 7822

-- Admissions are distributed nearly equally across all seven days of the 
-- 	week (7,781 to 7,913). This is one of the clearest indicators of 
-- 	synthetic data generation — in real hospitals elective admissions are 
-- 	heavily concentrated on weekdays (Monday-Friday) with weekends dominated
-- 	by emergency admissions only. Per HCUP research, only 11% of weekend 
-- 	admissions are elective compared to 28% of weekday admissions. The 
-- 	perfectly flat day-of-week distribution confirms no scheduling logic 
-- 	was applied during data generation.

-- Admissions by medical condition by year
SELECT YEAR(`Date of Admission`) AS admission_year,
       `Medical Condition`,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY YEAR(`Date of Admission`), `Medical Condition`
ORDER BY admission_year, total_admissions DESC;

-- admission_year,Medical Condition	,	total_admissions
-- 	2019		,	Asthma			,		1274
-- 	2019		,	Cancer			,		1272
-- 	2019		,	Diabetes		,		1233
-- 	2019		,	Arthritis		,		1187
-- 	2019		,	Hypertension	,		1175
-- 	2019		,	Obesity			,		1159
-- 	2020		,	Obesity			,		1953
-- 	2020		,	Hypertension	,		1883
-- 	2020		,	Cancer			,		1882
-- 	2020		,	Arthritis		,		1871
-- 	2020		,	Diabetes		,		1792
-- 	2020		,	Asthma			,		1791
-- 	2021		,	Hypertension	,		1849
-- 	2021		,	Arthritis		,		1827
-- 	2021		,	Asthma			,		1822
-- 	2021		,	Obesity			,		1811
-- 	2021		,	Diabetes		,		1779
-- 	2021		,	Cancer			,		1728
-- 	2022		,	Diabetes		,		1922
-- 	2022		,	Arthritis		,		1838
-- 	2022		,	Hypertension	,		1818
-- 	2022		,	Cancer			,		1809
-- 	2022		,	Obesity			,		1777
-- 	2022		,	Asthma			,		1751
-- 	2023		,	Obesity			,		1850
-- 	2023		,	Diabetes		,		1838
-- 	2023		,	Cancer			,		1831
-- 	2023		,	Hypertension	,		1829
-- 	2023		,	Arthritis		,		1806
-- 	2023		,	Asthma			,		1782
-- 	2024		,	Arthritis		,		 689
-- 	2024		,	Asthma			,		 675
-- 	2024		,	Diabetes		,		 652
-- 	2024		,	Cancer			,		 618
-- 	2024		,	Hypertension	,		 597
-- 	2024		,	Obesity			,		 596

-- Condition distribution shifts slightly by year but no consistent pattern
-- 	emerges — the leading condition changes each year (Asthma 2019, Obesity 
-- 	2020, Hypertension 2021, Diabetes 2022, Obesity 2023) with no condition
-- 	showing a sustained upward trend. In real healthcare data chronic 
-- 	conditions like diabetes and obesity have shown consistent year-over-year
-- 	increases in admission rates reflecting population health trends.
-- 	The random year-to-year leadership changes confirm synthetic generation.

-- Average length of stay by year
SELECT YEAR(`Date of Admission`) AS admission_year,
       ROUND(AVG(DATEDIFF(`Discharge Date`, `Date of Admission`)), 1) AS avg_stay_days,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
GROUP BY YEAR(`Date of Admission`)
ORDER BY admission_year;

-- admission_year, avg_stay_days	, total_admissions
-- 	2019		, 	15.6		, 		 7300
-- 	2020		, 	15.5		, 		11172
-- 	2021		, 	15.4		, 		10816
-- 	2022		, 	15.4		, 		10915
-- 	2023		, 	15.5		, 		10936
-- 	2024		, 	15.8		, 		 3827

-- Average length of stay is remarkably stable across all years (15.4 to 
-- 	15.8 days) with no year-over-year trend. Real healthcare data shows a 
-- 	long-term declining trend in average length of stay driven by advances 
-- 	in treatment, shift toward outpatient care, and insurance pressure to 
-- 	reduce inpatient days. The flat synthetic average of ~15.5 days is also
-- 	notably high -- the real US national average length of stay per 
-- 	CDC/NCHS (sourcing AHA data) was 6.3 days in 2020, 6.5 in 2021, 6.6 in
-- 	2022, and 6.5 in 2023, meaning the synthetic value is roughly 2.4x the 
-- 	real-world benchmark.

-- Average billing by year
SELECT YEAR(`Date of Admission`) AS admission_year,
       ROUND(AVG(`Billing Amount`), 2) AS avg_billed,
       COUNT(*) AS total_admissions
FROM healthcare.health_staging
WHERE `Billing Amount` >= 0
GROUP BY YEAR(`Date of Admission`)
ORDER BY admission_year;

-- admission_year, avg_billed	, total_admissions
-- 		2019	, 	25758.02	, 		 7280
-- 		2020	,	25451.25	, 		11157
-- 		2021	, 	25677.31	, 		10795
-- 		2022	, 	25583.1		, 		10891
-- 		2023	, 	25616.5		, 		10918
-- 		2024	, 	25438.72	, 		 3819

-- Average billing shows no meaningful year-over-year trend ($25,438 to 
-- 	$25,758 across all years, a range of only $319). Real healthcare billing
-- 	consistently increases year-over-year due to medical inflation -- per CMS
-- 	National Health Expenditure data, hospital services specifically rose 6.9%
-- 	from 2023-2024 alone, well above general CPI growth of 3.0% in the same
-- 	period. A real dataset covering 2019-2024 would show substantial cumulative
-- 	billing increases across those years. The flat synthetic billing confirms
-- 	no inflation modeling was applied.

-- Admissions by admission type by year
SELECT YEAR(`Date of Admission`) AS admission_year,
       `Admission Type`,
       COUNT(*) AS total_admissions,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY YEAR(`Date of Admission`)), 1) AS pct_within_year
FROM healthcare.health_staging
GROUP BY YEAR(`Date of Admission`), `Admission Type`
ORDER BY admission_year, total_admissions DESC;

-- 	admission_year	,Admission Type	,total_admissions,pct_within_year
-- 		2019		,	 Urgent		,	2516		,	34.5
-- 		2019		,	Elective	,	2496		,	34.2
-- 		2019		,	Emergency	,	2288		,	31.3
-- 		2020		,	Emergency	,	3818		,	34.2
-- 		2020		,	Urgent		,	3683		,	33
-- 		2020		,	Elective	,	3671		,	32.9
-- 		2021		,	Elective	,	3688		,	34.1
-- 		2021		,	Urgent		,	3596		,	33.2
-- 		2021		,	Emergency	,	3532		,	32.7
-- 		2022		,	Elective	,	3725		,	34.1
-- 		2022		,	Urgent		,	3666		,	33.6
-- 		2022		,	Emergency	,	3524		,	32.3
-- 		2023		,	Urgent		,	3667		,	33.5
-- 		2023		,	Emergency	,	3662		,	33.5
-- 		2023		,	Elective	,	3607		,	33
-- 		2024		,	Elective	,	1286		,	33.6
-- 		2024		,	Emergency	,	1278		,	33.4
-- 		2024		,	Urgent		,	1263		,	33

-- The leading admission type shifts randomly each year — Urgent led in 
-- 	2019, Emergency in 2020, Elective in 2021 and 2022, then Urgent again
-- 	in 2023. No consistent pattern or trend exists. In real healthcare data
-- 	the COVID-19 pandemic dramatically reduced elective admissions in 2020
-- 	and 2021 as hospitals cancelled non-urgent procedures — a signal that 
-- 	would be clearly visible in real admission type data but is entirely 
-- 	absent here, further confirming the synthetic nature of the dataset.

-- Data quality check: any records where admission date is after discharge date?
SELECT COUNT(*) AS invalid_date_order
FROM healthcare.health_staging
WHERE `Date of Admission` > `Discharge Date`;

-- Confirmed 0 records where Date of Admission occurs after Discharge Date.
-- 	Date integrity is intact for length-of-stay calculations used throughout 
-- 	this analysis.

SELECT COUNT(*) AS repeat_patients FROM (
    SELECT hs1.first_name, hs1.last_name, hs1.Gender, hs1.`Blood Type`
    FROM healthcare.health_staging AS hs1
    JOIN healthcare.health_staging AS hs2
      ON hs1.first_name = hs2.first_name AND 
         hs1.last_name = hs2.last_name AND
         hs1.Gender = hs2.Gender AND
         hs1.`Blood Type` = hs2.`Blood Type`
    WHERE hs2.`Date of Admission` > hs1.`Discharge Date`
    GROUP BY hs1.first_name, hs1.last_name, hs1.Gender, hs1.`Blood Type`
) AS distinct_repeats;

-- 1080 patients were admitted more than 1 time.

-- ============================================
-- KEY FINDINGS SUMMARY
-- ============================================
-- Dataset covers admissions from May 2019 through May 2024
-- Dataset covers discharges from May 2019 through June 2024
-- Total admission records analyzed: 54,966
-- Approximate unique patients: 39,617 (based on distinct name combinations)
-- Note: 2019 and 2024 are partial years (~8 and ~5 months respectively)
--
-- Top findings:
-- 1. PATIENT DEMOGRAPHICS
--    - Gender split is nearly equal (49.6% male, 50.4% female)
--    - Age distribution is uniform across the 20-79 range (~8,000 per decade)
--      contrasting with real healthcare where elderly patients dominate admissions
--    - Blood type distribution is equally flat (~12.5% per type) vs real US
--      population where O+ is 37.4% and AB- is only 0.6%
--
-- 2. CLINICAL PATTERNS
--    - All six medical conditions show nearly identical admission counts
--      and repeat admission rates (1.15-1.17 per patient)
--    - Medications are randomly assigned with no clinical logic --
--      Penicillin (antibiotic) appears as top medication for Obesity,
--      Ibuprofen (contraindicated) as top for Hypertension
--    - Test results show perfect ~33% distribution across Normal, Abnormal,
--      and Inconclusive regardless of condition, medication, or age group
--    - Mathematical analysis confirms complete independence between medication,
--      test result, and condition (actual counts 641-665 vs expected random
--      count of 611 across 90 possible combinations)
--
-- 3. BILLING AND LENGTH OF STAY
--    - Average billing is flat across all conditions, admission types,
--      insurance providers, and years ($25,438 to $25,859)
--    - No year-over-year billing increase despite real medical inflation
--      of 3-5% annually -- a real 2019-2024 dataset would show 15-25% increase
--    - Average length of stay (~15.5 days) is more than ~2.4x the US national
--      average of 6.3-6.6 days per the American Hospital Association
--    - Length of stay shows no year-over-year decline unlike real healthcare
--      trends driven by outpatient care shifts and insurance pressure
--
-- 4. TIME-BASED PATTERNS
--    - Admissions are flat across all days of the week (7,781-7,913)
--      vs real hospitals where weekends show only 11% elective admissions
--    - No seasonal variation in monthly admissions despite real winter spikes
--      for respiratory conditions
--    - No COVID-19 signal visible in 2020 elective admission data --
--      real hospital data would show dramatic elective admission decline
--      in 2020-2021 due to pandemic procedure cancellations
--    - Condition leadership changes randomly by year with no sustained trends
--
-- 5. DATA QUALITY NOTES
--    QA checks performed during EDA:
--    - Confirmed 0 NULLs across all four name fields (first_name, last_name,
--      dr_first_name, dr_last_name) -- COUNT(DISTINCT) figures throughout
--      this script are unaffected
--    - Confirmed 0 records where Date of Admission occurs after Discharge
--      Date -- date integrity intact for all length-of-stay calculations
--    - Verified doctor cardinality directly via query: 40,341 distinct
--      Doctor values vs 39,677 distinct dr_first_name/dr_last_name pairs,
--      averaging 1.39 patient admissions per doctor
--    - Resolved the Name (40,235) vs first_name/last_name (39,617) patient
--      count discrepancy by identifying real examples of case-collision
--      pairs (e.g. multiple raw Name variants mapping to the same cleaned
--      first_name/last_name, confirming proper-case conversion during
--      cleaning rather than a data loss issue)
--    - Corrected a double-counting bug in the repeat-patient self-join
--      query (revised from 1,507 to 1,080 patients after switching from
--      counting admission pairs to counting distinct patients)
--
--    Issues identified and handled:
--    - 106 negative billing amounts identified during EDA (not caught in
--      the cleaning phase) -- excluded from billing analysis via
--      WHERE Billing Amount >= 0
--    - Hospital column has ~18.7% CSV import corruption and is excluded
--      from analysis entirely
--    - Blood type distribution (~12.5% per type, vs real-world range of
--      0.6%-37%) confirms dataset unsuitable for clinical research
--
-- OVERALL CONCLUSION
-- This synthetic dataset demonstrates consistent random distribution across
-- all variables with no clinical, financial, or temporal modeling applied.
-- While suitable for practicing SQL, data cleaning, and EDA techniques,
-- it should not be used for healthcare predictive modeling, clinical
-- research, insurance analysis, or any real-world healthcare decision making.
-- The Kaggle description correctly identifies this as a practice dataset only.
