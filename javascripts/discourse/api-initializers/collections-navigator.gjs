// Collections Navigation - Modal with Discourse patterns integrated
// Restores: sidebar, topic slider, paging buttons, title/description
// Adds: Discourse carousel patterns for accessibility and performance
// ADDED: iframe support for external links

import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.24.0", (api) => {
  api.onPageChange(() => {

let links, items, currentIndex, currentItem, totalItems;

    setTimeout(() => {
      const sidebarPanel = document.querySelector(".discourse-collections-sidebar-panel");
      const postsContainer = document.querySelector(".posts");

      if (!sidebarPanel || !postsContainer) {
        return;
      }

  links = sidebarPanel.querySelectorAll(".collection-sidebar-link");

      // Remove old nav if exists
      document.querySelectorAll(".collections-nav-injected").forEach(el => el.remove());
      document.querySelectorAll(".collections-nav-modal-overlay").forEach(el => el.remove());

      // Extract collection title and description
      const collectionTitleEl = document.querySelector(".collection-sidebar__title");
      const collectionDescEl = document.querySelector(".collection-sidebar__desc");
      const collectionName = collectionTitleEl?.textContent?.trim() || "Collection";
      const collectionDesc = collectionDescEl?.textContent?.trim() || "";

      // ================================================================
      // HELPER: Detect external URL
      // ================================================================
      const isExternalUrl = (href) => {
        if (!href) return false;
        // Check if it's an absolute URL with protocol
        if (href.startsWith('http://') || href.startsWith('https://')) {
          // Check if it's NOT the current domain
          try {
            const url = new URL(href);
            return url.hostname !== window.location.hostname;
          } catch (e) {
            return false;
          }
        }
        return false;
      };

// Extract items from sidebar - FIXED regex
const items = Array.from(links).map((link) => {
  const href = link.getAttribute("href");
  
  let title = link.querySelector(".collection-link-content-text")?.textContent?.trim();
  if (!title) title = link.querySelector(".sidebar-section-link-content-text")?.textContent?.trim();
  if (!title) title = link.querySelector("[class*='content-text']")?.textContent?.trim();
  if (!title) title = link.textContent?.trim();
  if (!title) title = "Untitled";

  const external = isExternalUrl(href);
  
  // ✅ FIXED REGEX
  const idMatch = href.match(/\/(\d+)$/);
  const topicId = !external && idMatch ? idMatch[1] : null;

  return { title, href, topicId, external };
});


      if (items.length < 2) return;

      // Find current item
      const currentUrl = window.location.pathname;
      const currentIndex = items.findIndex(item => {
        if (item.external) {
          return false; // External links won't match current page
        }
        return currentUrl.includes(item.href.split("/")[2]);
      });

      if (currentIndex === -1) return;

      const currentItem = items[currentIndex];
      const totalItems = items.length;

      // Get cooked content from current page
      const getPostContent = () => {
        let content = document.querySelector(".topic-body .cooked");
        if (!content) content = document.querySelector(".topic-body .cooked");
        return content ? content.innerHTML : "<p>Loading content...</p>";
      };

      const cookedContent = getPostContent();

      // ================================================================
      // DISCOURSE PATTERNS INTEGRATION
      // ================================================================

      // Pattern #1: Constants
      const KEYBOARD_THROTTLE_MS = 150;
      const SCROLL_THROTTLE_MS = 50;

      // Pattern #2: Scroll behavior with reduced-motion support
      function getScrollBehavior() {
        return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
          ? "auto"
          : "smooth";
      }

      // Pattern #5: Throttle helper
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

      // ================================================================
      // CREATE NAVIGATION BAR (Top of page)
      // ================================================================

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

      // ================================================================
      // CREATE MODAL WITH ALL FEATURES
      // ================================================================

      const modal = document.createElement("div");
      modal.className = "collections-nav-modal-overlay";
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
                      ${item.external ? '<svg class="fa d-icon d-icon-external-link-alt svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#external-link-alt"></use></svg> ' : ''}${item.title}
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
                    <div class="collection-item-link ${item.external ? 'external-link' : ''}" data-index="${idx}" title="${item.title}">
                      <span class="item-number">${idx + 1}</span>
                      <span class="item-title">${item.title}</span>
                      ${idx === currentIndex ? '<span class="d-icon d-icon-check"></span>' : ''}
                      ${item.external ? '<span class="d-icon d-icon-external-link-alt"></span>' : ''}
                    </div>
                  </li>
                `).join('')}
              </ul>
            </div>
            <div class="modal-content-area">
              <div class="content-header">
                <h3 class="content-title">${currentItem.title}</h3>
                <div class="content-header-actions"></div>
              </div>
              <div class="cooked-content">
                ${cookedContent}
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

      // Get all elements
      const toggleBtn = navBar.querySelector(".collections-nav-toggle");
      const prevBtn = navBar.querySelector(".collections-nav-prev");
      const nextBtn = navBar.querySelector(".collections-nav-next");
      const closeBtn = modal.querySelector(".modal-close-btn");
      const itemLinks = modal.querySelectorAll(".collection-item-link");
      const sliderItems = modal.querySelectorAll(".slider-item");
      const contentArea = modal.querySelector(".cooked-content");
      const contentTitle = modal.querySelector(".content-title");
      const contentHeaderActions = modal.querySelector(".content-header-actions");
      const sidebarToggle = modal.querySelector(".modal-sidebar-toggle");
      const sidebar = modal.querySelector(".modal-items-sidebar");
      const modalContentPrev = modal.querySelector(".modal-content-prev");
      const modalContentNext = modal.querySelector(".modal-content-next");
      const pagingText = modal.querySelector(".paging-text");
      const topicSliderContainer = modal.querySelector(".topic-slider-container");
      const topicSlider = modal.querySelector(".topic-slider");

      let selectedIndex = currentIndex;
      let sidebarOpen = false;

      // Modal show/hide
      const showModal = () => {
        modal.style.display = "flex";
      };

      const hideModal = () => {
        modal.style.display = "none";
      };

      // Sidebar toggle
      const toggleSidebar = () => {
        sidebarOpen = !sidebarOpen;
        if (sidebarOpen) {
          sidebar.classList.remove("collapsed");
          topicSliderContainer.classList.add("collapsed");
        } else {
          topicSliderContainer.classList.remove("collapsed");
          sidebar.classList.add("collapsed");
        }
      };

      // Scroll slider to active item (Pattern #2)
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


      // ================================================================
      // UPDATE PAGE IN PLACE / INLINE
      // ================================================================

      // Update page content (navigates to new URL) - only for internal links
      const updatePageContent = (index) => {
        if (index < 0 || index >= totalItems) return;
        
        // Skip navigation for external links
        if (items[index].external) {
          console.log("Cannot navigate to external link in page view");
          return;
        }
        
        selectedIndex = index;

        // Update nav bar
        const navText = navBar.querySelector(".nav-text");
        navText.textContent = `${collectionName}: ${items[index].title} (${index + 1}/${totalItems})`;

        // Update prev/next button disabled states
        prevBtn.disabled = (index === 0);
        nextBtn.disabled = (index === totalItems - 1);

        // Fetch new topic content via API
        if (items[index].topicId) {
          fetch(`/t/${items[index].topicId}.json`)
            .then(response => response.json())
            .then(data => {
              // Update page title
              document.title = items[index].title;

              // Update the post content on the page
              let targetContent = document.querySelector(".post-stream .posts .boxed-body");
              if (!targetContent) targetContent = document.querySelector(".posts .boxed-body");
              if (!targetContent) targetContent = document.querySelector(".post-content");
              if (!targetContent) targetContent = document.querySelector("[data-post-id] .cooked");
              if (!targetContent) targetContent = document.querySelector(".cooked");

              if (targetContent) {
                if (data.post_stream && data.post_stream.posts && data.post_stream.posts[0]) {
                  const cooked = data.post_stream.posts[0].cooked;
                  if (cooked) {
                    targetContent.innerHTML = cooked;
                  }
                }
              }

              // Also update modal content
              contentTitle.textContent = items[index].title;
              if (data.post_stream && data.post_stream.posts && data.post_stream.posts[0]) {
                const cooked = data.post_stream.posts[0].cooked;
                if (cooked) {
                  contentArea.innerHTML = cooked;
                }
              }
            })
            .catch(err => console.error("Error updating content", err));
        }
      };

      // Update modal content (stays in modal) - ENHANCED for external links
// Update modal content (stays in modal) - ENHANCED for iframe-only scrolling
// Update modal content - FIXED scope & logic
const updateModalContent = throttle((index) => {
  if (index < 0 || index >= totalItems) return;

  selectedIndex = index;
  contentTitle.textContent = items[index].title;
  contentHeaderActions.innerHTML = "";

  // UI Updates
  pagingText.textContent = `${index + 1}/${totalItems}`;
  modalContentPrev.disabled = index === 0;
  modalContentNext.disabled = index === totalItems - 1;

  // Active states
  sliderItems.forEach((item, idx) => item.classList.toggle("active", idx === index));
  itemLinks.forEach((link, idx) => link.classList.toggle("active", idx === index));

  setTimeout(scrollSliderToActive, 100);

  if (items[index].external) {
    // EXTERNAL: Iframe mode
    modal.classList.add("external-url-active");
    contentArea.classList.add("external-url-content-wrapper");
    contentArea.innerHTML = loadExternalContent(items[index].href);
    setupIframeHandlers(contentArea);
    
    contentHeaderActions.innerHTML = `
      <a href="${items[index].href}" target="_blank" rel="noopener noreferrer" class="btn btn-primary">
        <svg class="fa d-icon d-icon-external-link-alt svg-icon" aria-hidden="true"><use href="#external-link-alt"></use></svg>
        Open in New Tab
      </a>
    `;
  } else {
    // INTERNAL: Topic mode
    modal.classList.remove("external-url-active");
    contentArea.classList.remove("external-url-content-wrapper");
    contentArea.innerHTML = "<p>Loading...</p>";
    
    if (items[index].topicId) {
      fetch(`/t/${items[index].topicId}.json`)
        .then(r => r.json())
        .then(data => {
          const cooked = data.post_stream?.posts?.[0]?.cooked;
          contentArea.innerHTML = cooked || "<p>No content</p>";
        })
        .catch(() => contentArea.innerHTML = "<p>Error loading</p>");
    }
  }

  // Navbar update
  const navText = navBar.querySelector(".nav-text");
  navText.textContent = `${collectionName}: ${items[index].title} (${index + 1}/${totalItems})`;
  prevBtn.disabled = index === 0;
  nextBtn.disabled = index === totalItems - 1;

}, SCROLL_THROTTLE_MS);


// ================================================================
// HELPER FUNCTIONS for iframe handling
// ================================================================

const loadExternalContent = (url) => {
  return `
    <div class="external-url-content">
      <div class="external-url-header">
        <h4>
          <a href="${url}" target="_blank" rel="noopener noreferrer" class="external-url-link">
            ${url.replace(/^https?:\/\//, '')}
            <svg class="fa d-icon d-icon-external-link-alt svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#external-link-alt"></use></svg>
          </a>
        </h4>
      </div>
      <div class="iframe-container">
        <div class="iframe-loading">Loading external content...</div>
        <iframe 
          src="${url}" 
          class="external-topic-iframe" 
          sandbox="allow-same-origin allow-scripts allow-popups allow-forms allow-downloads allow-top-navigation"
          loading="lazy"
          title="External content: ${url}"

        ></iframe>
//        <div class="iframe-error">
//          <p>⚠️ This content cannot be displayed in an iframe</p>
//          <p>Site security settings (CSP/X-Frame-Options) prevent embedding</p>
//          <a href="${url}" target="_blank" rel="noopener noreferrer" class="btn btn--primary">
//            Open in New Tab →
//          </a>
//        </div>
      </div>
    </div>
  `;
};


const processContentWithIframes = (cookedContent) => {
  // Process Discourse cooked content to ensure any embedded iframes are properly sandboxed
  return cookedContent;
};

const setupIframeHandlers = (container) => {
  const iframe = container.querySelector(".external-topic-iframe");
  const loadingDiv = container.querySelector(".iframe-loading");
  const errorDiv = container.querySelector(".iframe-error");

  if (iframe) {
    iframe.addEventListener("load", () => {
      if (loadingDiv) loadingDiv.style.display = "none";
    });
    
    iframe.addEventListener("error", () => {
      if (loadingDiv) loadingDiv.style.display = "none";
      if (errorDiv) errorDiv.style.display = "flex";
      iframe.style.display = "none";
    });
    
    // Timeout fallback for sites that silently block iframes
    setTimeout(() => {
      if (loadingDiv && loadingDiv.style.display !== "none") {
        try {
          iframe.contentWindow.location.href;
        } catch (e) {
          loadingDiv.style.display = "none";
          errorDiv.style.display = "flex";
          iframe.style.display = "none";
        }
      }
    }, 5000);
  }
};


      // ================================================================
      // EVENT LISTENERS
      // ================================================================

      // Toggle modal
      toggleBtn.addEventListener("click", showModal);

      // Sidebar toggle
      sidebarToggle.addEventListener("click", toggleSidebar);

      // Close modal
      closeBtn.addEventListener("click", hideModal);

      // Page nav buttons - update page content
      prevBtn.addEventListener("click", () => {
        if (selectedIndex > 0) {
          updatePageContent(selectedIndex - 1);
        }
      });

      nextBtn.addEventListener("click", () => {
        if (selectedIndex < totalItems - 1) {
          updatePageContent(selectedIndex + 1);
        }
      });

      // Modal content nav buttons
      modalContentPrev.addEventListener("click", () => {
        if (selectedIndex > 0) {
          updateModalContent(selectedIndex - 1);
        }
      });

      modalContentNext.addEventListener("click", () => {
        if (selectedIndex < totalItems - 1) {
          updateModalContent(selectedIndex + 1);
        }
      });

      // Item links in modal - update modal content
      itemLinks.forEach(link => {
        link.style.cursor = "pointer";
        link.addEventListener("click", (e) => {
          const index = parseInt(link.getAttribute("data-index"));
          updateModalContent(index);
        });
      });

      // Slider item clicks
      sliderItems.forEach(item => {
        item.addEventListener("click", (e) => {
          const index = parseInt(item.getAttribute("data-index"));
          updateModalContent(index);
        });
      });

      // Close on overlay background only
      modal.addEventListener("click", (e) => {
        if (e.target === modal) {
          hideModal();
        }
      });

      // ================================================================
      // KEYBOARD NAVIGATION (Pattern #1 - Throttled)
      // ================================================================

      let lastKeyPress = 0;

      document.addEventListener("keydown", (e) => {
        if (modal.style.display === "flex") {
          // Modal is open - navigate within modal
          if (e.key === "ArrowLeft" && selectedIndex > 0) {
            const now = Date.now();
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }
            lastKeyPress = now;
            e.preventDefault();
            updateModalContent(selectedIndex - 1);
          } else if (e.key === "ArrowRight" && selectedIndex < totalItems - 1) {
            const now = Date.now();
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }
            lastKeyPress = now;
            e.preventDefault();
            updateModalContent(selectedIndex + 1);
          } else if (e.key === "Escape") {
            e.preventDefault();
            hideModal();
          }
        } else {
          // Modal is closed - navigate the page
          if (e.key === "ArrowLeft" && selectedIndex > 0) {
            const now = Date.now();
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }
            lastKeyPress = now;
            e.preventDefault();
            updatePageContent(selectedIndex - 1);
          } else if (e.key === "ArrowRight" && selectedIndex < totalItems - 1) {
            const now = Date.now();
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }
            lastKeyPress = now;
            e.preventDefault();
            updatePageContent(selectedIndex + 1);
          }
        }
      });

    }, 500);
  });
});
