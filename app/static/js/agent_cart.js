
(function () {
    const CART_KEY = "kataloga_agent_cart_v1";
    const t = window.AGENT_I18N || {};
    const lang = window.AGENT_LANG || "ru";
    const currency = (t.currency || "сомон").replace("сомонӣ", "сомон").replace("сомони", "сомон").replace("сомонй", "сомон");

    function unitLabel() {
        return lang === "uz" ? "dona" : "шт";
    }

    function clearLabel() {
        return lang === "uz" ? "Tozalash" : "Очистить";
    }

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

    function escapeHtml(value) {
        return String(value || "")
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#039;");
    }

    function renderCartModal() {
        const cart = loadCart();
        const box = document.getElementById("cartItemsBox");
        const totalBox = document.getElementById("cartTotalSum");

        if (!box || !totalBox) return;

        const items = Object.values(cart).filter(item => Number(item.quantity) > 0);

        if (items.length === 0) {
            box.innerHTML = `<div class="cart-empty">${t.empty_cart || "Заказ пока пуст"}</div>`;
        } else {
            box.innerHTML = items.map(item => {
                const lineTotal = Number(item.price || 0) * Number(item.quantity || 0);
                return `
                    <div class="cart-item">
                        <div>
                            <div class="cart-item-name">${escapeHtml(item.name)}</div>
                            <div class="cart-item-meta">${item.quantity} ${unitLabel()} — ${money(item.price)}</div>
                        </div>
                        <div class="cart-item-total">${money(lineTotal)}</div>
                    </div>
                `;
            }).join("");
        }

        totalBox.textContent = money(cartTotal(cart));

        const clearBtn = document.getElementById("clearCartBtn");
        if (clearBtn) clearBtn.textContent = clearLabel();

        const closeBtn = document.getElementById("closeCartBtn");
        if (closeBtn) closeBtn.innerHTML = "&times;";
    }

    function openCart() {
        renderCartModal();
        document.getElementById("cartModal")?.classList.add("show");
    }

    function closeCart() {
        document.getElementById("cartModal")?.classList.remove("show");
    }

    function changeQty(productId, delta) {
        if (!productId) return;

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
            alert(t.fill_store || "Введите название магазина");
            storeInput?.focus();
            return;
        }

        if (items.length === 0) {
            alert(t.add_products || "Сначала выберите товар");
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

            alert((t.success || "Заказ принят") + " #" + result.order_id);
            window.location.reload();
        } catch (e) {
            alert("Ошибка: заказ не отправлен");
        } finally {
            if (btn) btn.disabled = false;
        }
    }

    document.addEventListener("click", function (event) {
        const plus = event.target.closest(".plus-btn");
        if (plus) {
            event.preventDefault();
            changeQty(plus.dataset.productId, 1);
            return;
        }

        const minus = event.target.closest(".minus-btn");
        if (minus) {
            event.preventDefault();
            changeQty(minus.dataset.productId, -1);
            return;
        }

        if (event.target.closest("#openCartBtn") || event.target.closest("#floatingCartBtn")) {
            event.preventDefault();
            openCart();
            return;
        }

        if (event.target.closest("#closeCartBtn")) {
            event.preventDefault();
            closeCart();
            return;
        }

        if (event.target.id === "cartModal") {
            closeCart();
            return;
        }

        if (event.target.closest("#clearCartBtn")) {
            event.preventDefault();
            localStorage.removeItem(CART_KEY);
            updateQtyViews({});
            renderCartModal();
            return;
        }

        if (event.target.closest("#confirmOrderBtn")) {
            event.preventDefault();
            confirmOrder();
            return;
        }
    });

    document.addEventListener("DOMContentLoaded", function () {
        document.querySelectorAll(".minus-btn").forEach(btn => btn.textContent = "-");
        document.querySelectorAll(".plus-btn").forEach(btn => btn.textContent = "+");

        const closeBtn = document.getElementById("closeCartBtn");
        if (closeBtn) closeBtn.innerHTML = "&times;";

        const clearBtn = document.getElementById("clearCartBtn");
        if (clearBtn) clearBtn.textContent = clearLabel();

        updateQtyViews(loadCart());
    });
})();
