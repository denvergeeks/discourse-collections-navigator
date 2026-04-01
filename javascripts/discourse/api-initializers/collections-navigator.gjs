import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.24.0", (api) => {
  api.onPageChange(() => {
    setTimeout(() => {
      const sidebarPanel = document.querySelector(".discourse-collections-sidebar-panel");
      const postsContainer = document.querySelector(".posts");

      if (!sidebarPanel || !postsContainer) {
        return;
      }

      let links = sidebarPanel.querySelectorAll(".collection-sidebar-link");

      // Remove old nav if exists
      document
        .querySelectorAll(".collections-nav-injected")
        .forEach((el) => el.remove());
      document
        .querySelectorAll(".collections-nav-modal-overlay")
        .forEach((el) => el.remove());

      // Collection title/description
      const collectionTitleEl = document.querySelector(".collection-sidebar__title");
      const collectionDescEl = document.querySelector(".collection-sidebar__desc");
      const collectionName =
        collectionTitleEl?.textContent?.trim() || "Collection";
      const collectionDesc = collectionDescEl?.textContent?.trim() || "";

      // -------- helpers --------
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

      // Find current item
      const currentUrl = window.location.pathname;
      const currentIndex = items.findIndex((item) => {
        if (item.external) {
          return false;
        }
        if (!item.href) {
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

      // Use already-rendered cooked DOM from the page (fully decorated)
      const getPostContentNode = () => {
        // Prefer main first post cooked
        let content = document.querySelector(
          ".topic-post[data-post-number='1'] .cooked"
        );
        if (!content) {
          content = document.querySelector(".topic-body .cooked");
        }
        if (!content) {
          return null;
        }
        // Clone so we keep original in the DOM
        return content.cloneNode(true);
      };

      const cookedNode = getPostContentNode();
      const cookedContent =
        cookedNode?.outerHTML || "<p>Loading content...</p>";

      // Discourse patterns / constants
      const KEYBOARD_THROTTLE_MS = 150;
      const SCROLL_THROTTLE_MS = 50;

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

      // ── IFRAME RESIZE UTILITY ────────────────────────────────────────────────
      // Adapted from the north-arrow iframe sizing pattern.
      // Calculates the wrapper's offset from the viewport and sizes the iframe
      // to fill from that point to the bottom of the visible area.
      //
      // The wrapper must have  position:relative  (set via CSS on
      // .iframe-container) so the absolutely-positioned iframe is contained.
      // The wrapper starts with  visibility:hidden  (CSS) and this function
      // reveals it after the first successful layout calculation.
      function adjustIframe(iframe, wrapper) {
        if (!iframe || !wrapper) {
          return;
        }

        const rect = wrapper.getBoundingClientRect();
        // offsetTop relative to the document (accounts for page scroll)
        const offsetTop = rect.top + window.scrollY;
        // offsetLeft relative to the document – used to counter any
        // left inset so the iframe aligns flush with its container edge
        const offsetLeft = rect.left + window.scrollX;

        // Height: fill from wrapper's top edge to the bottom of the viewport
        wrapper.style.height = "calc(100vh - " + offsetTop + "px)";

        // Position the iframe absolutely inside the wrapper.
        // We do NOT break out to full page width here (the modal is a fixed
        // overlay so there is no need), but we do cancel any left inset so
        // the iframe sits flush against the container's left edge.
        iframe.style.position = "absolute";
        iframe.style.top = "0";
        iframe.style.left = offsetLeft > 0 ? "-" + offsetLeft + "px" : "0";
        iframe.style.width = wrapper.offsetWidth + "px";
        iframe.style.height = "100%";
        iframe.style.border = "none";
        iframe.style.display = "block";

        // Reveal the wrapper now that sizing is correct
        wrapper.style.visibility = "visible";
      }

      // Run cooked decorators on dynamically injected content
      const enhanceCooked = (element) => {
        if (!element) {
          return;
        }

        // Register a no-op decorator so our id participates in the pipeline
        api.decorateCookedElement(() => {}, {
          id: "collections-navigator-modal",
        });

        // Apply all decorators to this element (available in current core)
        api.applyDecoratorsToElement?.(element);
      };

      // --- Top nav bar ---
      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.innerHTML = `
        <button class="btn btn--primary collections-nav-toggle" title="Open collection navigator" type="button">
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
            </svg>
          </button>
          <button class="btn btn--secondary collections-nav-next" ${
            currentIndex === totalItems - 1 ? "disabled" : ""
          } title="Next (arrow key)" type="button">
            <svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
              <use href="#arrow-right"></use>
            </svg>
          </button>
        </div>
      `;
      postsContainer.parentNode.insertBefore(navBar, postsContainer);

      // --- Modal ---
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
              <h2 class="modal-title">${collectionName}</h2>
              ${
                collectionDesc
                  ? `<p class="collection-description">${collectionDesc}</p>`
                  : ""
              }
              <div class="topic-slider-container">
                <div class="topic-slider">
                  ${items
                    .map(
                      (item, idx) => `
                    <button class="slider-item ${
                      idx === currentIndex ? "active" : ""
                    }" data-index="${idx}" title="${item.title}">
                      ${
                        item.external
                          ? `<svg class="fa d-icon d-icon-arrow-up-right-from-square svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                               <use href="#arrow-up-right-from-square"></use>
                             </svg> `
                          : ""
                      }${item.title}
                    </button>
                  `
                    )
                    .join("")}
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
                ${items
                  .map(
                    (item, idx) => `
                  <li class="collection-item ${
                    idx === currentIndex ? "active" : ""
                  }">
                    <div class="collection-item-link ${
                      item.external ? "external-link" : ""
                    }" data-index="${idx}" title="${item.title}">
                      <span class="item-number">${idx + 1}</span>
                      <span class="item-title">${item.title}</span>
                      ${
                        idx === currentIndex
                          ? '<span class="d-icon d-icon-check"></span>'
                          : ""
                      }
                      ${
                        item.external
                          ? '<span class="d-icon d-icon-external-link-alt"></span>'
                          : ""
                      }
                    </div>
                  </li>
                `
                  )
                  .join("")}
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
            <button class="btn btn--secondary modal-content-prev" title="Previous item" type="button" ${
              currentIndex === 0 ? "disabled" : ""
            }>
              <svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                <use href="#arrow-left"></use>
              </svg>
              Previous
            </button>
            <div class="modal-paging">
              <span class="paging-text">${currentIndex + 1}/${totalItems}</span>
            </div>
            <button class="btn btn--secondary modal-content-next" title="Next item" type="button" ${
              currentIndex === totalItems - 1 ? "disabled" : ""
            }>
              Next
              <svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                <use href="#arrow-right"></use>
              </svg>
            </button>
          </div>
        </div>
      `;
      document.body.appendChild(modal);

      // If we had a cloned cooked node, ensure we use it (so events/decorations survive)
      const contentArea = modal.querySelector(".cooked-content");
      if (cookedNode && contentArea) {
        contentArea.innerHTML = "";
        contentArea.appendChild(cookedNode);
      } else {
        enhanceCooked(contentArea);
      }

      // Elements
      const toggleBtn = navBar.querySelector(".collections-nav-toggle");
      const prevBtn = navBar.querySelector(".collections-nav-prev");
      const nextBtn = navBar.querySelector(".collections-nav-next");
      const closeBtn = modal.querySelector(".modal-close-btn");
      const itemLinks = modal.querySelectorAll(".collection-item-link");
      const sliderItems = modal.querySelectorAll(".slider-item");
      const contentTitle = modal.querySelector(".content-title");
      const contentHeaderActions = modal.querySelector(".content-header-actions");
      const sidebarToggle = modal.querySelector(".modal-sidebar-toggle");
      const sidebar = modal.querySelector(".modal-items-sidebar");
      const modalContentPrev = modal.querySelector(".modal-content-prev");
      const modalContentNext = modal.querySelector(".modal-content-next");
      const pagingText = modal.querySelector(".paging-text");
      const topicSliderContainer = modal.querySelector(".topic-slider-container");
      // topicSlider is referenced via topicSliderContainer only; kept for future use
      // const topicSlider = modal.querySelector(".topic-slider");

      let selectedIndex = currentIndex;
      let sidebarOpen = false;

      const showModal = () => {
        modal.style.display = "flex";
      };
      const hideModal = () => {
        modal.style.display = "none";
      };

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

      const scrollSliderToActive = () => {
        const activeSlider = modal.querySelector(".slider-item.active");
        if (activeSlider) {
          activeSlider.scrollIntoView({
            behavior: getScrollBehavior(),
            block: "nearest",
            inline: "center",
          });
        }
      };

      // ---- page content update (internal only) ----
      const updatePageContent = (index) => {
        if (index < 0 || index >= totalItems) return;
        if (items[index].external) {
          // Do not inline-navigate to external links
          return;
        }

        selectedIndex = index;

        const navText = navBar.querySelector(".nav-text");
        navText.textContent = `${collectionName}: ${items[index].title} (${
          index + 1
        }/${totalItems})`;

        prevBtn.disabled = index === 0;
        nextBtn.disabled = index === totalItems - 1;

        if (items[index].topicId) {
          fetch(`/t/${items[index].topicId}.json`)
            .then((response) => response.json())
            .then((data) => {
              document.title = items[index].title;

              let targetContent = document.querySelector(
                ".topic-post[data-post-number='1'] .cooked"
              );
              if (!targetContent)
                targetContent = document.querySelector(".topic-body .cooked");
              if (!targetContent)
                targetContent = document.querySelector(
                  ".post-stream .posts .boxed-body"
                );
              if (!targetContent)
                targetContent = document.querySelector(".post-content");
              if (!targetContent)
                targetContent = document.querySelector("[data-post-id] .cooked");
              if (!targetContent) targetContent = document.querySelector(".cooked");

              const cooked = data.post_stream?.posts?.[0]?.cooked;
              if (targetContent && cooked) {
                targetContent.innerHTML = cooked;
                enhanceCooked(targetContent);
              }

              contentTitle.textContent = items[index].title;
              if (cooked && contentArea) {
                contentArea.innerHTML = cooked;
                enhanceCooked(contentArea);
              }
            })
            .catch((err) => console.error("Error updating content", err));
        }
      };

      // ---- modal content update (internal & external) ----

      // Build the HTML shell for an external URL panel.
      // The iframe starts with display:none; adjustIframe() will reveal it
      // and size it correctly once the load event fires.
      const loadExternalContent = (url) => {
        return `
            <div class="external-url-header">
              <h4>
                <a href="${url}" target="_blank" rel="noopener noreferrer" class="external-url-link">
                  ${url.replace(/^https?:\/\//, "")}
                  <svg class="fa d-icon d-icon-external-link-alt svg-icon svg-string" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                    <use href="#external-link-alt"></use>
                  </svg>
                </a>
              </h4>
            </div>
              <div class="iframe-loading">Loading external content...</div>
              <iframe
                src="${url}"
                class="external-topic-iframe"
                sandbox="allow-same-origin allow-scripts allow-popups allow-forms allow-downloads allow-top-navigation"
                loading="lazy"
                title="External content: ${url}"
              ></iframe>
        `;
      };

      // Wire up load/error/resize behaviour for every .external-topic-iframe
      // found inside `container`.  Uses adjustIframe() for all sizing so that
      // iframe dimensions always derive from live viewport measurements.
      const setupIframeHandlers = (container) => {
        const iframe = container.querySelector(".external-topic-iframe");
        const loadingDiv = container.querySelector(".iframe-loading");
        const wrapper = container.querySelector(".cooked-content.external-url-content-wrapper");

        if (!iframe) {
          return;
        }

        // Throttled resize handler scoped to this specific iframe instance
        const onResize = throttle(() => adjustIframe(iframe, wrapper), 100);

        const onLoad = () => {
          if (loadingDiv) {
            loadingDiv.style.display = "none";
          }
          // Size the iframe using live viewport measurements, then
          // keep it in sync as the window is resized.
          adjustIframe(iframe, wrapper);
          window.addEventListener("resize", onResize);
        };

        const onError = () => {
          if (loadingDiv) {
            loadingDiv.style.display = "none";
          }
          // Ensure wrapper is at least visible so the error message shows
          if (wrapper) {
            wrapper.style.visibility = "visible";
          }
          iframe.style.display = "none";
          // Remove resize listener – sizing is irrelevant if the iframe failed
          window.removeEventListener("resize", onResize);
        };

        iframe.addEventListener("load", onLoad);
        iframe.addEventListener("error", onError);

        // Fallback: some hosts block iframes silently (no error event).
        // After 5 s, check if the loading indicator is still visible and
        // attempt a same-origin contentDocument access; a SecurityError
        // means the frame was blocked by X-Frame-Options / CSP.
        setTimeout(() => {
          if (loadingDiv && loadingDiv.style.display !== "none") {
            try {
              // Will throw SecurityError if cross-origin and blocked
              // eslint-disable-next-line no-unused-expressions
              iframe.contentWindow.location.href;
              // No throw → frame loaded (possibly empty); treat as success
              onLoad();
            } catch (e) {
              onError();
            }
          }
        }, 5000);
      };

      const updateModalContent = throttle((index) => {
        if (index < 0 || index >= totalItems) return;

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
        setTimeout(scrollSliderToActive, 100);

        if (items[index].external) {
          modal.classList.add("external-url-active");
          contentArea.classList.add("external-url-content-wrapper");
          contentArea.innerHTML = loadExternalContent(items[index].href);
          setupIframeHandlers(contentArea);

          contentHeaderActions.innerHTML = `
            <a href="${items[index].href}" target="_blank" rel="noopener noreferrer" class="btn btn-primary">
              <svg class="fa d-icon d-icon-external-link-alt svg-icon" aria-hidden="true">
                <use href="#external-link-alt"></use>
              </svg>
              Open in New Tab
            </a>
          `;
        } else {
          modal.classList.remove("external-url-active");
          contentArea.classList.remove("external-url-content-wrapper");
          contentArea.innerHTML = "<p>Loading...</p>";

          if (items[index].topicId) {
            fetch(`/t/${items[index].topicId}.json`)
              .then((r) => r.json())
              .then((data) => {
                const cooked = data.post_stream?.posts?.[0]?.cooked;
                contentArea.innerHTML = cooked || "<p>No content</p>";
                enhanceCooked(contentArea);
              })
              .catch(() => {
                contentArea.innerHTML = "<p>Error loading</p>";
              });
          }
        }

        const navText = navBar.querySelector(".nav-text");
        navText.textContent = `${collectionName}: ${items[index].title} (${
          index + 1
        }/${totalItems})`;
        prevBtn.disabled = index === 0;
        nextBtn.disabled = index === totalItems - 1;
      }, SCROLL_THROTTLE_MS);

      // --- listeners ---
      toggleBtn.addEventListener("click", showModal);
      sidebarToggle.addEventListener("click", toggleSidebar);
      closeBtn.addEventListener("click", hideModal);

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

      itemLinks.forEach((link) => {
        link.style.cursor = "pointer";
        link.addEventListener("click", () => {
          const index = parseInt(link.getAttribute("data-index"), 10);
          updateModalContent(index);
        });
      });

      sliderItems.forEach((item) => {
        item.addEventListener("click", () => {
          const index = parseInt(item.getAttribute("data-index"), 10);
          updateModalContent(index);
        });
      });

      modal.addEventListener("click", (e) => {
        if (e.target === modal) {
          hideModal();
        }
      });

      let lastKeyPress = 0;
      document.addEventListener("keydown", (e) => {
        const now = Date.now();

        if (modal.style.display === "flex") {
          if (e.key === "ArrowLeft" && selectedIndex > 0) {
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) return;
            lastKeyPress = now;
            e.preventDefault();
            updateModalContent(selectedIndex - 1);
          } else if (
            e.key === "ArrowRight" &&
            selectedIndex < totalItems - 1
          ) {
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) return;
            lastKeyPress = now;
            e.preventDefault();
            updateModalContent(selectedIndex + 1);
          } else if (e.key === "Escape") {
            e.preventDefault();
            hideModal();
          }
        } else {
          if (e.key === "ArrowLeft" && selectedIndex > 0) {
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) return;
            lastKeyPress = now;
            e.preventDefault();
            updatePageContent(selectedIndex - 1);
          } else if (
            e.key === "ArrowRight" &&
            selectedIndex < totalItems - 1
          ) {
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) return;
            lastKeyPress = now;
            e.preventDefault();
            updatePageContent(selectedIndex + 1);
          }
        }
      });
    }, 500);
  });
});
