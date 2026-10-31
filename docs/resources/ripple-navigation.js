/* Chapter navigation and responsive manual contents. */
(() => {
    "use strict";
    const navigation = document.querySelector(".ripple-navigation");
    if (navigation) {
        const updateHeight = () => {
            const height = Math.ceil(navigation.getBoundingClientRect().height);
            document.documentElement.style.setProperty("--manual-navigation-height", height + "px");
        };
        updateHeight();
        if (window.ResizeObserver) new ResizeObserver(updateHeight).observe(navigation);
        else window.addEventListener("resize", updateHeight);
        window.addEventListener("load", () => {
            updateHeight();
            const target = document.getElementById(decodeURIComponent(location.hash.slice(1)));
            if (target) target.scrollIntoView();
        }, { once: true });
    }
    const tree = document.querySelector(".manual-tree");
    if (!tree) return;
    const compact = window.matchMedia("(max-width: 900px)");
    const update = () => { tree.open = !compact.matches; };
    update();
    if (compact.addEventListener) compact.addEventListener("change", update);
    else compact.addListener(update);

    const current = tree.querySelector('a[aria-current="page"]');
    if (!current) return;
    const page = current.getAttribute("href");
    const links = Array.from(tree.querySelectorAll("a"))
        .filter(link => link.getAttribute("href").startsWith(page + "#"));
    const revealSection = () => {
        const hash = decodeURIComponent(location.hash.slice(1));
        links.forEach(link => {
            const selected = decodeURIComponent(link.hash.slice(1)) === hash;
            if (selected) {
                link.setAttribute("aria-current", "location");
                let parent = link.parentElement;
                while (parent && parent !== tree) {
                    if (parent.tagName === "DETAILS") parent.open = true;
                    parent = parent.parentElement;
                }
            } else {
                link.removeAttribute("aria-current");
            }
        });
    };
    revealSection();
    window.addEventListener("hashchange", revealSection);
})();
