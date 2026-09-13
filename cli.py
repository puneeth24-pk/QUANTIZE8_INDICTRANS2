"""
KAIROS — Offline AI Translation Engine
Terminal UI (cli.py)

Production-grade Rich-based CLI. Wraps the existing kairos_loader.py
(INT8 IndicTrans2) without modifying any model-loading or inference logic.
"""

import time
import sys

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.align import Align
from rich.text import Text
from rich.rule import Rule
from rich.padding import Padding
from rich.prompt import Prompt, IntPrompt
from rich.status import Status
from rich.columns import Columns
from rich.box import ROUNDED, SIMPLE

from kairos_loader import load_int8_model, translate


# --------------------------------------------------------------------------
# Theme
# --------------------------------------------------------------------------

BLUE = "bold rgb(66,133,244)"
MAGENTA = "bold rgb(186,104,200)"
GREEN = "bold rgb(76,175,80)"
PINK = "bold rgb(240,98,146)"
YELLOW = "bold rgb(255,202,58)"
CYAN = "bold rgb(38,198,218)"
DIM = "dim rgb(160,160,160)"
WHITE = "rgb(240,240,240)"

console = Console(highlight=False)

LINKEDIN_URL = "https://www.linkedin.com/in/puneeth-kumar-mandla-a03525326"

LANGUAGES = [
    ("English", "eng_Latn"),
    ("Assamese", "asm_Beng"),
    ("Bengali", "ben_Beng"),
    ("Bodo", "brx_Deva"),
    ("Dogri", "doi_Deva"),
    ("Goan Konkani", "gom_Deva"),
    ("Gujarati", "guj_Gujr"),
    ("Hindi", "hin_Deva"),
    ("Kannada", "kan_Knda"),
    ("Kashmiri (Arabic)", "kas_Arab"),
    ("Kashmiri (Devanagari)", "kas_Deva"),
    ("Maithili", "mai_Deva"),
    ("Malayalam", "mal_Mlym"),
    ("Marathi", "mar_Deva"),
    ("Manipuri (Bengali)", "mni_Beng"),
    ("Manipuri (Meitei)", "mni_Mtei"),
    ("Nepali", "npi_Deva"),
    ("Odia", "ory_Orya"),
    ("Punjabi", "pan_Guru"),
    ("Sanskrit", "san_Deva"),
    ("Santali", "sat_Olck"),
    ("Sindhi (Arabic)", "snd_Arab"),
    ("Sindhi (Devanagari)", "snd_Deva"),
    ("Tamil", "tam_Taml"),
    ("Telugu", "tel_Telu"),
    ("Urdu", "urd_Arab"),
]

# Big block-letter KAIROS banner (blue, bold, centered as a single unit).
KAIROS_BANNER = "\n".join([
    "██╗  ██╗ █████╗ ██╗██████╗  ██████╗ ███████╗",
    "██║ ██╔╝██╔══██╗██║██╔══██╗██╔═══██╗██╔════╝",
    "█████╔╝ ███████║██║██████╔╝██║   ██║███████╗",
    "██╔═██╗ ██╔══██║██║██╔══██╗██║   ██║╚════██║",
    "██║  ██╗██║  ██║██║██║  ██║╚██████╔╝███████║",
    "╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝",
])


# --------------------------------------------------------------------------
# Screens / rendering
# --------------------------------------------------------------------------

def clear():
    console.clear()


def print_startup():
    clear()
    console.print()
    console.print()

    # KAIROS — the dominant visual element
    title = Text(KAIROS_BANNER, style=BLUE)
    console.print(Align.center(title))
    console.print()

    subtitle = Text("IndicTrans2", style=MAGENTA, justify="center")
    console.print(Align.center(subtitle))

    version = Text("v1.0.0", style=DIM, justify="center")
    console.print(Align.center(version))

    powered = Text("Powered By PUNEETH@FDE", style=DIM, justify="center")
    console.print(Align.center(powered))

    console.print()
    console.print(Align.center(Rule(style=DIM)))
    console.print()

    tagline = Text("OFFLINE TRANSLATION ENGINE", style=f"{CYAN}", justify="center")
    console.print(Align.center(tagline))

    badge = Text("INT8 • CPU INFERENCE", style=DIM, justify="center")
    console.print(Align.center(badge))

    console.print()
    console.print()


def print_footer():
    console.print()
    console.print(Align.center(Rule(style=DIM)))
    line1 = Text("OFFLINE • PRIVATE • INT8", style=DIM, justify="center")
    console.print(Align.center(line1))
    console.print()

    li_text = Text("LinkedIn: ", style=DIM)
    li_link = Text(LINKEDIN_URL, style=f"{DIM} underline")
    li_link.stylize(f"link {LINKEDIN_URL}")
    combined = Text.assemble(li_text, li_link)
    console.print(Align.center(combined))

    console.print(Align.center(Text("Powered By PUNEETH@FDE", style=DIM)))
    console.print()


