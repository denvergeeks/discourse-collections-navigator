import { tracked } from "@glimmer/tracking";

class CollectionsNavigatorState {
  @tracked ready = false;
  @tracked collectionName = "Collection";
  @tracked collectionDesc = "";
  @tracked currentItem = null;
  @tracked currentIndex = -1;
  @tracked totalItems = 0;
  @tracked items = [];
}

const navigatorState = new CollectionsNavigatorState();

let eventsBound = false;
let keyboardBound = false;
let fallbackMountBound = false;

const KEYBOARD_THROTTLE_MS = 150;
const SCROLL_THROTTLE_MS = 50;
const EXTERNAL_LINK_TITLE = "Click to Open in New Browser Window";

function resetState() {
  navigatorState.ready = false;
  navigatorState.collectionName = "Collection";
  navigatorState.collectionDesc = "";
  navigatorState.currentItem = null;
  navigatorState.currentIndex = -1;
  navigatorState.totalItems = 0;
  navigatorState.items = [];
}

function setStateFromData(data, currentIndex) {
  navigatorState.ready = currentIndex > -1 && data.items.length > 1;
  navigatorState.collectionName = data.collectionName;
  navigatorState.collectionDesc = data.collectionDesc;
  navigatorState.currentItem = currentIndex > -1 ? data.items[currentIndex] : null;
  navigatorState.currentIndex = currentIndex;
  navigatorState.totalItems = data.items.length;
  navigatorState.items = [...data.items];
}

