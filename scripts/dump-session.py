#!/usr/bin/env python3

# Dump full opencode sessions and compare them to prior saved dumps.

import argparse
import subprocess
import json
import sys
from datetime import datetime
from pathlib import Path

from session_files import compress_if_large, logical_path, open_session_text, session_dump_paths


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


def get_repo_root():
    """Returns the git repository root for this workspace."""
    return Path(run_command(["git", "rev-parse", "--show-toplevel"]).strip())


def parse_args(default_sessions_dir):
    """Parses CLI arguments for the dump utility.

    Args:
        default_sessions_dir: Default directory used to discover and save session dumps.

    Returns:
        The parsed argparse namespace.
    """
    parser = argparse.ArgumentParser(
        description="List opencode sessions, show saved dump status, and export a full session dump."
    )
    parser.add_argument(
        "--sessions-dir",
        default=str(default_sessions_dir),
        help="Directory containing full-*.json session dumps and where new dumps are written.",
    )
    parser.add_argument(
        "--list-dumps",
        action="store_true",
        help="List saved full-*.json session dumps from the sessions directory and exit.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Dump every live session whose saved dump status is never or old.",
    )
    parser.add_argument(
        "--dump",
        metavar="SHORT_ID",
        help="Dump the live session whose displayed short id matches SHORT_ID.",
    )
    return parser.parse_args()


def get_session_id(session):
    """Extracts the canonical session id from a live session entry."""
    return session.get('id', session.get('session_id'))


def short_session_id(session_id):
    """Returns the last 8 characters of a session id for compact display."""
    if not session_id:
        return 'N/A'
    return session_id[-8:]


def load_dump_metadata(sessions_dir):
    """Loads saved dump metadata from full session export files.

    Args:
        sessions_dir: Directory that may contain full-*.json dump files.

    Returns:
        A tuple of:
        - list of parsed dump metadata dictionaries for display
        - dict keyed by full session id for status comparison
    """
    dumps = []
    dumps_by_id = {}

    if not sessions_dir.exists():
        return dumps, dumps_by_id

    for dump_path in session_dump_paths(sessions_dir):
        try:
            with open_session_text(dump_path) as handle:
                payload = json.load(handle)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"Warning: Skipping unreadable dump {dump_path}: {exc}", file=sys.stderr)
            continue

        info = payload.get("info", {})
        time_info = info.get("time", {})
        session_id = info.get("id")

        if not session_id:
            # Fall back to the filename when the payload is missing an id.
            session_id = logical_path(dump_path).stem.removeprefix("full-")

        dump = {
            "id": session_id,
            "title": info.get("title", "Untitled Session"),
            "created": parse_unix_timestamp(time_info.get("created")),
            "updated": parse_unix_timestamp(time_info.get("updated")),
        }
        dumps.append(dump)
        dumps_by_id[session_id] = dump

    dumps.sort(key=lambda dump: dump["created"] if dump["created"] else datetime.min)
    return dumps, dumps_by_id


def print_dump_table(dumps, sessions_dir, live_session_ids=None):
    """Prints an informational table of previously saved session dumps.

    Args:
        dumps: Parsed dump metadata entries for display.
        sessions_dir: Directory containing the saved dumps.
        live_session_ids: Optional set of live session ids used to label dumps as live or orphaned.
    """
    print(f"\nSaved Session Dumps ({sessions_dir}):")

    if not dumps:
        print("No existing dumped sessions found.")
        return

    if live_session_ids is None:
        print(f"{'Created':<15} | {'Saved':<15} | {'Short ID':<8} | Title")
        print("-" * 90)
    else:
        print(f"{'Created':<15} | {'Saved':<15} | {'Short ID':<8} | {'State':<8} | Title")
        print("-" * 101)

    for dump in dumps:
        if live_session_ids is None:
            print(
                f"{format_created(dump['created']):<15} | "
                f"{format_created(dump['updated']):<15} | "
                f"{short_session_id(dump['id']):<8} | "
                f"{dump['title']}"
            )
        else:
            state = 'live' if dump['id'] in live_session_ids else 'orphaned'
            print(
                f"{format_created(dump['created']):<15} | "
                f"{format_created(dump['updated']):<15} | "
                f"{short_session_id(dump['id']):<8} | "
                f"{state:<8} | "
                f"{dump['title']}"
            )

    if live_session_ids is None:
        print("-" * 90)
    else:
        print("-" * 101)


def get_dump_status(session, dumps_by_id):
    """Computes whether a live session has never, stale, or current saved dump data.

    Args:
        session: Live session entry returned by opencode.
        dumps_by_id: Parsed dump metadata keyed by session id.

    Returns:
        One of: never, old, current.
    """
    session_id = get_session_id(session)
    if not session_id:
        return 'never'

    dump = dumps_by_id.get(session_id)
    if not dump:
        return 'never'

    live_updated = session.get('_parsed_updated')
    dump_updated = dump.get('updated')

    if not live_updated or not dump_updated:
        return 'old'

    if live_updated > dump_updated:
        return 'old'

    return 'current'


