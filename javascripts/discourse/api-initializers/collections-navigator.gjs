import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.24.0", (api) => {
  let keyboardHandlerBound = false;
  let resizerBound = false;

  function getScrollBehavior() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
      ? "auto"
      : "smooth";
  }

  function throttle(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  function getCssPxNumber(element, varName, fallback) {
    const raw = getComputedStyle(element).getPropertyValue(varName).trim();
    if (!raw) {
      return fallback;
    }
    if (raw.startsWith("min(") || raw.startsWith("max(") || raw.startsWith("clamp(")) {
      return fallback;
    }
    const parsed = parseFloat(raw.replace("px", ""));
    return Number.isNaN(parsed) ? fallback : parsed;
  }

  function ensureSidebarResizer(modal) {
    if (!modal) {
      return null;
    }

    let resizer = modal.querySelector(".collections-sidebar-resizer");
    if (resizer) {
      return resizer;
    }

    const splitBody = modal.querySelector(".modal-body-split");
    const sidebar = modal.querySelector(".modal-items-sidebar");
    const contentArea = modal.querySelector(".modal-content-area");

    if (!splitBody || !sidebar || !contentArea) {
      return null;
    }

    resizer = document.createElement("div");
    resizer.className = "collections-sidebar-resizer";
    resizer.setAttribute("role", "separator");
    resizer.setAttribute("aria-orientation", "vertical");
    resizer.setAttribute("aria-label", "Resize collection sidebar");
    resizer.tabIndex = 0;

    splitBody.insertBefore(resizer, contentArea);
    return resizer;
  }

  function bindSidebarResizer() {
    if (resizerBound) {
      return;
    }

    const onPointerDown = (event) => {
      const resizer = event.target.closest(".collections-sidebar-resizer");
      if (!resizer) {
        return;
      }

      const modal = resizer.closest(".collections-nav-modal");
      if (!modal || window.innerWidth <= 767) {
        return;
      }

      const splitBody = modal.querySelector(".modal-body-split");
      const sidebar = modal.querySelector(".modal-items-sidebar");
      if (!splitBody || !sidebar) {
        return;
      }

      event.preventDefault();

      const splitRect = splitBody.getBoundingClientRect();
      const minWidth = getCssPxNumber(modal, "--collections-sidebar-min-width", 240);
      const maxWidthFallback = Math.max(minWidth, Math.floor(splitRect.width * 0.45));
      const maxWidth = getCssPxNumber(modal, "--collections-sidebar-max-width", maxWidthFallback);

      modal.classList.add("is-resizing");
      document.body.classList.add("collections-is-resizing");

      const updateWidth = (clientX) => {
        const proposed = clientX - splitRect.left;
        const nextWidth = clamp(proposed, minWidth, maxWidth);
        modal.style.setProperty("--collections-sidebar-width", `${nextWidth}px`);
        resizer.setAttribute("aria-valuenow", String(Math.round(nextWidth)));
      };

      updateWidth(event.clientX);

      const onPointerMove = (moveEvent) => {
        updateWidth(moveEvent.clientX);
      };

      const stopDragging = () => {
        modal.classList.remove("is-resizing");
        document.body.classList.remove("collections-is-resizing");
        window.removeEventListener("pointermove", onPointerMove);
        window.removeEventListener("pointerup", stopDragging);
        window.removeEventListener("pointercancel", stopDragging);
      };

      window.addEventListener("pointermove", onPointerMove);
      window.addEventListener("pointerup", stopDragging);
      window.addEventListener("pointercancel", stopDragging);
    };

    const onKeyDown = (event) => {
      const resizer = event.target.closest(".collections-sidebar-resizer");
      if (!resizer) {
        return;
      }

      const modal = resizer.closest(".collections-nav-modal");
      if (!modal) {
        return;
      }

      const currentWidth = getCssPxNumber(modal, "--collections-sidebar-width", 320);
      const minWidth = getCssPxNumber(modal, "--collections-sidebar-min-width", 240);
      const splitBody = modal.querySelector(".modal-body-split");
      const splitRect = splitBody?.getBoundingClientRect();
      const maxWidthFallback = splitRect
        ? Math.max(minWidth, Math.floor(splitRect.width * 0.45))
        : 520;
      const maxWidth = getCssPxNumber(modal, "--collections-sidebar-max-width", maxWidthFallback);

      let nextWidth = null;

      if (event.key === "ArrowLeft") {
        nextWidth = currentWidth - 24;
      } else if (event.key === "ArrowRight") {
        nextWidth = currentWidth + 24;
      } else if (event.key === "Home") {
        nextWidth = minWidth;
      } else if (event.key === "End") {
        nextWidth = maxWidth;
      }

      if (nextWidth === null) {
        return;
      }

      event.preventDefault();
      nextWidth = clamp(nextWidth, minWidth, maxWidth);
      modal.style.setProperty("--collections-sidebar-width", `${nextWidth}px`);
      resizer.setAttribute("aria-valuenow", String(Math.round(nextWidth)));
    };

    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    resizerBound = true;
  }

  api.onPageChange(() => {
    setTimeout(() => {
      const sidebarPanel = document.querySelector(".discourse-collections-sidebar-panel");
      const postsContainer = document.querySelector(".posts");

      if (!sidebarPanel || !postsContainer) {
        return;
      }

      let links = sidebarPanel.querySelectorAll(".collection-sidebar-link");

      document
        .querySelectorAll(".collections-nav-injected")
        .forEach((el) => el.remove());
      document
        .querySelectorAll(".collections-nav-modal-overlay")
        .forEach((el) => el.remove());

      const collectionTitleEl = document.querySelector(".collection-sidebar__title");
      const collectionDescEl = document.querySelector(".collection-sidebar__desc");
      const collectionName =
        collectionTitleEl?.textContent?.trim() || "Collection";
      const collectionDesc = collectionDescEl?.textContent?.trim() || "";

      const isExternalUrl = (href) => {
        if (!href) return false;
        if (href.startsWith("http://") || href.startsWith("https://")) {
          try {
            const url = new URL(href);
            return url.hostname !== window.location.hostname;
          } catch (e) {
            return false;
          }
        }
        return false;
      };

      const items = Array.from(links).map((link) => {
        const href = link.getAttribute("href");

        let title = link
          .querySelector(".collection-link-content-text")
          ?.textContent?.trim();
        if (!title)
          title = link
            .querySelector(".sidebar-section-link-content-text")
            ?.textContent?.trim();
        if (!title)
          title = link
            .querySelector("[class*='content-text']")
            ?.textContent?.trim();
        if (!title) title = link.textContent?.trim();
        if (!title) title = "Untitled";

        const external = isExternalUrl(href);
        const idMatch = href ? href.match(/\/(\d+)$/) : null;
        const topicId = !external && idMatch ? idMatch[1] : null;

        return {
          title,
          href,
          topicId,
          external,
        };
      });

      if (items.length < 2) {
        return;
      }

      const currentUrl = window.location.pathname;
      const currentIndex = items.findIndex((item) => {
        if (item.external || !item.href) {
          return false;
        }
        const parts = item.href.split("/");
        const slugPart = parts[2];
        return slugPart && currentUrl.includes(slugPart);
      });

      if (currentIndex === -1) {
        return;
      }

      const currentItem = items[currentIndex];
      const totalItems = items.length;

      const getPostContentNode = () => {
        let content = document.querySelector(
          ".topic-post[data-post-number='1'] .cooked"
        );
        if (!content) {
          content = document.querySelector(".topic-body .cooked");
        }
        if (!content) {
          return null;
        }
        return content.cloneNode(true);
      };

      const cookedNode = getPostContentNode();
      const cookedContent =
        cookedNode?.outerHTML || "<p>Loading content...</p>";

      const KEYBOARD_THROTTLE_MS = 150;
      const SCROLL_THROTTLE_MS = 50;

      function adjustIframe(iframe, wrapper) {
        if (!iframe || !wrapper) {
          return;
        }

        const rect = wrapper.getBoundingClientRect();
        const offsetTop = rect.top + window.scrollY;
        const offsetLeft = rect.left + window.scrollX;

        wrapper.style.height = "calc(100vh - " + offsetTop + "px)";

        iframe.style.position = "absolute";
        iframe.style.top = "0";
        iframe.style.left = offsetLeft > 0 ? "-" + offsetLeft + "px" : "0";
        iframe.style.width = wrapper.offsetWidth + "px";
        iframe.style.height = "100%";
        iframe.style.border = "none";
        iframe.style.display = "block";

        wrapper.style.visibility = "visible";
      }

      const enhanceCooked = (element) => {
        if (!element) {
          return;
        }

        api.decorateCookedElement(() => {}, {
          id: "collections-navigator-modal",
        });

        api.applyDecoratorsToElement?.(elementecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i class="btn btn--primary collections-nav-toggle" title="Open collection navigator" type="button">
          <svg class="fa d-icon d-icon-collection-pip svg-icon fa-width-auto prefix-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <use href="#collection-pip"></use>
          </svg>
          <span class="nav-text">${collectionName}: ${currentItem.title} (${currentIndex + 1}/${totalItems})</span>
        </button>
        <div class="collections-quick-nav">
          <button class="btn btn--secondary collections-nav-prev" ${
            currentIndex === 0 ? "disabled" : ""
          } title="Previous (arrow key)" type="button">
            <svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
              <use href="#arrow-left"></use>
            </ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iw key)" type="button">
            <svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
              <use href="#arrow-right"></use>
            </svg>
          </button>
        </div>
      `;
      postsContainer.parentNode.insertBefore(navBar, postsContainer);

      const modal = document.createElement("div");
      modal.className = "collections-nav-modal-overlay";
      modal.innerHTML = `
        <div class="collections-nav-modal collections-modal-with-content">
          <div class="modal-header">
            <button class="modal-sidebar-toggle btn btn-flat btn--toggle no-text btn-icon narrow-desktop" aria-label="Toggle sidebar" type="button" title="Toggle sidebar">
              <svg class="fa d-icon d-icon-bars svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                <use href="#bars"></use>
              </svg>
            </button>
            <div class="modal-header-content">
              <h2 class="modal-title">${collectionName}<ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.idiv class="topic-slider-container">
                <div class="topic-slider">
                  ${items
                    .map(
                      (item, idx) => `
                    <button class="slider-item ${
                      idx === currentIndex ? "active" : ""
                    }" data-index="${idx}" title="${item.title}">
                      ${item.external ? `<svg class="fa d-icon svg-icon svg-string" width="1em" height="1em" viewBox="0 0 512 512" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><path fill="currentColor" d="M320 0c-17.7 0-32 14.3-32 32s14.3 32 32 32l82.7 0L201.4 265.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L448 109.3l0 82.7c0 17.7 14.3 32 32 32s32-14.3 32-32l0-160c0-17.7-14.3-32-32-32L320 0zM8ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.illections-nav-injected";
      navBar.i     navBar.inav-injected";
      navBar.iinjected";
      navBar.i-injected";
      navBar.inav-bar collections-nav-injected";
      navBar.ieateElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i                 )
                    .join("")}
                </div>
              </div>
            </div>
            <button class="modal-close-btn" aria-label="Close modal" type="button">
              <svg class="fa d-icon d-icon-times svg-ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i       </div>
          <div class="modal-body-split">
            <div class="modal-items-sidebar collapsed">
              <ul class="collection-items-list">
                ${items
                  .map(
                    (item, idx) => `
                  <li class="collection-item ${
                    idx === currentIndex ? "active" : ""
                  }">
                    <div class="collection-item-link ${
                      item.external ? "external-link" : ""
                    }" data-iecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i        ${
                        idx === currentIndex
                          ? '<span class="d-icon d-icon-check"></span>'
                          : ""
                      }
                      ${
                        item.external
                          ? `<span class="collections-external-link-button" ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.icreateElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ient("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i
      navBar.iv-injected";
      navBar.icollections-nav-injected";
      navBar.iollections-nav-injected";
      navBar.icollections-nav-injected";
      navBar.ilections-nav-injected";
      navBar.iollections-nav-injected";
      navBar.iollections-nav-injected";
      navBar.iem-nav-bar collections-nav-injected";
      navBar.iollections-nav-injected";
      navBar.iav-bar collections-nav-injected";
      navBar.ins-nav-injected";
      navBar.i(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i         <div claecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i   const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i
      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i      navBar.iement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.icollections-nav-injected";
      navBar.is-nav-injected";
      navBar.iBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iiv>
            <button class="btn btn--secondary modal-content-next" title="Next item" type="button" ${
              currentIndex === totalIecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ien="true" xmlns="http://www.w3.org/2000/svg">
                <use href="#arrow-right"></ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ions-nav-modal");
      ensureSidecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iTML = "";
        contentArea.appendChild(cookedNode);
      } else {
        enhecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ited";
      navBar.iquerySelector(".collectionsecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i
      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ilector(".content-heecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i = modal.querySelector(".modal-content-prev");
      const modalContentNext = modal.querySelector(".modal-content-next");
      const pagingText = modal.querySelector(".paging-text");
      const topicSliderContainer = modal.querySelector(".topic-slider-container");

      let selectedIndex = currentIndex;
      let sidebarOpen = false;

      const showModal = () => {
        modal.style.display = "flex";
      };
      const hideModal = () => {
        modal.style.display = "none";
      };

      const toggleSidecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i
          modalPanel.classList.add("collections-sidebar-open");
        } else {
          topicSliderContainer.classList.remove("collapsed");
          sidebar.classList.add("collapsed");
          modalPanel.classList.remove("collections-sidebar-open");
        }
      };

      const scrollSliderToActive = () => {
        const activeSlider = modal.querySelector(".slider-item.active");
        if (activeSlider) {
          activeSlider.scrollIntoView({
            behavior: getScrollBehavior(),
            block: "nearest",
            inline: "center",
          }ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i}

        selectedIndex = index;

        const navText = navBar.querySelector(".nav-text");
        navText.textConteecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iitems[index].topicIecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.int);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i   const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.inavBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.idiv");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i-bar collections-nav-injected";
      navBar.i           targetConecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iment?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i               enhanceCooked(targetContent);
              }

              contentTitle.textContent = items[index].tiecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iatch((err) => console.error("Error updating content", err));
        }
      };

      const loadExteecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ir = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i = "collections-item-nav-bar collections-nav-injected";
      navBar.illections-item-nav-bar collections-nav-injected";
      navBar.i navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.icollections-nav-injected";
      navBar.ilections-nav-injected";
      navBar.i collections-nav-injected";
      navBar.ilections-nav-injected";
      navBar.iv-injected";
      navBar.iollections-nav-injected";
      navBar.i      navBar.im-nav-bar collections-nav-injected";
      navBar.iv-injected";
      navBar.ictions-nav-injected";
      navBar.iar collections-nav-injected";
      navBar.ilement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iv");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ieateElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i     navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i);
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i = "collections-item-nav-bar collections-nav-injected";
      navBar.i-item-nav-bar collections-nav-injected";
      navBar.inavBar.ins-item-nav-bar collections-nav-injected";
      navBar.iav-bar collections-nav-injected";
      navBar.ime = "collections-item-nav-bar collections-nav-injected";
      navBar.ime = "collections-item-nav-bar collections-nav-injected";
      navBar.iBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i    if (loadingDiv && loadingDiv.style.display !== "none") {
            try {
              iframe.contentWindow.location.href;
              onLoaecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i index >= totalItems) return;

        selectedIndex = index;
        contentTitle.textContent = items[index].title;
        contentHeaderActions.innerHTML = "";

        pagingText.textContent = `${index + 1}/${totalItems}`;
        modalContentPrev.disabled = index === 0;
        modalContentNext.disabled = index === totalItems - 1;

        sliderItems.forEach((item, idx) =>
          item.classList.toggle("active", idx === index)
        );
        itemLinks.forEach((link, idx) =>
          link.classList.toggle("active", idx === index)
        );
       ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.itent-wrapper");
          contentArea.innerHTML = loadExternalContent(items[index].href);
          setupIframeHandlers(contentArea);

          contentHeaderActions.innerHTML = `
            <a href="${itemsecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ieight="1em" viewBox=ecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.illections-item-nav-bar collections-nav-injected";
      navBar.ie = "collections-item-nav-bar collections-nav-injected";
      navBar.iav-injected";
      navBar.i     navBar.iollections-nav-injected";
      navBar.icollections-nav-injected";
      navBar.im-nav-bar collections-nav-injected";
      navBar.illections-nav-injected";
      navBar.i collections-nav-injected";
      navBar.iinjected";
      navBar.item-nav-bar collections-nav-injected";
      navBar.iected";
      navBar.i-injected";
      navBar.ins-nav-injected";
      navBar.ions-item-nav-bar collections-nav-injected";
      navBar.i.iElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i;
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i]?.cooked;
                contentArea.innerHTML = coecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ielement);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iitle} (${index + 1}/${totalItems})`;
        prevBtn.disabled = indexecoratorsToElement?.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.inavBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i;
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ivBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i);
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.idiv");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.inav-injected";
      navBar.iavBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ieateElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i= document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ivBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iions-nav-injected";
      navBar.iclassName = "collections-item-nav-bar collections-nav-injected";
      navBar.i-nav-injected";
      navBar.ilassName = "collections-item-nav-bar collections-nav-injected";
      navBar.i   navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i-item-nav-bar collections-nav-injected";
      navBar.ir.className = "collections-item-nav-bar collections-nav-injected";
      navBar.issName = "collections-item-nav-bar collections-nav-injected";
      navBar.i);
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ictions-item-nav-bar collections-nav-injected";
      navBar.i"collections-item-nav-bar collections-nav-injected";
      navBar.i   navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i= "collections-item-nav-bar collections-nav-injected";
      navBar.i= document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i     navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i= document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.ilement);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i    navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iections-item-nav-bar collections-nav-injected";
      navBar.ions-nav-injected";
      navBar.i"div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.i= "collections-item-nav-bar collections-nav-injected";
      navBar.i "collections-item-nav-bar collections-nav-injected";
      navBar.im-nav-bar collections-nav-injected";
      navBar.iv");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.iem-nav-bar collections-nav-injected";
      navBar.iv-bar collections-nav-injected";
      navBar.is-nav-injected";
      navBar.iar collections-nav-injected";
      navBar.i     navBar.i     navBar.i.(element);
      };

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.inavBar.iar.i