function escapeHtml(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

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

function isExternalUrl(href) {
  if (!href) {
    return false;
  }

  if (href.startsWith("http://") || href.startsWith("https://")) {
    try {
      const url = new URL(href);
      return url.hostname !== window.location.hostname;
    } catch {
      return false;
    }
  }

  return false;
}

function getTopicIdFromHref(href) {
  if (!href) {
    return null;
  }

  let match = href.match(/\/t\/[^/]+\/(\d+)(?:\/)?$/);
  if (match) {
    return match[1];
  }

  match = href.match(/\/t\/(\d+)(?:\/)?$/);
  if (match) {
    return match[1];
  }

  match = href.match(/\/(\d+)(?:\/)?$/);
  if (match) {
    return match[1];
  }

  return null;
}

function getCurrentTopicIdFromPage() {
  const canonical = document.querySelector("link[rel='canonical']")?.href;
  if (canonical) {
    const match = canonical.match(/\/t\/[^/]+\/(\d+)/);
    if (match) {
      return match[1];
    }
  }

  const pathMatch = window.location.pathname.match(/\/t\/[^/]+\/(\d+)/);
  if (pathMatch) {
    return pathMatch[1];
  }

  return null;
}

function externalLinkIconSvg() {
  return `<svg class="fa d-icon d-icon-collections-arrow-up-right-from-square svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#collections-arrow-up-right-from-square"></use></svg>`;
}

function externalLinkButton(url, extraClass = "") {
  if (!url) {
    return "";
  }

  return `
    <a
      href="${escapeHtml(url)}"
      class="collections-external-link-button ${extraClass}"
      target="_blank"
      rel="noopener noreferrer"
      title="${escapeHtml(EXTERNAL_LINK_TITLE)}"
      aria-label="${escapeHtml(EXTERNAL_LINK_TITLE)}"
    >
      ${externalLinkIconSvg()}
    </a>
  `;
}

function extractCollectionItems() {
  const sidebarPanel = document.querySelector(".discourse-collections-sidebar-panel");

  if (!sidebarPanel) {
    return null;
  }

  const links = sidebarPanel.querySelectorAll(".collection-sidebar-link");
  if (!links.length) {
    return null;
  }

  const collectionTitleEl = document.querySelector(".collection-sidebar__title");
  const collectionDescEl = document.querySelector(".collection-sidebar__desc");

  const collectionName = collectionTitleEl?.textContent?.trim() || "Collection";
  const collectionDesc = collectionDescEl?.textContent?.trim() || "";

  const items = Array.from(links).map((link) => {
    const href = link.getAttribute("href");

    let title =
      link.querySelector(".collection-link-content-text")?.textContent?.trim() ||
      link.querySelector(".sidebar-section-link-content-text")?.textContent?.trim() ||
      link.querySelector("[class*='content-text']")?.textContent?.trim() ||
      link.textContent?.trim() ||
      "Untitled";

    const external = isExternalUrl(href);
    const topicId = !external ? getTopicIdFromHref(href) : null;

    return {
      title,
      href,
      topicId,
      external,
    };
  });

  return {
    collectionName,
    collectionDesc,
    items,
  };
}

function getCurrentIndex(items) {
  const currentTopicId = getCurrentTopicIdFromPage();

  if (currentTopicId) {
    const idx = items.findIndex(
      (item) => !item.external && item.topicId === currentTopicId
    );

    if (idx > -1) {
      return idx;
    }
  }

  const currentPath = window.location.pathname;

  return items.findIndex((item) => {
    if (item.external || !item.href) {
      return false;
    }

    try {
      const hrefUrl = new URL(item.href, window.location.origin);
      return hrefUrl.pathname === currentPath;
    } catch {
      return false;
    }
  });
}

function updateStateFromPage() {
  const data = extractCollectionItems();

  if (!data || data.items.length < 2) {
    resetState();
    return;
  }

  const currentIndex = getCurrentIndex(data.items);

  if (currentIndex === -1) {
    resetState();
    return;
  }

  setStateFromData(data, currentIndex);
}

function getModal() {
  return document.querySelector(".collections-nav-modal-overlay");
}

function getFallbackMount() {
  return document.querySelector(".collections-nav-fallback-mount");
}

function ensureFallbackMountElement() {
  let mount = getFallbackMount();

  if (mount) {
    return mount;
  }

  const topicTitle = document.querySelector("#topic-title");
  const mainOutlet = document.querySelector("#main-outlet");
  const postsContainer = document.querySelector(".posts");

  if (topicTitle?.parentNode) {
    mount = document.createElement("div");
    mount.className = "collections-nav-fallback-mount";
    topicTitle.insertAdjacentElement("afterend", mount);
    return mount;
  }

  if (postsContainer?.parentNode) {
    mount = document.createElement("div");
    mount.className = "collections-nav-fallback-mount";
    postsContainer.parentNode.insertBefore(mount, postsContainer);
    return mount;
  }

  if (mainOutlet) {
    mount = document.createElement("div");
    mount.className = "collections-nav-fallback-mount";
    mainOutlet.prepend(mount);
    return mount;
  }

  return null;
}

function renderFallbackNavBar() {
  const mount = ensureFallbackMountElement();

  if (!mount) {
    return;
  }

  if (!navigatorState.ready || !navigatorState.currentItem) {
    mount.innerHTML = "";
    return;
  }

  mount.innerHTML = `
    <div class="collections-item-nav-bar collections-nav-injected collections-nav-fallback-render">
      <button class="btn btn--primary collections-nav-toggle" type="button" title="Open collection navigator">
        <svg
          class="fa d-icon d-icon-collection-pip svg-icon fa-width-auto prefix-icon svg-string"
          width="1em"
          height="1em"
          aria-hidden="true"
          xmlns="http://www.w3.org/2000/svg"
        >
          <use href="#collection-pip"></use>
        </svg>
        <span class="nav-text">${escapeHtml(
          `${navigatorState.collectionName}: ${navigatorState.currentItem.title} (${navigatorState.currentIndex + 1}/${navigatorState.totalItems})`
        )}</span>
      </button>

      <div class="collections-quick-nav">
        <button
          class="btn btn--secondary collections-nav-prev"
          type="button"
          title="Previous (arrow key)"
          ${navigatorState.currentIndex === 0 ? "disabled" : ""}
        >
          <svg
            class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string"
            width="1em"
            height="1em"
            aria-hidden="true"
            xmlns="http://www.w3.org/2000/svg"
          >
            <use href="#arrow-left"></use>
          </svg>
        </button>

        <button
          class="btn btn--secondary collections-nav-next"
          type="button"
          title="Next (arrow key)"
          ${navigatorState.currentIndex === navigatorState.totalItems - 1 ? "disabled" : ""}
        >
          <svg
            class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string"
            width="1em"
            height="1em"
            aria-hidden="true"
            xmlns="http://www.w3.org/2000/svg"
          >
            <use href="#arrow-right"></use>
          </svg>
        </button>
      </div>
    </div>
  `;
}

function hideModal() {
  const modal = getModal();
  if (modal) {
    modal.style.display = "none";
  }
}

function showModal() {
  const modal = getModal();
  if (modal) {
    modal.style.display = "flex";
  }
}

function updateSliderEdgeState(modal) {
  const shell = modal?.querySelector(".topic-slider-shell");
  const container = modal?.querySelector(".topic-slider-container");
  const prevButton = modal?.querySelector(".topic-slider-edge-prev");
  const nextButton = modal?.querySelector(".topic-slider-edge-next");

  if (!shell || !container) {
    return;
  }

  const maxScrollLeft = container.scrollWidth - container.clientWidth;
  const current = Math.max(0, container.scrollLeft);
  const threshold = 2;

  const atStart = current <= threshold;
  const atEnd = current >= maxScrollLeft - threshold || maxScrollLeft <= threshold;
  const isScrollable = maxScrollLeft > threshold;

  shell.classList.toggle("at-start", atStart);
  shell.classList.toggle("at-end", atEnd);
  shell.classList.toggle("is-scrollable", isScrollable);

  if (prevButton) {
    prevButton.disabled = atStart || !isScrollable;
    prevButton.setAttribute("aria-hidden", atStart || !isScrollable ? "true" : "false");
  }

  if (nextButton) {
    nextButton.disabled = atEnd || !isScrollable;
    nextButton.setAttribute("aria-hidden", atEnd || !isScrollable ? "true" : "false");
  }
}

function bindSliderScrollState(modal) {
  const container = modal?.querySelector(".topic-slider-container");

  if (!container || container.dataset.edgeStateBound === "true") {
    updateSliderEdgeState(modal);
    return;
  }

  container.dataset.edgeStateBound = "true";

  const onScroll = throttle(() => {
    updateSliderEdgeState(modal);
  }, 30);

  container.addEventListener("scroll", onScroll);
  window.addEventListener("resize", onScroll);

  updateSliderEdgeState(modal);
}

function scrollSliderToActive(modal) {
  const activeSlider = modal?.querySelector(".slider-item.active");

  if (activeSlider) {
    activeSlider.scrollIntoView({
      behavior: getScrollBehavior(),
      block: "nearest",
      inline: "center",
    });
  }

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      updateSliderEdgeState(modal);
    });
  });
}

