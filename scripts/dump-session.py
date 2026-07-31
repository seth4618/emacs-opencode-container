#!/usr/bin/env python3

# Do a complete dump of a session to a json file
# ask user for the session to dump

import subprocess
import json
import sys
import os
from datetime import datetime

def run_command(cmd):
    """Helper function to run a shell command and return stdout."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error running command {' '.join(cmd)}: {e.stderr}", file=sys.stderr)
        sys.exit(1)

def parse_unix_timestamp(ts_val):
    """Parses a Unix millisecond timestamp into a datetime object."""
    if ts_val is None or ts_val == 'N/A':
        return None
    try:
        # If it's passed as a string representation of a number, convert it
        ts_float = float(ts_val)
        # Convert milliseconds to seconds if the timestamp is character-length 13ish
        if ts_float > 9999999999:
            ts_float /= 1000.0
        return datetime.fromtimestamp(ts_float)
    except (ValueError, TypeError):
        return None

def format_created(dt):
    """Formats datetime object to mm/dd/yy hh:mm (24 hour time)."""
    if not dt:
        return 'N/A'
    return dt.strftime("%m/%d/%y %H:%M")

def format_relative_time(dt):
    """Calculates relative 'time ago' for whichever shortest unit is relevant."""
    if not dt:
        return 'N/A'
    
    diff = datetime.now() - dt
    seconds = diff.total_seconds()
    
    if seconds < 0:
        return "just now"
    
    days = diff.days
    hours, remainder = divmod(diff.seconds, 3600)
    minutes, secs = divmod(remainder, 60)

    if days > 0:
        return f"{days} day{'s' if days > 1 else ''} ago"
    elif hours > 0:
        return f"{hours} hour{'s' if hours > 1 else ''} ago"
    elif minutes > 0:
        return f"{minutes} minute{'s' if minutes > 1 else ''} ago"
    else:
        int_secs = int(secs)
        return f"{int_secs} second{'s' if int_secs != 1 else ''} ago"

def main():
    print("Fetching sessions from opencode...")
    # 1. Fetch the session list in JSON format
    cmd_list = ["opencode", "session", "list", "--format", "json"]
    raw_json = run_command(cmd_list)
    
    try:
        sessions = json.loads(raw_json)
    except json.JSONDecodeError:
        print("Failed to parse JSON output from opencode.", file=sys.stderr)
        print(raw_json)
        sys.exit(1)
        
    if not sessions:
        print("No sessions found.")
        return

    # 2. Pre-parse and Sort sessions from oldest to newest.
    for s in sessions:
        s['_parsed_created'] = parse_unix_timestamp(s.get('created_at', s.get('created', 'N/A')))
        s['_parsed_updated'] = parse_unix_timestamp(s.get('updated_at', s.get('updated', 'N/A')))

    try:
        # Sort based on the parsed datetimes
        sessions.sort(key=lambda x: x['_parsed_created'] if x['_parsed_created'] else 0)
    except Exception:
        pass

    # 3. List sessions out to stdout with requested formatting
    print("\nAvailable Sessions (Oldest to Newest):")
    print(f"{'No.':<5} | {'Created':<15} | {'Updated':<15} | Title")
    print("-" * 85)
    
    for idx, session in enumerate(sessions, start=1):
        title = session.get('title', 'Untitled Session')
        
        created_formatted = format_created(session['_parsed_created'])
        updated_formatted = format_relative_time(session['_parsed_updated'])
        
        print(f"{idx:<5} | {created_formatted:<15} | {updated_formatted:<15} | {title}")

    print("-" * 85)

    # 4. Prompt the user for a selection
    try:
        user_input = input("\nEnter the number of the session to dump (or anything else to exit): ").strip()
        if not user_input.isdigit():
            print("Exiting.")
            sys.exit(0)
            
        choice = int(user_input)
        if choice < 1 or choice > len(sessions):
            print("Invalid selection. Exiting.")
            sys.exit(0)
    except (KeyboardInterrupt, EOFError):
        print("\nExiting.")
        sys.exit(0)

    # Get the chosen session data
    selected_session = sessions[choice - 1]
    session_id = selected_session.get('id', selected_session.get('session_id'))
    
    if not session_id:
        print("Error: Could not extract a valid session ID for the selected item.", file=sys.stderr)
        sys.exit(1)

    # 5. Export the selected session bypassing the 64KB pipe buffer limit
    filename = f"full-{session_id}.json"
    print(f"Exporting session {session_id} to {filename}...")
    
    cmd_export = ["opencode", "export", session_id]
    
    try:
        with open(filename, "w", encoding="utf-8") as f:
            subprocess.run(cmd_export, stdout=f, check=True)
        print(f"Success! Full session saved to {os.path.abspath(filename)}")
    except (subprocess.CalledProcessError, IOError) as e:
        print(f"Failed to export full session: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
