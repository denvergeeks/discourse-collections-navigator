// Replace the entire contents of javascripts/discourse/api-initializers/collections-navigator.gjs with this:

// Collections Navigation - Modal with Discourse patterns integrated
// FIXED: Robust external URL handling - treats full URLs as external content
import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.24.0", (api) => {
  api.onPageChange(() => {
    setTimeout(() => {
      const sidebarPanel = document.querySelector(".discourse-collections-sidebar-panel");
      const postsContainer = document.querySelector(".posts");
      
      if (!sidebarPanel || !postsContainer) {
        return;
      }
      
      // Remove old nav if exists
      document.querySelectorAll(".collections-nav-injected").forEach(el => el.remove());
      document.querySelectorAll(".collections-nav-modal-overlay").forEach(el => el.remove());
      
      // Extract collection title and description
      const collectionTitleEl = document.querySelector(".collection-sidebar__title");
      const collectionDescEl = document.querySelector(".collection-sidebar__desc");
      const collectionName = collectionTitleEl?.textContent?.trim() || "Collection";
      const collectionDesc = collectionDescEl?.textContent?.trim() || "";
      
      // Extract items from sidebar - ROBUST EXTERNAL URL HANDLING
      const links = sidebarPanel.querySelectorAll(".collection-sidebar-link");
      const items = Array.from(links).map((link) => {
        const href = link.getAttribute("href") || link.dataset.href || "";
        
        // Try multiple selectors to get the title text
        let title = link.querySelector(".collection-link-content-text")?.textContent?.trim();
        if (!title) title = link.querySelector(".sidebar-section-link-content-text")?.textContent?.trim();
        if (!title) title = link.querySelector("[class*='content-text']")?.textContent?.trim();
        if (!title) title = link.textContent?.trim();
        if (!title) title = "Untitled";
        
        // Determine if this is an external full URL
        const isExternalFullUrl = href.startsWith("http://") || href.startsWith("https://");
        
        return { 
          title, 
          href, 
          isExternalFullUrl,
          fullDisplayUrl: href
        };
      });

      if (items.length < 2) return;
      
      // Find current item - improved matching for external URLs
      const currentUrl = window.location.href;
      const currentIndex = items.findIndex(item => {
        if (item.href === currentUrl) return true;
        if (currentUrl.includes(item.href)) return true;
        return false;
      });
      
      if (currentIndex === -1) return;
      
      const currentItem = items[currentIndex];
      const totalItems = items.length;
      
      // Get cooked content from current page
      const getPostContent = () => {
        let content = document.querySelector(".topic-body .cooked");
        return content ? content.innerHTML : "<p>Loading content...</p>";
      };
      
      const cookedContent = getPostContent();
      
      // DISCOURSE PATTERNS INTEGRATION
      const KEYBOARD_THROTTLE_MS = 150;
      const SCROLL_THROTTLE_MS = 50;
      
      function getScrollBehavior() {
        return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ? "auto" : "smooth";
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
      
      // IFRAME SUPPORT FOR EXTERNAL LINKS
function extractExternalLinks(htmlContent) {
  const tempDiv = document.createElement("div");
  tempDiv.innerHTML = htmlContent;

  const links = tempDiv.querySelectorAll("a[href]");
  const externalLinks = [];

  links.forEach((link) => {
    const href = link.getAttribute("href");
    if (!href) {
      return;
    }

    // (2) Do NOT treat internal cooked-content links as iframe candidates
    if (
      href.startsWith("/") ||                    // relative internal
      href.startsWith(window.location.origin) || // absolute internal
      href.startsWith("#")                       // in-page anchors
    ) {
      return;
    }

    // (3) Only true externals become iframe entries
    if (href.startsWith("http://") || href.startsWith("https://")) {
      try {
        const url = new URL(href);
        if (url.hostname !== window.location.hostname) {
          externalLinks.push({
            url: href,
            text: link.textContent?.trim() || href,
          });
        }
      } catch (e) {
        // ignore malformed URL
      }
    }
  });

  return externalLinks;
}


      
      function createIframeDisplay(externalLinks) {
        if (externalLinks.length === 0) return "";
        
        let iframeHtml = `<div class="external-links-iframe-container">`;
        externalLinks.forEach((link, index) => {
          iframeHtml += `
            <div class="iframe-wrapper" data-iframe-index="${index}">
              <div class="iframe-header">
                <span class="iframe-title">${link.text}</span>
                <a href="${link.url}" target="_blank" class="iframe-open-new" title="Open in new tab">
                  <svg class="fa d-icon d-icon-external-link-alt svg-icon svg-string" xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" aria-hidden="true"><use href="#external-link-alt"></use></svg>
                </a>
              </div>
              <div class="iframe-loading">Loading external content...</div>
              <iframe src="${link.url}" class="external-link-iframe" sandbox="allow-scripts allow-same-origin allow-forms allow-popups" loading="lazy" title="${link.text}"></iframe>
              <div class="iframe-error" style="display: none;">
                <p>Unable to display this content in an iframe.</p>
                <a href="${link.url}" target="_blank" class="btn btn-primary">Open in New Tab</a>
              </div>
            </div>
          `;
        });
        iframeHtml += `</div>`;
        return iframeHtml;
      }
      
function setupIframeHandlers(contentArea) {
  const iframes = contentArea.querySelectorAll(".external-link-iframe, .external-topic-iframe");
  
  iframes.forEach((iframe, index) => {
    const wrapper = iframe.closest(".iframe-wrapper, .iframe-container") || iframe.parentElement;
    const loading = wrapper.querySelector(".iframe-loading");
    const error = wrapper.querySelector(".iframe-error");
    
    if (!loading) return;
    
    // Hide loading and show iframe on successful load
    const onIframeLoad = () => {
      console.log(`Iframe ${index} loaded successfully`);
      loading.style.display = "none";
      iframe.style.display = "block";
      iframe.style.height = "600px"; // Set explicit height
    };
    
    // Hide everything and show error on load error
    const onIframeError = () => {
      console.log(`Iframe ${index} failed to load`);
      loading.style.display = "none";
      iframe.style.display = "none";
      if (error) error.style.display = "block";
    };
    
    // Attach events
    iframe.addEventListener("load", onIframeLoad);
    iframe.addEventListener("error", onIframeError);
    
    // Additional timeout check (some sites block iframes silently)
    setTimeout(() => {
      if (loading.style.display !== "none") {
        try {
          // Test if iframe content is accessible
          iframe.contentDocument || iframe.contentWindow.document;
          onIframeLoad();
        } catch (e) {
          console.log(`Iframe ${index} blocked by CORS/X-Frame-Options`);
          onIframeError();
        }
      }
    }, 3000); // Reduced timeout for better UX
  });
}
      
      function processContentWithIframes(htmlContent) {
        const externalLinks = extractExternalLinks(htmlContent);
        const iframeDisplay = createIframeDisplay(externalLinks);
        return iframeDisplay ? htmlContent + iframeDisplay : htmlContent;
      }
      
function loadExternalContent(url) {
  return `
    <div class="external-url-content">
      <div class="external-url-header">
        <h4>External Link: <a href="${url}" target="_blank">${url}</a></h4>
        <a href="${url}" target="_blank" class="btn btn-primary">Open in New Tab</a>
      </div>
      <div class="iframe-container">
        <div class="iframe-loading">Loading external site...</div>
        <iframe src="${url}" class="external-topic-iframe" sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-top-navigation" loading="lazy" title="${url}" style="display: none;"></iframe>
        <div class="iframe-error" style="display: none;">
          <p>This site cannot be displayed in an iframe (likely due to X-Frame-Options security policy).</p>
          <a href="${url}" target="_blank" class="btn btn-primary">Open in New Tab</a>
        </div>
      </div>
    </div>
  `;
}
      
      // CREATE NAVIGATION BAR
      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.innerHTML = `
        <button class="btn btn--primary collections-nav-toggle" title="Open collection navigator" type="button">
          <svg class="fa d-icon d-icon-collection-pip svg-icon fa-width-auto prefix-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#collection-pip"></use></svg>
          <span class="nav-text">${collectionName}: ${currentItem.title} (${currentIndex + 1}/${totalItems})</span>
        </button>
        <div class="collections-quick-nav">
          <button class="btn btn--secondary collections-nav-prev" ${currentIndex === 0 ? 'disabled' : ''} title="Previous (arrow key)" type="button">
            <svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#arrow-left"></use></svg>
          </button>
          <button class="btn btn--secondary collections-nav-next" ${currentIndex === totalItems - 1 ? 'disabled' : ''} title="Next (arrow key)" type="button">
            <svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#arrow-right"></use></svg>
          </button>
        </div>
      `;
      postsContainer.parentNode.insertBefore(navBar, postsContainer);
      
      // CREATE MODAL
      const modal = document.createElement("div");
      modal.className = "collections-nav-modal-overlay";
      
      // Initial content - external URLs get special handling
      const initialContent = currentItem.isExternalFullUrl 
        ? loadExternalContent(currentItem.fullDisplayUrl)
        : processContentWithIframes(cookedContent);
      
      modal.innerHTML = `
        <div class="collections-nav-modal collections-modal-with-content">
          <div class="modal-header">
            <button class="modal-sidebar-toggle btn btn-flat btn--toggle no-text btn-icon narrow-desktop" aria-label="Toggle sidebar" type="button" title="Toggle sidebar">
              <svg class="fa d-icon d-icon-bars svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#bars"></use></svg>
            </button>
            <div class="modal-header-content">
              <h2 class="modal-title">${collectionName}</h2>
              ${collectionDesc ? `<p class="collection-description">${collectionDesc}</p>` : ''}
              <div class="topic-slider-container">
                <div class="topic-slider">
                  ${items.map((item, idx) => `
                    <button class="slider-item ${idx === currentIndex ? 'active' : ''}" data-index="${idx}" title="${item.title}">
                      ${item.title}
                    </button>
                  `).join('')}
                </div>
              </div>
            </div>
            <button class="modal-close-btn" aria-label="Close modal" type="button">
              <span class="d-icon d-icon-times"></span>
            </button>
          </div>
          
          <div class="modal-body-split">
            <div class="modal-items-sidebar collapsed">
              <ul class="collection-items-list">
                ${items.map((item, idx) => `
                  <li class="collection-item ${idx === currentIndex ? 'active' : ''}">
                    <div class="collection-item-link" data-index="${idx}" title="${item.title}">
                      <span class="item-number">${idx + 1}</span>
                      <span class="item-title">${item.title}</span>
                      ${idx === currentIndex ? '<span class="d-icon d-icon-check"></span>' : ''}
                    </div>
                  </li>
                `).join('')}
              </ul>
            </div>
            
            <div class="modal-content-area">
              <div class="content-header">
                <h3 class="content-title">${currentItem.title}</h3>
              </div>
              <div class="cooked-content">
                ${initialContent}
              </div>
            </div>
          </div>
          
          <div class="modal-nav-footer">
            <button class="btn btn--secondary modal-content-prev" title="Previous item" type="button" ${currentIndex === 0 ? 'disabled' : ''}>
              <svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#arrow-left"></use></svg>
              Previous
            </button>
            <div class="modal-paging">
              <span class="paging-text">${currentIndex + 1}/${totalItems}</span>
            </div>
            <button class="btn btn--secondary modal-content-next" title="Next item" type="button" ${currentIndex === totalItems - 1 ? 'disabled' : ''}>
              Next
              <svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#arrow-right"></use></svg>
            </button>
          </div>
        </div>
      `;
      
      document.body.appendChild(modal);
      
      // Setup handlers
      const contentArea = modal.querySelector(".cooked-content");
      setupIframeHandlers(contentArea);
      
      // Rest of the event handlers remain the same...
      const toggleBtn = navBar.querySelector(".collections-nav-toggle");
      const prevBtn = navBar.querySelector(".collections-nav-prev");
      const nextBtn = navBar.querySelector(".collections-nav-next");
      const closeBtn = modal.querySelector(".modal-close-btn");
      const itemLinks = modal.querySelectorAll(".collection-item-link");
      const sliderItems = modal.querySelectorAll(".slider-item");
      const contentTitle = modal.querySelector(".content-title");
      const sidebarToggle = modal.querySelector(".modal-sidebar-toggle");
      const sidebar = modal.querySelector(".modal-items-sidebar");
      const modalContentPrev = modal.querySelector(".modal-content-prev");
      const modalContentNext = modal.querySelector(".modal-content-next");
      const pagingText = modal.querySelector(".paging-text");
      const topicSliderContainer = modal.querySelector(".topic-slider-container");

      let selectedIndex = currentIndex;
      
      const showModal = () => { modal.style.display = "flex"; };
      const hideModal = () => { modal.style.display = "none"; };
      
      const toggleSidebar = () => {
        const sidebarOpen = sidebar.classList.contains("collapsed");
        if (sidebarOpen) {
          sidebar.classList.remove("collapsed");
          topicSliderContainer.classList.add("collapsed");
        } else {
          topicSliderContainer.classList.remove("collapsed");
          sidebar.classList.add("collapsed");
        }
      };
      
      const scrollSliderToActive = () => {
        const activeSlider = modal.querySelector(".slider-item.active");
        if (activeSlider) {
          activeSlider.scrollIntoView({ 
            behavior: getScrollBehavior(), 
            block: "nearest", 
            inline: "center" 
          });
        }
      };

// Sidebar items: external = iframe, internal = cooked-only in modal
const updateModalContent = throttle((index) => {
  if (index < 0 || index >= totalItems) return;

  selectedIndex = index;
  const currentItemData = items[index];

  contentTitle.textContent = currentItemData.title;

  if (currentItemData.isExternalFullUrl) {
    // External sidebar item → iframe in modal
    contentArea.innerHTML = loadExternalContent(currentItemData.fullDisplayUrl);
  } else {
    // Internal sidebar item (collection or subcollection) → cooked-only
    contentArea.innerHTML = processContentWithIframes(cookedContent);
  }

  // Run after either branch
  setupIframeHandlers(contentArea);

  // UI state updates (unchanged)
  pagingText.textContent = `${index + 1}/${totalItems}`;
  modalContentPrev.disabled = index === 0;
  modalContentNext.disabled = index === totalItems - 1;

  sliderItems.forEach((item) => {
    const idx = parseInt(item.getAttribute("data-index"), 10);
    item.classList.toggle("active", idx === index);
  });

  itemLinks.forEach((link) => {
    const idx = parseInt(link.getAttribute("data-index"), 10);
    link.classList.toggle("active", idx === index);
  });

  const navText = navBar.querySelector(".nav-text");
  navText.textContent =
    `${collectionName}: ${currentItemData.title} (${index + 1}/${totalItems})`;

  prevBtn.disabled = index === 0;
  nextBtn.disabled = index === totalItems - 1;

  setTimeout(scrollSliderToActive, 100);
}, SCROLL_THROTTLE_MS);



// After you have `modal`, `contentArea`, `items`, `totalItems`, `updateModalContent` defined:

// Delegated click handler for internal links INSIDE cooked content
const cookedContentEl = modal.querySelector(".cooked-content");

if (cookedContentEl) {
  cookedContentEl.addEventListener("click", (event) => {
    const a = event.target.closest("a[href]");
    if (!a) {
      return;
    }

    // Preserve modified clicks: Ctrl/⌘/Shift or middle mouse should behave normally
    if (
      event.defaultPrevented ||
      event.button !== 0 || // not left click
      event.metaKey ||      // ⌘ on Mac
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }

    const href = a.getAttribute("href");
    if (!href) {
      return;
    }

    const origin = window.location.origin;

    // Normalize to absolute URL for comparison
    let absoluteHref;
    if (href.startsWith("http://") || href.startsWith("https://")) {
      absoluteHref = href;
    } else if (href.startsWith("/")) {
      absoluteHref = origin + href;
    } else if (href.startsWith("#")) {
      // In-page anchors: let them behave as normal
      return;
    } else {
      // Relative path like "t/topic/123"
      absoluteHref = origin + "/" + href.replace(/^\.\//, "");
    }

    // Determine whether it's internal or external relative to current site
    let url;
    try {
      url = new URL(absoluteHref);
    } catch (e) {
      // If URL can't be parsed, let browser handle it
      return;
    }

    const isInternal =
      url.origin === origin || url.hostname === window.location.hostname;

    if (!isInternal) {
      // External cooked-content link → allow default
      // (it will also show up in iframe list via extractExternalLinks)
      return;
    }

    // From here: internal cooked-content link.
    // Try to find a matching sidebar item to show in the modal instead of full nav.
    const matchIndex = items.findIndex((item) => {
      if (!item.href) {
        return false;
      }

      if (item.isExternalFullUrl) {
        // External sidebar items should not be matched here
        return false;
      }

      let itemAbs;
      if (item.href.startsWith("http://") || item.href.startsWith("https://")) {
        itemAbs = item.href;
      } else if (item.href.startsWith("/")) {
        itemAbs = origin + item.href;
      } else {
        itemAbs = origin + "/" + item.href.replace(/^\.\//, "");
      }

      // Loose match: exact URL or URL contains item's path
      return itemAbs === absoluteHref || absoluteHref.startsWith(itemAbs);
    });

    if (matchIndex === -1) {
      // No corresponding sidebar item; let Discourse handle navigation
      return;
    }

    // We have a matching item, so keep user in modal and switch content
    event.preventDefault();
    updateModalContent(matchIndex);
  });
}

      
      // Event listeners (same as before)
      toggleBtn.addEventListener("click", showModal);
      sidebarToggle.addEventListener("click", toggleSidebar);
      closeBtn.addEventListener("click", hideModal);
      
      prevBtn.addEventListener("click", () => {
        if (selectedIndex > 0) updateModalContent(selectedIndex - 1);
      });
      
      nextBtn.addEventListener("click", () => {
        if (selectedIndex < totalItems - 1) updateModalContent(selectedIndex + 1);
      });
      
      modalContentPrev.addEventListener("click", () => {
        if (selectedIndex > 0) updateModalContent(selectedIndex - 1);
      });
      
      modalContentNext.addEventListener("click", () => {
        if (selectedIndex < totalItems - 1) updateModalContent(selectedIndex + 1);
      });
      
      itemLinks.forEach(link => {
        link.style.cursor = "pointer";
        link.addEventListener("click", (e) => {
          const index = parseInt(link.getAttribute("data-index"));
          updateModalContent(index);
        });
      });
      
      sliderItems.forEach(item => {
        item.addEventListener("click", (e) => {
          const index = parseInt(item.getAttribute("data-index"));
          updateModalContent(index);
        });
      });
      
      modal.addEventListener("click", (e) => {
        if (e.target === modal) hideModal();
      });
      
      // Keyboard navigation
      let lastKeyPress = 0;
      document.addEventListener("keydown", (e) => {
        if (modal.style.display === "flex") {
          const now = Date.now();
          if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) return;
          lastKeyPress = now;
          
          if (e.key === "ArrowLeft" && selectedIndex > 0) {
            e.preventDefault();
            updateModalContent(selectedIndex - 1);
          } else if (e.key === "ArrowRight" && selectedIndex < totalItems - 1) {
            e.preventDefault();
            updateModalContent(selectedIndex + 1);
          } else if (e.key === "Escape") {
            e.preventDefault();
            hideModal();
          }
        }
      });
      
    }, 500);
  });
});