function getSliderScrollStep(modal) {
  const container = modal?.querySelector(".topic-slider-container");
  if (!container) {
    return 0;
  }

  return Math.max(160, Math.round(container.clientWidth * 0.72));
}

function scrollSliderByDirection(modal, direction) {
  const container = modal?.querySelector(".topic-slider-container");
  if (!container) {
    return;
  }

  const amount = getSliderScrollStep(modal) * direction;

  container.scrollBy({
    left: amount,
    behavior: getScrollBehavior(),
  });

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      updateSliderEdgeState(modal);
    });
  });
}

function getPostContentNode() {
  let content = document.querySelector(".topic-post[data-post-number='1'] .cooked");

  if (!content) {
    content = document.querySelector(".topic-body .cooked");
  }

  if (!content) {
    return null;
  }

  return content.cloneNode(true);
}

function enhanceCooked(api, element) {
  if (!element) {
    return;
  }

  api.decorateCookedElement(() => {}, {
    id: "collections-navigator-modal",
  });

  api.applyDecoratorsToElement?.(element);
}

function adjustIframe(iframe, wrapper) {
  if (!iframe || !wrapper) {
    return;
  }

  const rect = wrapper.getBoundingClientRect();
  const offsetTop = rect.top + window.scrollY;
  const offsetLeft = rect.left + window.scrollX;

  wrapper.style.height = `calc(100vh - ${offsetTop}px)`;

  iframe.style.position = "absolute";
  iframe.style.top = "0";
  iframe.style.left = offsetLeft > 0 ? `-${offsetLeft}px` : "0";
  iframe.style.width = `${wrapper.offsetWidth}px`;
  iframe.style.height = "100%";
  iframe.style.border = "none";
  iframe.style.display = "block";

  wrapper.style.visibility = "visible";
}

function setupIframeHandlers(container) {
  const iframe = container.querySelector(".external-topic-iframe");
  const loadingDiv = container.querySelector(".iframe-loading");
  const wrapper = container.querySelector(
    ".cooked-content.external-url-content-wrapper"
  );

  if (!iframe) {
    return;
  }

  const onResize = throttle(() => adjustIframe(iframe, wrapper), 100);

  const onLoad = () => {
    if (loadingDiv) {
      loadingDiv.style.display = "none";
    }

    adjustIframe(iframe, wrapper);
    window.addEventListener("resize", onResize);
  };

  const onError = () => {
    if (loadingDiv) {
      loadingDiv.style.display = "none";
    }

    if (wrapper) {
      wrapper.style.visibility = "visible";
    }

    iframe.style.display = "none";
    window.removeEventListener("resize", onResize);
  };

  iframe.addEventListener("load", onLoad);
  iframe.addEventListener("error", onError);

  setTimeout(() => {
    if (loadingDiv && loadingDiv.style.display !== "none") {
      try {
        iframe.contentWindow.location.href;
        onLoad();
      } catch {
        onError();
      }
    }
  }, 5000);
}

