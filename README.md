> **Note:** This repository contains GenieLabs skills for Claude Code and Codex. Supported environments vary by skill. For information about the Agent Skills standard, see [agentskills.io](https://agentskills.io).
> 
# genielabs-io Skills

Bridging Education and Innovation.

We believe education is the foundation of innovation. GenieLabs supports students, startups, and communities through AI transformation, software excellence, and practical coding education.

This repository distributes the skills we use to make AX-powered coding workflows more accessible, repeatable, and useful in real learning and building environments.

## Included Skills

| Skill | Purpose | Distribution / environment |
| --- | --- | --- |
| `wrap` | Summarize a session and extract reusable lessons | Claude Code bundle; uses Claude session paths |
| `unicode-guard` | Scan changed files for hidden Unicode characters | Claude Code bundle |
| `find` | Find local files, search indexed document text, and search connected Google Drive | Individual Codex skill; Windows for local search |

## Install Find in Codex

Ask Codex to install only the `skills/find` directory:

```text
$skill-installer Install the skill at skills/find from https://github.com/genielabs-io/skills.
```

After installation, use `$find` on the next turn. Local filename search requires Windows, PowerShell 5.1+, and Everything HTTP. Content search additionally requires Python 3.10+ with SQLite FTS5 and an existing index. Google Drive search is optional and requires a separately connected Google Drive connector. Installing the skill does not install these programs or build an index.

See the [Find setup and usage guide](docs/find.md) for environment checks, indexing, and examples. The skill includes its own [MIT license](skills/find/LICENSE). Codex compatibility of the other skills is not established by this installation.

## Try In Claude Code

### Claude Code

You can register this repository as a Claude Code plugin marketplace by running the following command in Claude Code:

```text
/plugin marketplace add genielabs-io/skills
```

Then install the bundled plugin:

```text
/plugin install genielabs-skills@genielabs-io
```

The Claude Code bundle contains `wrap` and `unicode-guard`. Install `find` separately in Codex using the instructions above.

After installing the plugin, you can use the skills by mentioning them naturally. For example:

```text
Use the unicode-guard skill to scan the staged files for hidden Unicode characters.
Use the wrap skill to summarize this session and extract reusable lessons.
```

## Validate Find

From the repository root, use a Python 3.10+ virtual environment:

```sh
python -m pip install -r skills/find/requirements.txt
python -B -m unittest discover -s tests/find -v
```

Tests use temporary documents and databases and mock Everything responses. Windows CI also exercises PowerShell helpers; other platforms skip Windows-only checks. Live Everything, Google Drive, and optional Tika integration require separate checks.
