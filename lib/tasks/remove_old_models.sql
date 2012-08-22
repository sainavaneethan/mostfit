--this script will delete old model from database which have been deleted from application--

DELETE * FROM `regions`;
DROP TABLE `regions`;
DELETE * FROM `areas`;
DROP TABLE `areas`;
DELETE * FROM `branches`;
DROP TABLE `branches`;
DELETE * FROM `centers`;
DROP TABLE `centers`;
DELETE * FROM `loans`;
DROP TABLE `loans`;
DELETE * FROM `cachers`;
DROP TABLE `cachers`;
DELETE * FROM `rule_books`;
DROP TABLE `rule_books`;
DELETE * FROM `targets`;
DROP TABLE `targets`;
DELETE * FROM `loan_history`;
DROP TABLE `loan_history`;
DELETE * FROM `fees`;
DROP TABLE `fees`;
DELETE * FROM `applicable_fees`;
DROP TABLE `applicable_fees`;
DELETE * FROM `center_meeting_days`;
DROP TABLE `center_meeting_days`;
DELETE * FROM `loan_products`;
DROP TABLE `loan_products`;
DELETE * FROM `credit_account_rules`;
DROP TABLE `credit_account_rules`;
DELETE * FROM `debit_account_rules`;
DROP TABLE `debit_account_rules`;
ALTER TABLE `accruals` DROP COLUMN `loan_id`;
ALTER TABLE `api_accesses` DROP COLUMN `branch_id`;
ALTER TABLE `attendances` DROP COLUMN `center_id`;
ALTER TABLE `checkers` DROP COLUMN `loan_id`;
ALTER TABLE `client_groups` DROP COLUMN `center_id`;
ALTER TABLE `insurance_policies` DROP COLUMN `loan_id`;
ALTER TABLE `postings` DROP COLUMN `fee_id`;
ALTER TABLE `stock_registers` DROP COLUMN `branch_name`;
ALTER TABLE `stock_registers` DROP COLUMN `branch_id`;
DELETE * FROM `transaction_summaries`;
DROP TABLE `transaction_summaries`;