function loadExternalContent(url) {
  return `
    <div class="external-url-header">
      <h4>
        <a
          href="${escapeHtml(url)}"
          target="_blank"
          rel="noopener noreferrer"
          title="${escapeHtml(EXTERNAL_LINK_TITLE)}"
          class="external-url-link"
        >
          ${escapeHtml(url.replace(/^https?:\/\//, ""))}
          ${externalLinkIconSvg()}
        </a>
      </h4>
    </div>
    <div class="iframe-loading">Loading external content...</div>
    <iframe
      src="${escapeHtml(url)}"
      class="external-topic-iframe"
      sandbox="allow-same-origin allow-scripts allow-popups allow-forms allow-downloads allow-top-navigation"
      loading="lazy"
      title="External content: ${escapeHtml(url)}"
    ></iframe>
  `;
}

function buildSliderItemHtml(item, idx) {
  const isActive = idx === navigatorState.currentIndex;

  return `
    <button
      class="slider-item ${isActive ? "active" : ""}"
      data-index="${idx}"
      title="${escapeHtml(item.title)}"
      type="button"
    >
      <span class="slider-item-title">${escapeHtml(item.title)}</span>
      ${isActive ? `<span class="slider-item-count">${idx + 1}/${navigatorState.totalItems}</span>` : ""}
      ${item.external ? externalLinkButton(item.href, "in-slider") : ""}
    </button>
  `;
}

function buildSidebarItemHtml(item, idx) {
  return `
    <li class="collection-item ${idx === navigatorState.currentIndex ? "active" : ""}">
      <div
        class="collection-item-link ${item.external ? "external-link" : ""}"
        data-index="${idx}"
        title="${escapeHtml(item.title)}"
        role="button"
        tabindex="0"
      >
        <span class="item-number">${idx + 1}</span>
        <span class="item-title">${escapeHtml(item.title)}</span>
        ${idx === navigatorState.currentIndex ? '<span class="d-icon d-icon-check"></span>' : ""}
        ${item.external ? externalLinkButton(item.href, "in-sidebar") : ""}
      </div>
    </li>
  `;
}

