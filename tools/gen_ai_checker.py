"""
Runtime AI writing tell checker for Frosthold procedural content.

Provides two functions:
  check_ai_tells(text) -- returns list of (pattern_name, matched_text, suggestion) warnings
  scrub_ai_tells(text) -- auto-fixes common AI patterns, returns cleaned text

Called on every generated piece before output. See AI_WRITING_TELLS.md for reference.
"""

import re


def check_ai_tells(text):
    """
    Scan generated text for AI writing patterns.
    Returns list of (pattern_name, matched_text, suggestion) tuples.
    Returns empty list if clean.
    """
    warnings = []

    # 1. CONTRASTIVE RHETORICAL FRAMING
    # "isn't just X. It's/They're Y"
    patterns_contrastive = [
        r"isn't just .{5,40}\. (?:It's|They're|She's|He's)",
        r"not just about .{5,30}\. It's about",
        r"aren't just .{5,30}\. (?:They're|We're)",
        r"wasn't just .{5,30}\. (?:It was|She was|He was)",
        r"isn't about .{5,30}\. It's about",
    ]
    for p in patterns_contrastive:
        for m in re.finditer(p, text, re.IGNORECASE):
            warnings.append(("contrastive_framing", m.group(),
                             "Rewrite without 'isn't just...it's' structure"))

    # 2. ASK-AND-ANSWER RHETORICAL QUESTIONS
    # Short question (under 30 chars) followed by short answer (under 40 chars)
    pattern_qa = r'([A-Z][^.!?]{3,25}\?)\s+([A-Z][^.!?]{3,35}\.)'
    for m in re.finditer(pattern_qa, text):
        q = m.group(1)
        a = m.group(2)
        # Only flag if the answer is very short (under 6 words)
        if len(a.split()) <= 6:
            warnings.append(("rhetorical_qa", m.group(),
                             "Don't ask then answer. Just state it."))

    # 3. EM DASHES IN PROSE
    dash_count = len(re.findall(r' -- ', text))
    if dash_count > 2:
        warnings.append(("em_dash_overuse", f"{dash_count} em dashes",
                         "Replace with periods or commas"))

    # 4. TRIPLET FRAMING
    # "Not X. Not Y. Z." or "Not X. Not Y. For Z."
    pattern_triplet = (r'Not (?:for |about )?[^.]{3,30}\. '
                       r'Not (?:for |about )?[^.]{3,30}\. '
                       r'(?:For |But |Just )?[^.]{3,30}\.')
    for m in re.finditer(pattern_triplet, text, re.IGNORECASE):
        warnings.append(("triplet_framing", m.group(),
                         "Break the three-beat pattern"))

    # 5. INSPIRATIONAL PIVOT
    # "This isn't about X. It's about Y." where Y is abstract
    abstract_words = {
        "humanity", "survival", "truth", "hope", "fear", "power", "freedom",
        "identity", "legacy", "connection", "meaning", "purpose",
    }
    pattern_pivot = r"(?:This|It) isn't (?:just )?about .{5,30}\. It's about (\w+)"
    for m in re.finditer(pattern_pivot, text, re.IGNORECASE):
        if m.group(1).lower() in abstract_words:
            warnings.append(("inspirational_pivot", m.group(),
                             "Don't elevate to abstract. Stay specific."))

    # 6. "STATEMENT. IT'S [REFRAME]." (the most pervasive pattern)
    # Two short sentences where second reframes first with "It's"
    pattern_reframe = r'([^.]{10,50})\. It\'s ([^.]{5,30})\.'
    reframe_count = len(re.findall(pattern_reframe, text))
    if reframe_count >= 3:
        warnings.append(("reframe_overuse",
                         f"{reframe_count} instances of '. It's [reframe].'",
                         "Vary sentence structure"))

    # 7. "THAT'S THE WORD" / "THAT'S WHAT THEY CALL IT" confirmation
    pattern_confirm = r"That's (?:the word|what they (?:call|say|told|use))"
    for m in re.finditer(pattern_confirm, text, re.IGNORECASE):
        warnings.append(("confirmation_pattern", m.group(),
                         "Don't confirm your own statement"))

    # 8. EXCESSIVE "NOT" FRAGMENTS
    # "Not anymore." "Not here." "Not yet." used as dramatic beats
    not_fragments = re.findall(r'\. Not [a-z]{2,15}\.', text)
    if len(not_fragments) >= 3:
        warnings.append(("not_fragments",
                         f"{len(not_fragments)} 'Not X.' fragments",
                         "Reduce dramatic not-fragments"))

    # 9. EXCESSIVE SENTENCE-INITIAL "THE"
    sentences = re.findall(r'(?:^|\. )The [A-Z]?', text)
    total_sentences = len(re.findall(r'[.!?]\s+[A-Z]', text)) + 1
    if total_sentences > 5 and len(sentences) / total_sentences > 0.5:
        warnings.append(("the_opening",
                         f"{len(sentences)}/{total_sentences} sentences start with 'The'",
                         "Vary sentence openings"))

    # 10. ANTHROPOMORPHIZING OBJECTS (that aren't alive in lore)
    # "The artifact decided" "The building remembered" "The door refused"
    # Only flags volitional/emotional verbs, NOT physical state ("was", "seemed")
    # because "the corridor was narrow" and "the wall was cracked" are fine.
    inanimate_actions = [
        (r"(?:artifact|equipment|machine|tool|door|wall|building|corridor|room) "
         r"(?:decided |remembered |refused |wanted |chose |wished |hoped |feared )"),
    ]
    for p in inanimate_actions:
        for m in re.finditer(p, text, re.IGNORECASE):
            # Don't flag if it's clearly about Erebus (alive entity) or precursor tech
            start = max(0, m.start() - 50)
            end = m.end() + 50
            context = text[start:end]
            lore_exceptions = ["erebus", "precursor", "entity", "alive", "xenolith"]
            if not any(w in context.lower() for w in lore_exceptions):
                warnings.append(("anthropomorphizing", m.group(),
                                 "Objects don't have feelings unless lore says they're alive"))

    # 11. SYNONYM CYCLING
    # Same concept described with different fancy words in close proximity
    synonym_groups = [
        ["important", "crucial", "vital", "essential", "critical", "pivotal", "paramount"],
        ["demonstrate", "illustrate", "showcase", "highlight", "underscore"],
        ["comprehensive", "thorough", "extensive", "exhaustive"],
        ["enhance", "improve", "boost", "elevate", "augment"],
    ]
    for group in synonym_groups:
        found = [w for w in group if w.lower() in text.lower()]
        if len(found) >= 3:
            warnings.append(("synonym_cycling", f"Uses {', '.join(found)} in same piece", "Pick one word and use it. Humans repeat."))

    # 12. SIGNPOSTING
    signposts = ["firstly", "secondly", "thirdly", "in conclusion", "to summarize", "in summary", "it is important to note"]
    for s in signposts:
        if s.lower() in text.lower():
            warnings.append(("signposting", s, "Cut the signpost. Just say it."))

    # 13. SYMMETRICAL STRUCTURE
    # Check if bullet points or list items are suspiciously similar length
    lines = text.split('\n')
    bullet_lines = [l.strip() for l in lines if l.strip().startswith('- ')]
    if len(bullet_lines) >= 3:
        lengths = [len(l) for l in bullet_lines]
        avg_len = sum(lengths) / len(lengths)
        # If all bullets are within 20% of average length, flag
        if all(abs(l - avg_len) / avg_len < 0.2 for l in lengths if avg_len > 0):
            warnings.append(("symmetrical_structure", f"{len(bullet_lines)} bullets, all ~{int(avg_len)} chars", "Vary bullet lengths. Humans are messy."))

    # 14. FORCED CASUAL
    forced_casual = ["honestly,", "to be fair,", "at the end of the day,", "let's be honest,", "look,", "here's the thing,"]
    for fc in forced_casual:
        if fc.lower() in text.lower():
            warnings.append(("forced_casual", fc, "Cut the forced casualness"))

    # 15. LOOPING CONCLUSION
    # Same idea stated more than once in different words (harder to detect)
    # Simple heuristic: check if last sentence restates the first
    sentences = [s.strip() for s in re.split(r'[.!?]+', text) if s.strip() and len(s.strip()) > 10]
    if len(sentences) >= 4:
        first_words = set(sentences[0].lower().split()[:5])
        last_words = set(sentences[-1].lower().split()[:5])
        overlap = len(first_words & last_words)
        if overlap >= 3:
            warnings.append(("looping_conclusion", "Last sentence restates first", "Don't circle back. Move forward."))

    return warnings


