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
    # Remove markdown tables (keep cell text, drop pipes and header separators)
    text = re.sub(r'^\|?[-:| ]+\|?$', '', text, flags=re.MULTILINE)  # header separator rows
    text = re.sub(r'\|', ' ', text)  # remaining pipes → spaces
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

    # Strategy 1: Try JSONL history file (Cortex Code format)
    # Cortex Code stores messages in .history.jsonl alongside the .json metadata file
    jsonl_path = transcript_path.replace('.json', '.history.jsonl')
    if os.path.isfile(jsonl_path):
        try:
            with open(jsonl_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line:
                        messages.append(json.loads(line))
        except (json.JSONDecodeError, FileNotFoundError):
            messages = []

    # Strategy 2: Fall back to original JSON format (Claude Code format)
    if not messages:
        try:
            with open(transcript_path, 'r') as f:
                transcript = json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return ""

        messages = transcript if isinstance(transcript, list) else transcript.get("messages", [])

    # Find the last assistant message
    last_assistant_text = ""
    for msg in reversed(messages):
        role = msg.get("role", "")
        if role == "assistant":
            # Extract text content
            content = msg.get("content", "")
            if isinstance(content, list):
                # Handle structured content blocks
                text_parts = []
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text_parts.append(block.get("text", ""))
                    elif isinstance(block, str):
                        text_parts.append(block)
                last_assistant_text = " ".join(text_parts)
            elif isinstance(content, str):
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
