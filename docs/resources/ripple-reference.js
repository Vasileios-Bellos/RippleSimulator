/* Section navigation and example disclosure for the API reference. */
(() => {
    "use strict";
    const standalone = document.querySelector(".ripple-reference article");
    const integrated = document.querySelector(".ripple-reference-index > div");
    if (!standalone && !integrated) return;

    const headingOf = node => {
        if (/^H[1-6]$/.test(node.tagName)) return node;
        if (!node.classList.contains("markdown-heading")) return null;
        return Array.from(node.children).find(child => /^H[1-6]$/.test(child.tagName)) || null;
    };
    const isAlias = node => node.matches("a[id]:not([href])") && !node.textContent && !node.children.length;
    const startsSection = (node, level) => {
        while (node && isAlias(node)) node = node.nextElementSibling;
        const heading = node && headingOf(node);
        return heading && Number(heading.tagName.slice(1)) <= level;
    };
    const articles = standalone ? [standalone] : [];
    if (integrated) {
        const links = integrated.querySelector("table").querySelectorAll("tbody a[href]");
        for (const link of links) {
            const title = document.getElementById(decodeURIComponent(link.hash.slice(1)));
            if (!title || title.tagName !== "H2" || !integrated.contains(title)) continue;
            const start = title.closest(".markdown-heading") || title;
            const article = document.createElement("section");
            article.className = "reference-article";
            article.setAttribute("aria-labelledby", title.id);
            start.before(article);
            let next = start.nextElementSibling;
            article.append(start);
            while (next && !startsSection(next, 2)) {
                const following = next.nextElementSibling;
                article.append(next);
                next = following;
            }
            articles.push(article);
        }
    }

    const groups = new Set(["Examples", "Input Arguments", "Name-Value Arguments", "Output Arguments"]);
    const updates = articles.map(article => {
        const title = article.querySelector("h1,h2");
        const sectionLevel = Number(title.tagName.slice(1)) + 1;
        const itemLevel = sectionLevel + 1;
        let currentSection = "";
        for (const node of Array.from(article.children)) {
            const heading = headingOf(node);
            if (!heading) continue;
            const level = Number(heading.tagName.slice(1));
            if (level <= sectionLevel) {
                currentSection = level === sectionLevel ? heading.textContent.trim() : "";
            }
            if (level !== itemLevel || !groups.has(currentSection)) continue;
            const disclosure = document.createElement("details");
            disclosure.className = "reference-detail";
            disclosure.open = true;
            const summary = document.createElement("summary");
            node.before(disclosure);
            if (node === heading) summary.append(node);
            else {
                summary.append(...node.childNodes);
                node.remove();
            }
            disclosure.append(summary);
            let next = disclosure.nextElementSibling;
            while (next && !startsSection(next, itemLevel)) {
                const following = next.nextElementSibling;
                disclosure.append(next);
                next = following;
            }
        }

        const disclosures = Array.from(article.querySelectorAll(".reference-detail"));
        if (!disclosures.length) return () => {};
        const button = document.createElement("button");
        button.className = "reference-toggle";
        button.type = "button";
        const updateToggle = () => {
            const allOpen = disclosures.every(detail => detail.open);
            button.setAttribute("aria-expanded", String(allOpen));
            button.textContent = allOpen ? "Collapse all" : "Expand all";
            button.setAttribute("aria-label", `${button.textContent} sections for ${title.textContent.trim()}`);
        };
        button.addEventListener("click", () => {
            const open = !disclosures.every(detail => detail.open);
            disclosures.forEach(detail => { detail.open = open; });
            updateToggle();
        });
        disclosures.forEach(detail => detail.addEventListener("toggle", updateToggle));
        (title.closest(".markdown-heading") || title).after(button);
        updateToggle();
        return updateToggle;
    });

    const revealTarget = () => {
        let identifier;
        try {
            identifier = decodeURIComponent(location.hash.slice(1));
        } catch {
            return;
        }
        let target = document.getElementById(identifier);
        if (target && isAlias(target)) {
            let next = target.nextElementSibling;
            while (next && isAlias(next)) next = next.nextElementSibling;
            if (next && next.matches(".reference-detail")) target = next.querySelector("summary");
        }
        let disclosure = target && target.closest(".reference-detail");
        if (!disclosure) return;
        while (disclosure) {
            disclosure.open = true;
            disclosure = disclosure.parentElement.closest(".reference-detail");
        }
        updates.forEach(update => update());
        requestAnimationFrame(() => target.scrollIntoView());
    };
    window.addEventListener("hashchange", revealTarget);
    document.addEventListener("click", event => {
        const link = event.target.closest("a[href]");
        if (link && link.hash && link.hash === location.hash &&
            link.pathname === location.pathname && link.origin === location.origin) revealTarget();
    });
    revealTarget();

    if (!standalone) return;
    const article = standalone;
    const contents = document.querySelector(".reference-contents details");
    const compact = window.matchMedia("(max-width: 900px)");
    if (contents) {
        const updateContents = () => { contents.open = !compact.matches; };
        updateContents();
        if (compact.addEventListener) compact.addEventListener("change", updateContents);
        else compact.addListener(updateContents);
    }
    const links = Array.from(document.querySelectorAll(".reference-contents a"));
    const headings = Array.from(article.querySelectorAll("h2[id]"));
    let activeId = "";
    let navigationScheduled = false;
    const updateNavigation = () => {
        navigationScheduled = false;
        let current = headings[0];
        const sectionOffset = current ? parseFloat(getComputedStyle(current).scrollMarginTop) : 0;
        const threshold = Math.max(sectionOffset + 1, Math.min(160, innerHeight * 0.2));
        for (const heading of headings) {
            if (heading.getBoundingClientRect().top > threshold) break;
            current = heading;
        }
        if (!current || current.id === activeId) return;
        activeId = current.id;
        links.forEach(link => {
            if (link.getAttribute("href") === "#" + activeId) link.setAttribute("aria-current", "location");
            else link.removeAttribute("aria-current");
        });
    };
    const scheduleNavigation = () => {
        if (navigationScheduled) return;
        navigationScheduled = true;
        requestAnimationFrame(updateNavigation);
    };
    window.addEventListener("scroll", scheduleNavigation, {passive: true});
    window.addEventListener("resize", scheduleNavigation);
    article.addEventListener("toggle", scheduleNavigation, true);
    scheduleNavigation();
})();
