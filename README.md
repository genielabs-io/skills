> **Note:** This repository contains GenieLabs skills for AX-powered coding and learning workflows in Claude Code. For information about the Agent Skills standard, see [agentskills.io](https://agentskills.io).
> 
# genielabs-io Skills

Bridging Education and Innovation.

We believe education is the foundation of innovation. GenieLabs supports students, startups, and communities through AI transformation, software excellence, and practical coding education.

This repository distributes the skills we use to make AX-powered coding workflows more accessible, repeatable, and useful in real learning and building environments.

## Included Skills

- `wrap`: wraps up a session, summarizes changes, and extracts reusable lessons
- `unicode-guard`: scans changed files or a specific path for hidden Unicode characters

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

If you publish separate plugins later, individual skill installs would look like:

```text
/plugin install wrap@genielabs-io
/plugin install unicode-guard@genielabs-io
```

This repository currently ships as a bundled plugin.

After installing the plugin, you can use the skills by mentioning them naturally. For example:

```text
Use the unicode-guard skill to scan the staged files for hidden Unicode characters.
Use the wrap skill to summarize this session and extract reusable lessons.
```