function renderModalChrome(api) {
  const modal = getModal();

  if (!modal || !navigatorState.ready || !navigatorState.currentItem) {
    return;
  }

  const cookedNode = getPostContentNode();
  const cookedContent = cookedNode?.outerHTML || "<p>Loading content...</p>";

  modal.innerHTML = `
    <div class="collections-nav-modal collections-modal-with-content">
      <div class="modal-header">
        <button
          class="modal-sidebar-toggle btn btn-flat btn--toggle no-text btn-icon narrow-desktop"
          aria-label="Toggle sidebar"
          type="button"
          title="Toggle sidebar"
        >
          <svg class="fa d-icon d-icon-discourse-sidebar svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <use href="#discourse-sidebar"></use>
          </svg>
        </button>

        <div class="modal-header-content">
          <h2 class="modal-title">${escapeHtml(navigatorState.collectionName)}</h2>
          ${
            navigatorState.collectionDesc
              ? `<p class="collection-description">${escapeHtml(
                  navigatorState.collectionDesc
                )}</p>`
              : ""
          }

          <div class="topic-slider-shell">
            <button
              class="topic-slider-edge topic-slider-edge-prev"
              type="button"
              title="Scroll slider left"
            >
              <svg
                class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string"
                width="1em"
                height="1em"
                aria-hidden="true"
                xmlns="http://www.w3.org/2000/svg"
              >
                <use href="#arrow-left"></use>
              </svg>
            </button>

            <div class="topic-slider-container">
              <div class="topic-slider">
                ${navigatorState.items.map(buildSliderItemHtml).join("")}
              </div>
            </div>

            <button
              class="topic-slider-edge topic-slider-edge-next"
              type="button"
              title="Scroll slider right"
            >
              <svg
                class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string"
                width="1em"
                height="1em"
                aria-hidden="true"
                xmlns="http://www.w3.org/2000/svg"
              >
                <use href="#arrow-right"></use>
              </svg>
            </button>
          </div>
        </div>

        <button class="modal-close-btn" aria-label="Close modal" type="button">
          <svg class="fa d-icon d-icon-times svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <use href="#times"></use>
          </svg>
        </button>
      </div>

      <div class="modal-body-split">
        <div class="modal-items-sidebar collapsed">
          <ul class="collection-items-list">
            ${navigatorState.items.map(buildSidebarItemHtml).join("")}
          </ul>
        </div>

        <div class="modal-content-area">
          <div class="content-header">
            <h3 class="content-title">${escapeHtml(navigatorState.currentItem.title)}</h3>
            <div class="content-header-actions"></div>
          </div>

          <div class="cooked-content">
            ${cookedContent}
          </div>
        </div>
      </div>

      <div class="modal-nav-footer">
        <button
          class="btn btn--secondary modal-content-prev"
          title="Previous item"
          type="button"
          ${navigatorState.currentIndex === 0 ? "disabled" : ""}
        >
          <svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <use href="#arrow-left"></use>
          </svg>
          Previous
        </button>

        <div class="modal-paging">
          <span class="paging-text">${navigatorState.currentIndex + 1}/${navigatorState.totalItems}</span>
        </div>

        <button
          class="btn btn--secondary modal-content-next"
          title="Next item"
          type="button"
          ${navigatorState.currentIndex === navigatorState.totalItems - 1 ? "disabled" : ""}
        >
          Next
          <svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <use href="#arrow-right"></use>
          </svg>
        </button>
      </div>
    </div>
  `;

  const contentArea = modal.querySelector(".cooked-content");
  if (cookedNode && contentArea) {
    contentArea.innerHTML = "";
    contentArea.appendChild(cookedNode);
  } else {
    enhanceCooked(api, contentArea);
  }

  bindSliderScrollState(modal);
  updateSliderEdgeState(modal);
}

function clickExistingCollectionLink(item) {
  if (!item?.href) {
    return false;
  }

  const links = document.querySelectorAll(".discourse-collections-sidebar-panel .collection-sidebar-link");

  const match = Array.from(links).find((link) => {
    const href = link.getAttribute("href");
    if (!href) {
      return false;
    }

    try {
      const a = new URL(href, window.location.origin);
      const b = new URL(item.href, window.location.origin);
      return a.pathname === b.pathname;
    } catch {
      return href === item.href;
    }
  });

  if (!match) {
    return false;
  }

  match.click();
  return true;
}

function navigateToInternalItem(index) {
  if (index < 0 || index >= navigatorState.totalItems) {
    return;
  }

  const item = navigatorState.items[index];
  if (!item || item.external) {
    return;
  }

  if (clickExistingCollectionLink(item)) {
    return;
  }

  if (item.href) {
    window.location.pathname = new URL(item.href, window.location.origin).pathname;
  }
}

