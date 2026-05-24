-- Supabase Schema Migration: chat_messages table
-- Purpose: Store AI assistant chat message history for cloud sync across devices
-- Part of: AI Assistant feature for Task Manager app

-- =============================================================================
-- TABLE DEFINITION
-- =============================================================================

CREATE TABLE IF NOT EXISTS chat_messages (
    -- Primary key with auto-generation
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- User ownership (references Supabase auth.users)
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Conversation session identifier
    session_id UUID NOT NULL,

    -- Message role: 'user' (human), 'assistant' (AI), 'system' (configuration)
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),

    -- The actual message content
    content TEXT NOT NULL,

    -- Optional: JSON structure for tool/function calls the assistant made
    tool_calls JSONB,

    -- Optional: JSON structure for results returned from tool executions
    tool_results JSONB,

    -- Timestamp with timezone for ordering and sync reconciliation
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =============================================================================
-- INDEXES
-- =============================================================================

-- Index for fetching a user's messages ordered by time (common query pattern)
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id_created_at
    ON chat_messages (user_id, created_at DESC);

-- Index for fetching messages within a specific session
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id
    ON chat_messages (session_id);

-- =============================================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================================

-- Enable RLS to enforce access control at the database level
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- RLS POLICIES
-- =============================================================================

-- Policy: Users can only access their own chat messages
-- Applies to ALL operations (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY chat_messages_owner ON chat_messages
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- NOTES
-- =============================================================================

-- 1. session_id groups messages into conversations. The app manages session lifecycle.
-- 2. Remote-wins reconciliation: When syncing, remote messages take precedence.
-- 3. tool_calls and tool_results support AI function calling (optional per message).
-- 4. The ON DELETE CASCADE on user_id ensures user data cleanup when account is deleted.

-- =============================================================================
-- AI CONFIG TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    api_base_url TEXT,
    api_key TEXT,
    model_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE ai_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_config_owner ON ai_config
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);