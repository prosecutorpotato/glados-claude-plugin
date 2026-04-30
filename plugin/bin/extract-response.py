#!/usr/bin/env python3
"""
extract-response.py - Extract the last assistant message from a transcript file.
Used by speak.sh to get the text that should be spoken.
"""

import json
import os
import sys
import re


def strip_markdown(text):
    """Remove markdown formatting, code blocks, and special characters for cleaner TTS."""
    # Remove code blocks entirely
    text = re.sub(r'```[\s\S]*?```', '', text)
    # Remove inline code
    text = re.sub(r'`[^`]+`', '', text)
    # Remove headers
    text = re.sub(r'^#{1,6}\s+', '', text, flags=re.MULTILINE)
    # Remove bold/italic markers
    text = re.sub(r'\*{1,3}([^*]+)\*{1,3}', r'\1', text)
    text = re.sub(r'_{1,3}([^_]+)_{1,3}', r'\1', text)
    # Remove links, keep text
    text = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text)
    # Remove bullet points
    text = re.sub(r'^\s*[-*+]\s+', '', text, flags=re.MULTILINE)
    # Remove numbered lists prefix
    text = re.sub(r'^\s*\d+\.\s+', '', text, flags=re.MULTILINE)
    # Collapse whitespace
    text = re.sub(r'\n{2,}', '. ', text)
    text = re.sub(r'\n', ' ', text)
    text = re.sub(r'\s{2,}', ' ', text)
    return text.strip()


def extract_last_response(transcript_path):
    """Extract the last assistant message from transcript JSON or JSONL."""
    messages = []

    # Strategy 1: JSONL file (direct path or .history.jsonl companion)
    # Claude Code: each line is {"message": {"role":..., "content":...}, ...}
    # Cortex Code: each line is {"role":..., "content":...} (flat messages)
    jsonl_path = transcript_path
    if not jsonl_path.endswith('.jsonl'):
        jsonl_path = transcript_path.replace('.json', '.history.jsonl')
    if os.path.isfile(jsonl_path):
        try:
            with open(jsonl_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        entry = json.loads(line)
                        if "message" in entry and isinstance(entry["message"], dict):
                            messages.append(entry["message"])
                        elif "role" in entry:
                            messages.append(entry)
        except (json.JSONDecodeError, FileNotFoundError):
            messages = []

    # Strategy 2: JSON transcript file (array of messages or {messages: [...]})
    if not messages and not transcript_path.endswith('.jsonl'):
        try:
            with open(transcript_path, 'r') as f:
                transcript = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return ""

        messages = transcript if isinstance(transcript, list) else transcript.get("messages", [])

    # Find the last assistant message that contains actual text (skip tool_use-only messages)
    last_assistant_text = ""
    for msg in reversed(messages):
        role = msg.get("role", "")
        if role == "assistant":
            content = msg.get("content", "")
            if isinstance(content, list):
                text_parts = []
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif isinstance(block, str):
                        text_parts.append(block)
                candidate = " ".join(text_parts).strip()
                if candidate:
                    last_assistant_text = candidate
                    break
            elif isinstance(content, str) and content.strip():
                last_assistant_text = content
                break

    if not last_assistant_text:
        return ""

    # Clean for TTS
    return strip_markdown(last_assistant_text)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract-response.py <transcript_path>", file=sys.stderr)
        sys.exit(1)

    result = extract_last_response(sys.argv[1])
    print(result)