const updateModalContent = throttle((api, index) => {
  const modal = getModal();

  if (!modal) {
    return;
  }

  if (index < 0 || index >= navigatorState.totalItems) {
    return;
  }

  const item = navigatorState.items[index];
  const contentTitle = modal.querySelector(".content-title");
  const contentHeaderActions = modal.querySelector(".content-header-actions");
  const contentArea = modal.querySelector(".cooked-content");
  const pagingText = modal.querySelector(".paging-text");
  const modalContentPrev = modal.querySelector(".modal-content-prev");
  const modalContentNext = modal.querySelector(".modal-content-next");
  const sliderItems = modal.querySelectorAll(".slider-item");
  const itemLinks = modal.querySelectorAll(".collection-item-link");

  if (!item || !contentTitle || !contentHeaderActions || !contentArea) {
    return;
  }

  navigatorState.currentIndex = index;
  navigatorState.currentItem = item;

  contentTitle.textContent = item.title;
  contentHeaderActions.innerHTML = "";
  pagingText.textContent = `${index + 1}/${navigatorState.totalItems}`;
  modalContentPrev.disabled = index === 0;
  modalContentNext.disabled = index === navigatorState.totalItems - 1;

  sliderItems.forEach((sliderItem, idx) =>
    sliderItem.classList.toggle("active", idx === index)
  );

  itemLinks.forEach((link, idx) =>
    link.classList.toggle("active", idx === index)
  );

  sliderItems.forEach((sliderItem, idx) => {
    let count = sliderItem.querySelector(".slider-item-count");

    if (idx === index) {
      if (!count) {
        count = document.createElement("span");
        count.className = "slider-item-count";
        sliderItem.querySelector(".slider-item-title")?.after(count);
      }
      count.textContent = `${idx + 1}/${navigatorState.totalItems}`;
    } else if (count) {
      count.remove();
    }
  });

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      scrollSliderToActive(modal);
    });
  });

  if (item.external) {
    modal.classList.add("external-url-active");
    contentArea.classList.add("external-url-content-wrapper");
    contentArea.innerHTML = loadExternalContent(item.href);
    setupIframeHandlers(contentArea);

    contentHeaderActions.innerHTML = `
      <a
        href="${escapeHtml(item.href)}"
        target="_blank"
        rel="noopener noreferrer"
        title="${escapeHtml(EXTERNAL_LINK_TITLE)}"
        class="btn btn-primary collections-open-external-button"
      >
        ${externalLinkIconSvg()}
        Open in New Tab
      </a>
    `;
  } else {
    modal.classList.remove("external-url-active");
    contentArea.classList.remove("external-url-content-wrapper");
    contentArea.style.visibility = "";
    contentArea.style.height = "";
    contentArea.innerHTML = "<p>Loading...</p>";

    if (item.topicId) {
      fetch(`/t/${item.topicId}.json`)
        .then((r) => r.json())
        .then((data) => {
          const cooked = data?.post_stream?.posts?.[0]?.cooked;
          contentArea.innerHTML = cooked || "<p>No content</p>";
          enhanceCooked(api, contentArea);
        })
        .catch(() => {
          contentArea.innerHTML = "<p>Error loading</p>";
        });
    }
  }
}, SCROLL_THROTTLE_MS);

function bindDelegatedModalEvents(api) {
  const modal = getModal();
  if (!modal || modal.dataset.collectionsBound === "true") {
    return;
  }

  modal.dataset.collectionsBound = "true";

  modal.addEventListener("click", (e) => {
    if (e.target === modal) {
      hideModal();
      return;
    }

    const closeBtn = e.target.closest(".modal-close-btn");
    if (closeBtn) {
      hideModal();
      return;
    }

    const sidebarToggle = e.target.closest(".modal-sidebar-toggle");
    if (sidebarToggle) {
      const modalRoot = modal.querySelector(".collections-nav-modal");
      modalRoot?.classList.toggle("collections-sidebar-open");
      return;
    }

    const prevBtn = e.target.closest(".modal-content-prev");
    if (prevBtn && navigatorState.currentIndex > 0) {
      updateModalContent(api, navigatorState.currentIndex - 1);
      return;
    }

    const nextBtn = e.target.closest(".modal-content-next");
    if (
      nextBtn &&
      navigatorState.currentIndex < navigatorState.totalItems - 1
    ) {
      updateModalContent(api, navigatorState.currentIndex + 1);
      return;
    }

    const sliderPrev = e.target.closest(".topic-slider-edge-prev");
    if (sliderPrev) {
      const modalRoot = getModal();
      scrollSliderByDirection(modalRoot, -1);
      return;
    }

    const sliderNext = e.target.closest(".topic-slider-edge-next");
    if (sliderNext) {
      const modalRoot = getModal();
      scrollSliderByDirection(modalRoot, 1);
      return;
    }

    const sliderItem = e.target.closest(".slider-item");
    if (sliderItem) {
      const index = parseInt(sliderItem.getAttribute("data-index"), 10);
      updateModalContent(api, index);
      return;
    }

    const itemLink = e.target.closest(".collection-item-link");
    if (itemLink) {
      const index = parseInt(itemLink.getAttribute("data-index"), 10);
      updateModalContent(api, index);
    }
  });

  modal.addEventListener("keydown", (e) => {
    const itemLink = e.target.closest(".collection-item-link");
    if (itemLink && (e.key === "Enter" || e.key === " ")) {
      e.preventDefault();
      const index = parseInt(itemLink.getAttribute("data-index"), 10);
      updateModalContent(api, index);
    }
  });
}

