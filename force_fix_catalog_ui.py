from pathlib import Path
import re
import shutil

root = Path(r"D:\My Project\KatalogA")
catalog = root / "app" / "templates" / "agent" / "catalog.html"

if not catalog.exists():
    raise SystemExit("catalog.html topilmadi")

html = catalog.read_text(encoding="utf-8")

# Oldingi shu fix bo'lsa olib tashlaymiz
html = re.sub(
    r"\n?<!-- KATALOGAA_FORCE_FINAL_FIX_V5_START -->.*?<!-- KATALOGAA_FORCE_FINAL_FIX_V5_END -->\n?",
    "\n",
    html,
    flags=re.DOTALL
)

force_block = r'''
<!-- KATALOGAA_FORCE_FINAL_FIX_V5_START -->
<style>
/* KATALOGAA_FORCE_FINAL_FIX_V5 */

/* KARTA ICHIDAGI - 0 + NI KICHIK QILISH */
body .agent-mini-card .qty-control,
body .qty-control {
    width: 84px !important;
    max-width: 84px !important;
    display: grid !important;
    grid-template-columns: 24px 28px 24px !important;
    gap: 4px !important;
    align-items: center !important;
    justify-content: center !important;
    margin: 8px auto 0 !important;
}

body .agent-mini-card .qty-btn,
body .qty-btn,
body button.minus-btn,
body button.plus-btn {
    width: 24px !important;
    height: 24px !important;
    min-width: 24px !important;
    min-height: 24px !important;
    max-width: 24px !important;
    max-height: 24px !important;
    padding: 0 !important;
    border-radius: 8px !important;
    font-size: 15px !important;
    font-weight: 900 !important;
    line-height: 1 !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
}

body .agent-mini-card .qty-number,
body .qty-number {
    width: 28px !important;
    height: 24px !important;
    min-width: 28px !important;
    min-height: 24px !important;
    max-width: 28px !important;
    max-height: 24px !important;
    padding: 0 !important;
    border-radius: 8px !important;
    font-size: 13px !important;
    font-weight: 900 !important;
    line-height: 24px !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
}

/* MODAL YOPISH TUGMASI */
body #closeCartBtn,
body .cart-close-btn,
body .modal-close,
body .order-close {
    width: 34px !important;
    height: 34px !important;
    min-width: 34px !important;
    min-height: 34px !important;
    border-radius: 50% !important;
    font-size: 26px !important;
    font-weight: 900 !important;
    line-height: 1 !important;
    display: inline-flex !important;
    align-items: center !important;
    justify-content: center !important;
}

@media (max-width: 640px) {
    body .agent-mini-card .qty-control,
    body .qty-control {
        width: 78px !important;
        max-width: 78px !important;
        grid-template-columns: 22px 26px 22px !important;
        gap: 4px !important;
    }

    body .agent-mini-card .qty-btn,
    body .qty-btn,
    body button.minus-btn,
    body button.plus-btn {
        width: 22px !important;
        height: 22px !important;
        min-width: 22px !important;
        min-height: 22px !important;
        max-width: 22px !important;
        max-height: 22px !important;
        font-size: 14px !important;
        border-radius: 7px !important;
    }

    body .agent-mini-card .qty-number,
    body .qty-number {
        width: 26px !important;
        height: 22px !important;
        min-width: 26px !important;
        min-height: 22px !important;
        max-width: 26px !important;
        max-height: 22px !important;
        font-size: 12px !important;
        line-height: 22px !important;
        border-radius: 7px !important;
    }
}
</style>

<script>
/* KATALOGAA_FORCE_FINAL_FIX_V5 */
(function () {
    function getLang() {
        try {
            const p = new URLSearchParams(window.location.search);
            return p.get("lang") || window.AGENT_LANG || "ru";
        } catch (e) {
            return window.AGENT_LANG || "ru";
        }
    }

    function unitLabel() {
        return getLang() === "uz" ? "dona" : "\u0448\u0442";
    }

    function clearLabel() {
        return getLang() === "uz" ? "Tozalash" : "\u041e\u0447\u0438\u0441\u0442\u0438\u0442\u044c";
    }

    function normalizeQtyButtons() {
        document.querySelectorAll(".qty-control").forEach(function (box) {
            const buttons = Array.from(box.querySelectorAll("button"));
            if (buttons.length >= 2) {
                buttons[0].textContent = "-";
                buttons[0].classList.add("minus-btn");

                buttons[buttons.length - 1].textContent = "+";
                buttons[buttons.length - 1].classList.add("plus-btn");
            }
        });
    }

    function normalizeCloseButton() {
        const buttons = document.querySelectorAll("#closeCartBtn, .cart-close-btn, .modal-close, .order-close");
        buttons.forEach(function (btn) {
            btn.innerHTML = "&times;";
            btn.setAttribute("aria-label", "close");
        });

        document.querySelectorAll("button").forEach(function (btn) {
            const txt = (btn.textContent || "").trim();
            const insideModal = btn.closest(".cart-modal, .order-modal, .modal, .cart-modal-overlay");
            if (insideModal && (txt === "\u0413" || txt === "\u0433")) {
                btn.innerHTML = "&times;";
            }
        });
    }

    function normalizeTextNodes() {
        const unit = unitLabel();

        const walker = document.createTreeWalker(
            document.body,
            NodeFilter.SHOW_TEXT,
            null
        );

        let node;
        while ((node = walker.nextNode())) {
            let text = node.nodeValue;
            let next = text;

            next = next
                .replace(/сомонӣ/g, "сомон")
                .replace(/сомони/g, "сомон")
                .replace(/сомонй/g, "сомон")
                .replace(/сум/g, "сомон");

            // 2 Г — 20 сомон => 2 шт — 20 сомон
            next = next.replace(/(\d+)\s*[\u0413\u0433]\s*[—-]\s*/g, "$1 " + unit + " — ");

            // 2 × 20 сомон => 2 шт — 20 сомон
            next = next.replace(/(\d+)\s*[×x]\s*(?=\d)/g, "$1 " + unit + " — ");

            if (next !== text) {
                node.nodeValue = next;
            }
        }
    }

    function normalizeClearButton() {
        document.querySelectorAll("button, a, div, span").forEach(function (el) {
            const txt = (el.textContent || "").trim();
            const cls = String(el.className || "").toLowerCase();

            if (
                txt.includes("built-in method clear") ||
                txt.includes("clear of dict object") ||
                cls.includes("cart-clear") ||
                cls.includes("clear")
            ) {
                if (txt.includes("built-in method") || cls.includes("cart-clear") || cls.includes("clear")) {
                    el.textContent = clearLabel();
                }
            }
        });
    }

    function runFix() {
        normalizeQtyButtons();
        normalizeCloseButton();
        normalizeTextNodes();
        normalizeClearButton();
    }

    document.addEventListener("DOMContentLoaded", function () {
        runFix();

        setTimeout(runFix, 100);
        setTimeout(runFix, 400);
        setTimeout(runFix, 900);
        setTimeout(runFix, 1500);
        setTimeout(runFix, 2500);

        document.addEventListener("click", function () {
            setTimeout(runFix, 50);
            setTimeout(runFix, 250);
            setTimeout(runFix, 700);
        });

        const observer = new MutationObserver(function () {
            runFix();
        });

        observer.observe(document.body, {
            childList: true,
            subtree: true,
            characterData: true
        });
    });
})();
</script>
<!-- KATALOGAA_FORCE_FINAL_FIX_V5_END -->
'''

if "</body>" in html:
    html = html.replace("</body>", force_block + "\n</body>")
else:
    html += "\n" + force_block

catalog.write_text(html, encoding="utf-8")

for p in root.rglob("__pycache__"):
    if p.is_dir():
        shutil.rmtree(p, ignore_errors=True)

print("OK: forced final catalog UI fix applied")
print(catalog)