def build_language_table(highlight_style: str) -> Table:
    half = (len(LANGUAGES) + 1) // 2
    left_col = LANGUAGES[:half]

    max_rows = half

    table2 = Table(
        box=SIMPLE,
        show_header=True,
        header_style=highlight_style,
        pad_edge=False,
        expand=True,
    )
    table2.add_column("#", justify="right", style=DIM, width=4)
    table2.add_column("Language", style=WHITE, ratio=2)
    table2.add_column("Code", style=DIM, ratio=1)
    table2.add_column("#", justify="right", style=DIM, width=4)
    table2.add_column("Language", style=WHITE, ratio=2)
    table2.add_column("Code", style=DIM, ratio=1)

    for i in range(max_rows):
        li = i
        ri = i + half
        left = left_col[i] if i < len(left_col) else None
        right = LANGUAGES[ri] if ri < len(LANGUAGES) else None

        l_idx = str(li + 1) if left else ""
        l_name = left[0] if left else ""
        l_code = left[1] if left else ""

        r_idx = str(ri + 1) if right else ""
        r_name = right[0] if right else ""
        r_code = right[1] if right else ""

        table2.add_row(l_idx, l_name, l_code, r_idx, r_name, r_code)

    return table2


def select_language(role: str, style: str, exclude_code: str = None) -> tuple:
    """
    role: 'SOURCE' or 'DESTINATION'
    style: color style for the panel/heading
    exclude_code: optionally disallow picking the same code as source
    """
    console.print()
    heading = Text(f"SELECT {role} LANGUAGE", style=style)
    console.print(Align.center(heading))
    console.print()

    table = build_language_table(style)
    console.print(Panel(table, border_style=style, box=ROUNDED, padding=(1, 2)))
    console.print()

    while True:
        choice = Prompt.ask(
            Text(f"Enter {role.title()} language number or code", style=style).plain,
        )
        choice = choice.strip()

        selected = None
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(LANGUAGES):
                selected = LANGUAGES[idx]
        else:
            for name, code in LANGUAGES:
                if choice.lower() == code.lower() or choice.lower() == name.lower():
                    selected = (name, code)
                    break

        if selected is None:
            console.print(Text("  Invalid selection. Please choose a valid number or code.", style="bold red"))
            continue

        if exclude_code and selected[1] == exclude_code:
            console.print(Text("  Destination language must differ from source.", style="bold red"))
            continue

        return selected


def print_selection_summary(src, tgt):
    table = Table(box=None, show_header=False, pad_edge=False, expand=False)
    table.add_column(justify="left", style="bold")
    table.add_column(justify="left")

    table.add_row(Text("SOURCE", style=GREEN), Text(f"{src[0]}  ({src[1]})", style=WHITE))
    table.add_row(Text("DESTINATION", style=PINK), Text(f"{tgt[0]}  ({tgt[1]})", style=WHITE))

    console.print()
    console.print(Align.center(table))
    console.print()


def get_input_text() -> str:
    console.print(Rule(style=DIM))
    console.print()
    prompt_label = Text("Enter text:", style=YELLOW)
    console.print(prompt_label)
    text = Prompt.ask(Text("›", style=YELLOW).plain)
    console.print()
    return text


def run_translation(model, tokenizer, processor, text, src_code, tgt_code):
    console.print()
    with console.status(Text("TRANSLATING...", style=CYAN).plain, spinner="dots", spinner_style=CYAN):
        start = time.perf_counter()
        result = translate(model, tokenizer, processor, text, src_code, tgt_code)
        elapsed = time.perf_counter() - start
    return result, elapsed


def print_output(result: str, elapsed: float):
    console.print()
    console.print(Rule(style=DIM))
    console.print()
    console.print(Text("OUTPUT", style=CYAN))
    console.print()

    # Output must be NORMAL WHITE ONLY — no bold, no color, no background.
    output_text = Text(result, style="white")
    console.print(Padding(output_text, (0, 2)))

    console.print()
    timing = Text(f"Inference Time: {elapsed:.3f} seconds", style=DIM)
    console.print(timing)
    console.print()
    console.print(Rule(style=DIM))
    console.print()


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

def main():
    print_startup()

    with console.status(Text("Loading INT8 model...", style=CYAN).plain, spinner="dots", spinner_style=CYAN):
        model, tokenizer, processor = load_int8_model()

    console.print(Align.center(Text("Model loaded successfully.", style=GREEN)))
    console.print()
    time.sleep(0.4)

    while True:
        clear()
        print_startup()

        src = select_language("SOURCE", GREEN)
        clear()
        print_startup()

        tgt = select_language("DESTINATION", PINK, exclude_code=src[1])

        clear()
        print_startup()
        print_selection_summary(src, tgt)

        text = get_input_text()

        if not text.strip():
            console.print(Text("  Empty input — please enter some text.", style="bold red"))
            console.input(Text("Press Enter to continue...", style=DIM).plain)
            continue

        result, elapsed = run_translation(model, tokenizer, processor, text, src[1], tgt[1])
        print_output(result, elapsed)

        print_footer()

        again = Prompt.ask(
            Text("Translate another text?", style=YELLOW).plain,
            choices=["y", "n"],
            default="y",
        )
        if again.lower() != "y":
            console.print()
            console.print(Align.center(Text("Session ended. Thank you for using KAIROS.", style=BLUE)))
            console.print()
            break


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print()
        console.print(Align.center(Text("Interrupted. Exiting KAIROS.", style=DIM)))
        sys.exit(0)