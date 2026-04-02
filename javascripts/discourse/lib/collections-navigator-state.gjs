let navigatorState = {
  ready: false,
  collectionName: "Collection",
  collectionDesc: "",
  currentItem: null,
  currentIndex: -1,
  totalItems: 0,
  items: [],
};

let eventsBound = false;

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

function extractItemsFromCollectionsSidebar() {
  const sidebarPanel = document.querySelector(
    ".discourse-collections-sidebar-panel"
  );

  if (!sidebarPanel) {
    return null;
  }

  const links = sidebarPanel.querySelectorAll(".collection-sidebar-link");

  const collectionTitleEl = document.querySelector(".collection-sidebar__title");
  const collectionDescEl = document.querySelector(".collection-sidebar__desc");

  const collectionName =
    collectionTitleEl?.textContent?.trim() || "Collection";
  const collectionDesc =
    collectionDescEl?.textContent?.trim() || "";

  const items = Array.from(links).map((link) => {
    const href = link.getAttribute("href");

    let title =
      link.querySelector(".collection-link-content-text")?.textContent?.trim() ||
      link
        .querySelector(".sidebar-section-link-content-text")
        ?.textContent?.trim() ||
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

export function getCollectionsNavigatorState() {
  return navigatorState;
}

export function initializeCollectionsNavigatorState(_api) {
  const data = extractItemsFromCollectionsSidebar();

  if (!data || data.items.length < 2) {
    navigatorState = {
      ready: false,
      collectionName: "Collection",
      collectionDesc: "",
      currentItem: null,
      currentIndex: -1,
      totalItems: 0,
      items: [],
    };
    return;
  }

  const currentPath = window.location.pathname;

  const currentIndex = data.items.findIndex((item) => {
    if (item.external || !item.href) {
      return false;
    }

    try {
      const url = new URL(item.href, window.location.origin);
      return currentPath === url.pathname || currentPath.includes(url.pathname);
    } catch {
      return false;
    }
  });

  navigatorState = {
    ready: currentIndex > -1,
    collectionName: data.collectionName,
    collectionDesc: data.collectionDesc,
    currentItem: currentIndex > -1 ? data.items[currentIndex] : null,
    currentIndex,
    totalItems: data.items.length,
    items: data.items,
  };
}

function openModal() {
  const modal = document.querySelector(".collections-nav-modal-overlay");
  if (modal) {
    modal.style.display = "flex";
  }
}

function closeModal() {
  const modal = document.querySelector(".collections-nav-modal-overlay");
  if (modal) {
    modal.style.display = "none";
  }
}

function navigateRelative(offset) {
  const nextIndex = navigatorState.currentIndex + offset;
  if (nextIndex < 0 || nextIndex >= navigatorState.totalItems) {
    return;
  }

  const item = navigatorState.items[nextIndex];
  if (!item || item.external || !item.href) {
    return;
  }

  window.location.href = item.href;
}

export function ensureCollectionsNavigatorModal(api) {
  let modal = document.querySelector(".collections-nav-modal-overlay");

  if (modal) {
    return;
  }

  modal = document.createElement("div");
  modal.className = "collections-nav-modal-overlay";
  modal.style.display = "none";

  modal.innerHTML = `
    <div class="collections-nav-modal collections-modal-with-content">
      <div class="modal-header">
        <h2 class="modal-title"></h2>
        <button class="modal-close-btn" type="button" aria-label="Close">
          <svg class="fa d-icon d-icon-times svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <use href="#times"></use>
          </svg>
        </button>
      </div>
      <div class="modal-body-split">
        <div class="modal-items-sidebar"></div>
        <div class="modal-content-area">
          <div class="content-header">
            <h3 class="content-title"></h3>
            <div class="content-header-actions"></div>
          </div>
          <div class="cooked-content"></div>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modal);

  modal.querySelector(".modal-close-btn")?.addEventListener("click", closeModal);
  modal.addEventListener("click", (e) => {
    if (e.target === modal) {
      closeModal();
    }
  });

  api.decorateCookedElement(() => {}, {
    id: "collections-navigator-modal",
  });
}

export function bindCollectionsNavigatorEvents(_api) {
  if (eventsBound) {
    return;
  }

  eventsBound = true;

  document.addEventListener("collections:navigator:open", () => {
    openModal();
  });

  document.addEventListener("collections:navigator:previous", () => {
    navigateRelative(-1);
  });

  document.addEventListener("collections:navigator:next", () => {
    navigateRelative(1);
  });

  document.addEventListener("keydown", (e) => {
    const modal = document.querySelector(".collections-nav-modal-overlay");
    const modalOpen = modal && modal.style.display === "flex";

    if (e.key === "Escape" && modalOpen) {
      closeModal();
      return;
    }

    if (e.key === "ArrowLeft") {
      navigateRelative(-1);
    } else if (e.key === "ArrowRight") {
      navigateRelative(1);
    }
  });
}
