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
let modalWired = false;

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
  const currentUrl = window.location.pathname;

  return items.findIndex((item) => {
    if (item.external || !item.href) {
      return false;
    }

    try {
      const hrefUrl = new URL(item.href, window.location.origin);
      return (
        hrefUrl.pathname === currentUrl ||
        currentUrl.includes(hrefUrl.pathname)
      );
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

function scrollSliderToActive(modal) {
  const activeSlider = modal?.querySelector(".slider-item.active");

  if (activeSlider) {
    activeSlider.scrollIntoView({
      behavior: getScrollBehavior(),
      block: "nearest",
      inline: "center",
    });
  }
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

function bindExternalLinkButtons(scope) {
  if (!scope) {
    return;
  }

  scope.querySelectorAll(".collections-external-link-button").forEach((link) => {
    link.addEventListener("click", (e) => e.stopPropagation());
    link.addEventListener("mousedown", (e) => e.stopPropagation());
    link.addEventListener("keydown", (e) => e.stopPropagation());
  });
}

function buildSliderItemHtml(item, idx) {
  return `
    <button
      class="slider-item ${idx === navigatorState.currentIndex ? "active" : ""}"
      data-index="${idx}"
      title="${escapeHtml(item.title)}"
      type="button"
    >
      <span class="slider-item-title">${escapeHtml(item.title)}</span>
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
          <svg class="fa d-icon d-icon-bars svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <use href="#bars"></use>
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

          <div class="topic-slider-container">
            <div class="topic-slider">
              ${navigatorState.items.map(buildSliderItemHtml).join("")}
            </div>
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

  modalWired = false;
  wireModalHandlers(api, modal);
  bindExternalLinkButtons(modal);
}

function wireModalHandlers(api, modal) {
  if (!modal || modalWired) {
    return;
  }

  modalWired = true;
  let sidebarOpen = false;

  const closeBtn = modal.querySelector(".modal-close-btn");
  const sidebarToggle = modal.querySelector(".modal-sidebar-toggle");
  const sidebar = modal.querySelector(".modal-items-sidebar");
  const topicSliderContainer = modal.querySelector(".topic-slider-container");
  const modalContentPrev = modal.querySelector(".modal-content-prev");
  const modalContentNext = modal.querySelector(".modal-content-next");

  closeBtn?.addEventListener("click", hideModal);

  sidebarToggle?.addEventListener("click", () => {
    sidebarOpen = !sidebarOpen;

    if (sidebarOpen) {
      sidebar?.classList.remove("collapsed");
      topicSliderContainer?.classList.add("collapsed");
    } else {
      topicSliderContainer?.classList.remove("collapsed");
      sidebar?.classList.add("collapsed");
    }
  });

  modalContentPrev?.addEventListener("click", () => {
    if (navigatorState.currentIndex > 0) {
      updateModalContent(api, navigatorState.currentIndex - 1);
    }
  });

  modalContentNext?.addEventListener("click", () => {
    if (navigatorState.currentIndex < navigatorState.totalItems - 1) {
      updateModalContent(api, navigatorState.currentIndex + 1);
    }
  });

  modal.querySelectorAll(".collection-item-link").forEach((link) => {
    link.style.cursor = "pointer";

    link.addEventListener("click", () => {
      const index = parseInt(link.getAttribute("data-index"), 10);
      updateModalContent(api, index);
    });

    link.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        const index = parseInt(link.getAttribute("data-index"), 10);
        updateModalContent(api, index);
      }
    });
  });

  modal.querySelectorAll(".slider-item").forEach((item) => {
    item.addEventListener("click", () => {
      const index = parseInt(item.getAttribute("data-index"), 10);
      updateModalContent(api, index);
    });
  });

  modal.addEventListener("click", (e) => {
    if (e.target === modal) {
      hideModal();
    }
  });
}

function navigateToInternalItem(api, index) {
  if (index < 0 || index >= navigatorState.totalItems) {
    return;
  }

  const item = navigatorState.items[index];
  if (!item || item.external || !item.topicId) {
    return;
  }

  fetch(`/t/${item.topicId}.json`)
    .then((response) => response.json())
    .then((data) => {
      document.title = item.title;

      let targetContent = document.querySelector(".topic-post[data-post-number='1'] .cooked");
      if (!targetContent) {
        targetContent = document.querySelector(".topic-body .cooked");
      }
      if (!targetContent) {
        targetContent = document.querySelector(".post-stream .posts .boxed-body");
      }
      if (!targetContent) {
        targetContent = document.querySelector(".post-content");
      }
      if (!targetContent) {
        targetContent = document.querySelector("[data-post-id] .cooked");
      }
      if (!targetContent) {
        targetContent = document.querySelector(".cooked");
      }

      const cooked = data?.post_stream?.posts?.[0]?.cooked;

      if (targetContent && cooked) {
        targetContent.innerHTML = cooked;
        enhanceCooked(api, targetContent);
      }

      if (item.href) {
        history.pushState({}, "", item.href);
      }

      navigatorState.currentIndex = index;
      navigatorState.currentItem = item;

      refreshCollectionsNavigatorUI(api);
    })
    .catch((err) => console.error("Error updating content", err));
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

  setTimeout(() => scrollSliderToActive(modal), 100);

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

  bindExternalLinkButtons(modal);
}, SCROLL_THROTTLE_MS);

export function getCollectionsNavigatorState() {
  return navigatorState;
}

export function initializeCollectionsNavigatorState(_api) {
  updateStateFromPage();
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
}

export function refreshCollectionsNavigatorUI(api) {
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

      navigateToInternalItem(api, navigatorState.currentIndex - 1);
    });

    document.addEventListener("collections:navigator:next", () => {
      if (
        !navigatorState.ready ||
        navigatorState.currentIndex >= navigatorState.totalItems - 1
      ) {
        return;
      }

      navigateToInternalItem(api, navigatorState.currentIndex + 1);
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
          navigateToInternalItem(api, navigatorState.currentIndex - 1);
        } else if (
          e.key === "ArrowRight" &&
          navigatorState.currentIndex < navigatorState.totalItems - 1
        ) {
          lastKeyPress = now;
          e.preventDefault();
          navigateToInternalItem(api, navigatorState.currentIndex + 1);
        }
      }
    });
  }
}
