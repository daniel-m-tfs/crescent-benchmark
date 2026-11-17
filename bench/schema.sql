-- Recreated before every app run: same data for everyone.
CREATE DATABASE IF NOT EXISTS crescent_bench CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE crescent_bench;
DROP TABLE IF EXISTS bench_items;
CREATE TABLE bench_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    value INT NOT NULL
) ENGINE=InnoDB;
INSERT INTO bench_items (name, value)
WITH RECURSIVE seq (n) AS (SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 1000)
SELECT CONCAT('item-', n), n * 7 % 1000 FROM seq;