function bindFallbackMountEvents() {
  if (fallbackMountBound) {
    return;
  }

  fallbackMountBound = true;

  document.addEventListener("click", (e) => {
    const root = e.target.closest(".collections-nav-fallback-render");
    if (!root) {
      return;
    }

    const toggle = e.target.closest(".collections-nav-toggle");
    if (toggle) {
      document.dispatchEvent(
        new CustomEvent("collections:navigator:open", { bubbles: true })
      );
      return;
    }

    const prev = e.target.closest(".collections-nav-prev");
    if (prev) {
      document.dispatchEvent(
        new CustomEvent("collections:navigator:previous", { bubbles: true })
      );
      return;
    }

    const next = e.target.closest(".collections-nav-next");
    if (next) {
      document.dispatchEvent(
        new CustomEvent("collections:navigator:next", { bubbles: true })
      );
    }
  });
}

export function getCollectionsNavigatorState() {
  return navigatorState;
}

export function initializeCollectionsNavigatorState(_api) {
  updateStateFromPage();
}

export function ensureCollectionsNavigatorMount() {
  ensureFallbackMountElement();
  bindFallbackMountEvents();
}

export function ensureCollectionsNavigatorModal(api) {
  let modal = getModal();

  if (!modal) {
    modal = document.createElement("div");
    modal.className = "collections-nav-modal-overlay";
    modal.style.display = "none";
    document.body.appendChild(modal);
  }

  if (!navigatorState.ready) {
    modal.innerHTML = "";
    return;
  }

  renderModalChrome(api);
  bindDelegatedModalEvents(api);
}

export function refreshCollectionsNavigatorUI(api) {
  renderFallbackNavBar();

  const modal = getModal();

  if (!navigatorState.ready) {
    if (modal) {
      modal.style.display = "none";
      modal.innerHTML = "";
    }
    return;
  }

  if (modal && modal.innerHTML.trim() !== "") {
    const isVisible = modal.style.display === "flex";
    renderModalChrome(api);
    bindDelegatedModalEvents(api);

    if (isVisible) {
      modal.style.display = "flex";
      updateModalContent(api, navigatorState.currentIndex);
    }
  }
}

export function bindCollectionsNavigatorEvents(api) {
  if (!eventsBound) {
    eventsBound = true;

    document.addEventListener("collections:navigator:open", () => {
      if (!navigatorState.ready) {
        return;
      }

      ensureCollectionsNavigatorModal(api);
      showModal();
      updateModalContent(api, navigatorState.currentIndex);
    });

    document.addEventListener("collections:navigator:previous", () => {
      if (!navigatorState.ready || navigatorState.currentIndex <= 0) {
        return;
      }

      navigateToInternalItem(navigatorState.currentIndex - 1);
    });

    document.addEventListener("collections:navigator:next", () => {
      if (
        !navigatorState.ready ||
        navigatorState.currentIndex >= navigatorState.totalItems - 1
      ) {
        return;
      }

      navigateToInternalItem(navigatorState.currentIndex + 1);
    });
  }

  if (!keyboardBound) {
    keyboardBound = true;

    let lastKeyPress = 0;

    document.addEventListener("keydown", (e) => {
      if (!navigatorState.ready) {
        return;
      }

      const now = Date.now();
      if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
        return;
      }

      const modal = getModal();
      const modalVisible = modal && modal.style.display === "flex";

      if (modalVisible) {
        if (e.key === "ArrowLeft" && navigatorState.currentIndex > 0) {
          lastKeyPress = now;
          e.preventDefault();
          updateModalContent(api, navigatorState.currentIndex - 1);
        } else if (
          e.key === "ArrowRight" &&
          navigatorState.currentIndex < navigatorState.totalItems - 1
        ) {
          lastKeyPress = now;
          e.preventDefault();
          updateModalContent(api, navigatorState.currentIndex + 1);
        } else if (e.key === "Escape") {
          lastKeyPress = now;
          e.preventDefault();
          hideModal();
        }
      } else {
        if (e.key === "ArrowLeft" && navigatorState.currentIndex > 0) {
          lastKeyPress = now;
          e.preventDefault();
          navigateToInternalItem(navigatorState.currentIndex - 1);
        } else if (
          e.key === "ArrowRight" &&
          navigatorState.currentIndex < navigatorState.totalItems - 1
        ) {
          lastKeyPress = now;
          e.preventDefault();
          navigateToInternalItem(navigatorState.currentIndex + 1);
        }
      }
    });

    window.addEventListener(
      "resize",
      throttle(() => {
        renderFallbackNavBar();
      }, 100)
    );
  }
}
