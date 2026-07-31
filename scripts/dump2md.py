#!/usr/bin/env python3

# convert a json dump file from opencode into a markdown file with just the user questions and model outputs.

import sys
import json
from datetime import datetime

def format_timestamp(ts_value):
    """Converts unix timestamp in milliseconds to mm/dd/yy hh:mm."""
    if not ts_value:
        return "N/A"
    try:
        dt = datetime.fromtimestamp(float(ts_value) / 1000)
        return dt.strftime("%m/%d/%y %H:%M")
    except Exception:
        return str(ts_value)

def parse_opencode_dump(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    info = data.get("info", {})
    
    # 1. Extract Top Header Metadata
    session_id = info.get("id", "Unknown ID")
    
    model_obj = info.get("model", {})
    model_name = model_obj.get("id", "Unknown Model") if isinstance(model_obj, dict) else str(model_obj)
    
    time_obj = info.get("time", {})
    created_raw = time_obj.get("created")
    created_time = format_timestamp(created_raw)
    
    directory = info.get("directory", "Unknown Directory")
    title = info.get("title", "OpenCode Session")
    
    # Generate Header Block
    md_lines = [
        f"# {title}\n",
        f"- {session_id}",
        f"- {model_name}",
        f"- {created_time}",
        f"- {directory}\n"
    ]
    
    # 2. Extract Conversation Lines
    messages = data.get("messages", [])
    
    for message in messages:
        msg_info = message.get("info", {})
        role = msg_info.get("role")
        
        msg_time_obj = msg_info.get("time", {})
        msg_time_raw = msg_time_obj.get("created")
        msg_time = format_timestamp(msg_time_raw)
        
        # Only parse parts where type is "text"
        parts = message.get("parts", [])
        text_parts = [part.get("text", "") for part in parts if part.get("type") == "text"]
        combined_text = "\n\n".join(p.strip() for p in text_parts if p.strip())
        
        if not combined_text:
            continue
            
        if role == "user":
            md_lines.append(f"## User <{msg_time}>\n")
            md_lines.append(f"{combined_text}\n")
        elif role == "assistant":
            md_lines.append(f"## Output <{msg_time}>\n")
            md_lines.append(f"{combined_text}\n")
            
    return "\n".join(md_lines)

if __name__ == "__main__":
    # Ensure exactly one argument (the file path) is passed
    if len(sys.argv) != 2:
        print(f"Usage: python {sys.argv[0]} <path_to_session_json>", file=sys.stderr)
        sys.exit(1)
        
    input_file = sys.argv[1]
    
    try:
        markdown_content = parse_opencode_dump(input_file)
        sys.stdout.write(markdown_content + "\n")
    except Exception as e:
        print(f"Error parsing file: {e}", file=sys.stderr)
        sys.exit(1)