def export_session(session_id, sessions_dir):
    """Exports a single live session into the configured sessions directory.

    Args:
        session_id: Full opencode session id to export.
        sessions_dir: Directory where the full session dump should be written.
    """
    filename = sessions_dir / f"full-{session_id}.json"
    print(f"Exporting session {session_id} to {filename}...")

    cmd_export = ["opencode", "export", session_id]

    try:
        sessions_dir.mkdir(parents=True, exist_ok=True)
        with filename.open("w", encoding="utf-8") as handle:
            subprocess.run(cmd_export, stdout=handle, check=True)
        saved_path = compress_if_large(filename)
        print(f"Success! Full session saved to {saved_path}")
    except (subprocess.CalledProcessError, IOError) as exc:
        print(f"Failed to export full session {session_id}: {exc}", file=sys.stderr)
        sys.exit(1)


def find_sessions_by_short_id(sessions, requested_short_id):
    """Finds live sessions whose displayed short id matches the requested value.

    Args:
        sessions: Live session entries returned by opencode.
        requested_short_id: The short id string provided by the user.

    Returns:
        A list of matching live session entries.
    """
    return [
        session for session in sessions
        if short_session_id(get_session_id(session)) == requested_short_id
    ]


def handle_dump_all(sessions, dumps_by_id, sessions_dir):
    """Exports every live session whose saved dump is missing or stale.

    Args:
        sessions: Live session entries returned by opencode.
        dumps_by_id: Parsed dump metadata keyed by session id.
        sessions_dir: Directory where exported sessions should be written.
    """
    sessions_to_dump = [
        session for session in sessions
        if get_dump_status(session, dumps_by_id) != 'current'
    ]

    if not sessions_to_dump:
        print("All sessions are already current.")
        return

    for session in sessions_to_dump:
        session_id = get_session_id(session)
        if not session_id:
            print("Warning: Skipping session with no id.", file=sys.stderr)
            continue
        export_session(session_id, sessions_dir)


def handle_dump_short_id(sessions, requested_short_id, sessions_dir):
    """Exports a single live session selected by displayed short id.

    Args:
        sessions: Live session entries returned by opencode.
        requested_short_id: The short id string provided by the user.
        sessions_dir: Directory where the exported session should be written.
    """
    matches = find_sessions_by_short_id(sessions, requested_short_id)

    if not matches:
        print(f"No live session matched short id {requested_short_id}.", file=sys.stderr)
        sys.exit(1)

    if len(matches) > 1:
        print(f"Short id {requested_short_id} matched multiple live sessions:", file=sys.stderr)
        for session in matches:
            print(
                f"- {get_session_id(session)} | {session.get('title', 'Untitled Session')}",
                file=sys.stderr,
            )
        sys.exit(1)

    session_id = get_session_id(matches[0])
    if not session_id:
        print("Error: Could not extract a valid session ID for the selected item.", file=sys.stderr)
        sys.exit(1)

    export_session(session_id, sessions_dir)

def main():
    repo_root = get_repo_root()
    args = parse_args(repo_root / "sessions")
    sessions_dir = Path(args.sessions_dir).expanduser().resolve()

    dumps, dumps_by_id = load_dump_metadata(sessions_dir)
    if args.list_dumps:
        print_dump_table(dumps, sessions_dir)
        return

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
        
    # 2. Show existing dumps before listing live sessions.
    live_session_ids = {get_session_id(session) for session in sessions if get_session_id(session)}
    print_dump_table(dumps, sessions_dir, live_session_ids)

    if not sessions:
        print("\nNo sessions found.")
        return

    # 3. Pre-parse and Sort sessions from oldest to newest.
    for s in sessions:
        s['_parsed_created'] = parse_unix_timestamp(s.get('created_at', s.get('created', 'N/A')))
        s['_parsed_updated'] = parse_unix_timestamp(s.get('updated_at', s.get('updated', 'N/A')))

    try:
        # Sort based on the parsed datetimes
        sessions.sort(key=lambda x: x['_parsed_created'] if x['_parsed_created'] else 0)
    except Exception:
        pass

    print("\nAvailable Sessions (Oldest to Newest):")
    print(f"{'No.':<5} | {'Created':<15} | {'Updated':<15} | {'Status':<7} | Title")
    print("-" * 100)
    
    for idx, session in enumerate(sessions, start=1):
        title = session.get('title', 'Untitled Session')
        created_formatted = format_created(session['_parsed_created'])
        updated_formatted = format_relative_time(session['_parsed_updated'])
        status = get_dump_status(session, dumps_by_id)
        
        print(f"{idx:<5} | {created_formatted:<15} | {updated_formatted:<15} | {status:<7} | {title}")

    print("-" * 100)

    if args.dump:
        handle_dump_short_id(sessions, args.dump, sessions_dir)
        return

    if args.all:
        handle_dump_all(sessions, dumps_by_id, sessions_dir)
        return

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
    session_id = get_session_id(selected_session)
    
    if not session_id:
        print("Error: Could not extract a valid session ID for the selected item.", file=sys.stderr)
        sys.exit(1)

    # 5. Export the selected session bypassing the 64KB pipe buffer limit.
    export_session(session_id, sessions_dir)

if __name__ == "__main__":
    main()