def scrub_ai_tells(text):
    """
    Automatically fix common AI patterns in generated text.
    Called on every piece before output.
    """
    # Fix contrastive framing: "isn't just X. It's Y" -> merge into one sentence
    text = re.sub(
        r"isn't just (.{5,40})\. (?:It's|They're) (.{5,40}\.)",
        lambda m: f"is {m.group(2)}",
        text, flags=re.IGNORECASE,
    )

    # Fix ask-and-answer: "What changed? The math did." -> just the answer
    # Only fix obvious short Q&A pairs
    def _fix_qa(m):
        a = m.group(2).rstrip('.')
        # If answer is very short, just use the answer
        if len(a.split()) <= 4:
            return a + '.'
        return m.group(0)  # leave longer ones alone
    text = re.sub(r'([A-Z][^.!?]{3,20}\?)\s+([A-Z][^.!?]{3,25}\.)', _fix_qa, text)

    # Fix "That's the word they use" confirmation
    text = re.sub(r"\. That's the word they use\.", ".", text)
    text = re.sub(r"\. That's what they call it\.", ".", text)
    text = re.sub(r"\. That's what they say\.", ".", text)

    # Auto-remove signposts
    for s in ["Firstly, ", "Secondly, ", "Thirdly, ", "In conclusion, ", "To summarize, ", "In summary, ", "It is important to note that "]:
        text = text.replace(s, "")
        text = text.replace(s.lower(), "")

    # Auto-remove forced casual
    for fc in ["Honestly, ", "To be fair, ", "At the end of the day, ", "Let's be honest, ", "Here's the thing, "]:
        text = text.replace(fc, "")

    return text
