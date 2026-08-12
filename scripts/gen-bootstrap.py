#!/usr/bin/env python3

# take a dump file and ask llm to convert it into a bootstrap for a future session to continue

import subprocess
import sys
import os
import re
from pprint import pprint

from session_files import logical_path, materialized_session, resolve_session_path

def main():
    if len(sys.argv) < 2:
        print("Usage: python generate_bootstrap.py <path_to_full_session.json>")
        sys.exit(1)

    json_path = resolve_session_path(os.path.abspath(sys.argv[1]))
    if not json_path.exists():
        print(f"Error: File not found at {json_path}")
        sys.exit(1)

    logical_json_path = logical_path(json_path)
    base_name = logical_json_path.name
    dir_name = str(logical_json_path.parent)
    
    session_id_match = re.search(r"full-(.+)\.json", base_name)
    session_id = session_id_match.group(1) if session_id_match else os.path.splitext(base_name)[0]

    output_filename = f"bootstrap-from-{session_id}.md"
    output_path = os.path.join(dir_name, output_filename)

    # Clean, direct instructions for the attached file
    instruction = (
        "Analyze the attached raw session history JSON file. "
        "Generate a high-density, compact 'Session Handoff Summary' to bootstrap a brand new clean session. "
        "Structure your output exactly using these 4 Markdown headers:\n"
        "1. ## Project Architecture\n"
        "2. ## Current State\n"
        "3. ## Critical Context & Workarounds\n"
        "4. ## Immediate Next Steps\n\n"
        "CRITICAL: Return your final output inside a single standard markdown code block (using ```markdown ... ```). "
        "Do not include any conversational filler."
    )

    print(f"Launching OpenCode pipeline and attaching {base_name}...")

    # Native attachment call using the -f flag
    try:
        with materialized_session(json_path) as attachment_path:
            cmd = ["opencode", "run", instruction,
                   "--file", str(attachment_path),
                   "--model", "openai/gpt-5.5",
                   "--variant", "high"
                   ]
            pprint(cmd)
            with open("/tmp/opencode.errs", "w") as err_log:
                result = subprocess.run(
                    cmd,
                    stdin=subprocess.DEVNULL, # Tell OpenCode it's a headless execution
                    stdout=subprocess.PIPE,
                    stderr=err_log,
                    text=True
                )
        
        response_text = result.stdout

        # Extract markdown block
        markdown_block_match = re.search(r"```markdown\s*(.*?)\s*```", response_text, re.DOTALL)
        bootstrap_content = markdown_block_match.group(1).strip() if markdown_block_match else response_text.strip()

        if not bootstrap_content or "Commands:" in bootstrap_content:
            print("Error: Failed to generate a valid summary block.")
            print("Take a look at /tmp/opencode.errs to inspect output logs.")
            sys.exit(1)

        with open(output_path, "w", encoding="utf-8") as out_f:
            out_f.write(bootstrap_content)

        print(f"\n✨ Success! Native file import complete.")
        print(f"Template saved to: {output_path}")

    except subprocess.CalledProcessError as e:
        print(f"\n❌ Error processing with OpenCode CLI: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
