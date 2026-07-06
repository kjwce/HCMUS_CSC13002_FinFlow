-- Rename transaction title semantics to name while preserving existing data.
ALTER TABLE transactions
ADD COLUMN IF NOT EXISTS name TEXT;

UPDATE transactions
SET name = title
WHERE name IS NULL
  AND title IS NOT NULL;

ALTER TABLE transactions
ALTER COLUMN name SET DEFAULT 'Transaction';

UPDATE transactions
SET name = 'Transaction'
WHERE name IS NULL;

ALTER TABLE transactions
ALTER COLUMN name SET NOT NULL;
