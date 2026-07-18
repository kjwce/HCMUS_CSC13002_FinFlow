ALTER TABLE chat_messages
  ADD COLUMN IF NOT EXISTS sequence_number BIGINT;

WITH ranked_messages AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY conversation_id
      ORDER BY
        created_at ASC,
        CASE role WHEN 'user' THEN 0 ELSE 1 END ASC,
        id ASC
    ) AS position
  FROM chat_messages
)
UPDATE chat_messages AS message
SET sequence_number = ranked.position
FROM ranked_messages AS ranked
WHERE message.id = ranked.id
  AND message.sequence_number IS NULL;

ALTER TABLE chat_messages
  ALTER COLUMN sequence_number SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_messages_conversation_sequence
  ON chat_messages(conversation_id, sequence_number ASC);

CREATE OR REPLACE FUNCTION assign_chat_message_sequence()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Serialize inserts within one conversation so concurrent requests cannot
  -- receive the same sequence number.
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW.conversation_id::text, 0));

  SELECT COALESCE(MAX(message.sequence_number), 0) + 1
  INTO NEW.sequence_number
  FROM chat_messages AS message
  WHERE message.conversation_id = NEW.conversation_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_message_assign_sequence ON chat_messages;
CREATE TRIGGER chat_message_assign_sequence
BEFORE INSERT ON chat_messages
FOR EACH ROW EXECUTE FUNCTION assign_chat_message_sequence();
