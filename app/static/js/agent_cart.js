
(function () {
    const CART_KEY = "kataloga_agent_cart_v1";
    const t = window.AGENT_I18N || {};
    const currency = t.currency || "СЃРѕРјРѕРЅУЈ";

    function money(value) {
        const n = Number(value || 0);
        return n.toLocaleString("ru-RU") + " " + currency;
    }

    function loadCart() {
        try {
            return JSON.parse(localStorage.getItem(CART_KEY) || "{}");
        } catch (e) {
            return {};
        }
    }

    function saveCart(cart) {
        localStorage.setItem(CART_KEY, JSON.stringify(cart));
    }

    function getProductData(productId) {
        const card = document.querySelector(`.order-product-card[data-product-id="${productId}"]`);
        if (!card) return null;

        return {
            product_id: Number(productId),
            name: card.dataset.productName || "",
            price: Number(card.dataset.productPrice || 0),
            quantity: 0
        };
    }

    function cartCount(cart) {
        return Object.values(cart).reduce((sum, item) => sum + Number(item.quantity || 0), 0);
    }

    function cartTotal(cart) {
        return Object.values(cart).reduce((sum, item) => {
            return sum + Number(item.price || 0) * Number(item.quantity || 0);
        }, 0);
    }

    function updateQtyViews(cart) {
        document.querySelectorAll(".qty-number").forEach(el => {
            const productId = el.id.replace("qty-", "");
            el.textContent = cart[productId] ? cart[productId].quantity : 0;
        });

        const count = cartCount(cart);

        const top = document.getElementById("cartTopCount");
        const floating = document.getElementById("floatingCartCount");

        if (top) top.textContent = count;
        if (floating) floating.textContent = count;
    }

    function renderCartModal() {
        const cart = loadCart();
        const box = document.getElementById("cartItemsBox");
        const totalBox = document.getElementById("cartTotalSum");

        if (!box || !totalBox) return;

        const items = Object.values(cart).filter(item => Number(item.quantity) > 0);

        if (items.length === 0) {
            box.innerHTML = `<div class="cart-empty">${t.empty_cart || "Zakaz hali bo'sh"}</div>`;
        } else {
            box.innerHTML = items.map(item => {
                const lineTotal = Number(item.price || 0) * Number(item.quantity || 0);
                return `
                    <div class="cart-item">
                        <div>
                            <div class="cart-item-name">${escapeHtml(item.name)}</div>
                            <div class="cart-item-meta">${item.quantity} Г— ${money(item.price)}</div>
                        </div>
                        <div class="cart-item-total">${money(lineTotal)}</div>
                    </div>
                `;
            }).join("");
        }

        totalBox.textContent = money(cartTotal(cart));
    }

    function escapeHtml(value) {
        return String(value || "")
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#039;");
    }

    function openCart() {
        renderCartModal();
        document.getElementById("cartModal")?.classList.add("show");
    }

    function closeCart() {
        document.getElementById("cartModal")?.classList.remove("show");
    }

    function changeQty(productId, delta) {
        const cart = loadCart();
        const current = cart[productId] || getProductData(productId);

        if (!current) return;

        current.quantity = Math.max(0, Number(current.quantity || 0) + delta);

        if (current.quantity <= 0) {
            delete cart[productId];
        } else {
            cart[productId] = current;
        }

        saveCart(cart);
        updateQtyViews(cart);
        renderCartModal();
    }

    async function confirmOrder() {
        const storeInput = document.getElementById("storeNameInput");
        const storeName = (storeInput?.value || "").trim();
        const cart = loadCart();
        const items = Object.values(cart).filter(item => Number(item.quantity) > 0);

        if (!storeName) {
            alert(t.fill_store || "Magazin nomini yozing");
            storeInput?.focus();
            return;
        }

        if (items.length === 0) {
            alert(t.add_products || "Avval mahsulot tanlang");
            return;
        }

        const btn = document.getElementById("confirmOrderBtn");
        if (btn) btn.disabled = true;

        try {
            const response = await fetch("/agent/order", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    store_name: storeName,
                    items: items.map(item => ({
                        product_id: item.product_id,
                        quantity: item.quantity
                    }))
                })
            });

            const result = await response.json();

            if (!response.ok || !result.ok) {
                throw new Error(result.error || "error");
            }

            localStorage.removeItem(CART_KEY);
            updateQtyViews({});
            renderCartModal();
            closeCart();

            alert((t.success || "Zakaz qabul qilindi") + " #" + result.order_id);
            window.location.reload();
        } catch (e) {
            alert("Xatolik: zakaz yuborilmadi");
        } finally {
            if (btn) btn.disabled = false;
        }
    }

    document.addEventListener("click", function (event) {
        const plus = event.target.closest(".plus-btn");
        if (plus) {
            changeQty(plus.dataset.productId, 1);
            return;
        }

        const minus = event.target.closest(".minus-btn");
        if (minus) {
            changeQty(minus.dataset.productId, -1);
            return;
        }

        if (event.target.closest("#openCartBtn") || event.target.closest("#floatingCartBtn")) {
            openCart();
            return;
        }

        if (event.target.closest("#closeCartBtn")) {
            closeCart();
            return;
        }

        if (event.target.id === "cartModal") {
            closeCart();
            return;
        }

        if (event.target.closest("#clearCartBtn")) {
            localStorage.removeItem(CART_KEY);
            updateQtyViews({});
            renderCartModal();
            return;
        }

        if (event.target.closest("#confirmOrderBtn")) {
            confirmOrder();
            return;
        }
    });

    document.addEventListener("DOMContentLoaded", function () {
        updateQtyViews(loadCart());
    });
})();
