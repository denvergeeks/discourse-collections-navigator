import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.24.0", (api) => {
  let keyboardHandlerBound = false;
  let resizerBound = false;
  let activeModalState = null;

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

    if (
      raw.startsWith("min(") ||
      raw.startsWith("max(") ||
      raw.startsWith("clamp(")
    ) {
      return fallback;
    }

    const parsed = parseFloat(raw.replace("px", ""));
    return Number.isNaN(parsed) ? fallback : parsed;
  }

  const externalLinkIcon = `
    <svg
      class="fa d-icon svg-icon svg-string"
      width="1em"
      height="1em"
      viewBox="0 0 512 512"
      aria-hidden="true"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        fill="currentColor"
        d="M320 0c-17.7 0-32 14.3-32 32s14.3 32 32 32l82.7 0L201.4 265.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L448 109.3l0 82.7c0 17.7 14.3 32 32 32s32-14.3 32-32l0-160c0-17.7-14.3-32-32-32L320 0zM80 32C35.8 32 0 67.8 0 112L0 432c0 44.2 35.8 80 80 80l320 0c44.2 0 80-35.8 80-80l0-112c0-17.7-14.3-32-32-32s-32 14.3-32 32l0 112c0 8.8-7.2 16-16 16L80 448c-8.8 0-16-7.2-16-16l0-320c0-8.8 7.2-16 16-16l112 0c17.7 0 32-14.3 32-32s-14.3-32-32-32L80 32z"
      />
    </svg>
  `;

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
    resizer.setAttribute("aria-valuemin", "240");
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
      if (!splitBody) {
        return;
      }

      event.preventDefault();

      const splitRect = splitBody.getBoundingClientRect();
      const minWidth = getCssPxNumber(
        modal,
        "--collections-sidebar-min-width",
        240
      );
      const maxWidthFallback = Math.max(
        minWidth,
        Math.floor(splitRect.width * 0.45)
      );
      const maxWidth = getCssPxNumber(
        modal,
        "--collections-sidebar-max-width",
        maxWidthFallback
      );

      resizer.setAttribute("aria-valuemax", String(Math.round(maxWidth)));

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

      const currentWidth = getCssPxNumber(
        modal,
        "--collections-sidebar-width",
        320
      );
      const minWidth = getCssPxNumber(
        modal,
        "--collections-sidebar-min-width",
        240
      );
      const splitBody = modal.querySelector(".modal-body-split");
      const splitRect = splitBody?.getBoundingClientRect();
      const maxWidthFallback = splitRect
        ? Math.max(minWidth, Math.floor(splitRect.width * 0.45))
        : 520;
      const maxWidth = getCssPxNumber(
        modal,
        "--collections-sidebar-max-width",
        maxWidthFallback
      );

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
      resizer.setAttribute("aria-valuemax", String(Math.round(maxWidth)));
    };

    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    resizerBound = true;
  }

  api.onPageChange(() => {
    setTimeout(() => {
      const sidebarPanel = document.querySelector(
        ".discourse-collections-sidebar-panel"
      );
      const postsContainer = document.querySelector(".posts");

      if (!sidebarPanel || !postsContainer) {
        return;
      }

      const links = sidebarPanel.querySelectorAll(".collection-sidebar-link");

      document
        .querySelectorAll(".collections-nav-injected")
        .forEach((el) => el.remove());
      document
        .querySelectorAll(".collections-nav-modal-overlay")
        .forEach((el) => el.remove());

      const collectionTitleEl = document.querySelector(
        ".collection-sidebar__title"
      );
      const collectionDescEl = document.querySelector(
        ".collection-sidebar__desc"
      );
      const collectionName =
        collectionTitleEl?.textContent?.trim() || "Collection";
      const collectionDesc = collectionDescEl?.textContent?.trim() || "";

      const isExternalUrl = (href) => {
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
      };

      const items = Array.from(links).map((link) => {
        const href = link.getAttribute("href");

        let title = link
          .querySelector(".collection-link-content-text")
          ?.textContent?.trim();

        if (!title) {
          title = link
            .querySelector(".sidebar-section-link-content-text")
            ?.textContent?.trim();
        }

        if (!title) {
          title = link
            .querySelector("[class*='content-text']")
            ?.textContent?.trim();
        }

        if (!title) {
          title = link.textContent?.trim();
        }

        if (!title) {
          title = "Untitled";
        }

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

      const enhanceCooked = (element) => {
        if (!element) {
          return;
        }

        api.decorateCookedElement(() => {}, {
          id: "collections-navigator-modal",
        });

        api.applyDecoratorsToElement?.(element);
      };

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

      const modal = document.createElement("div");
      modal.className = "collections-nav-modal-overlay";
      modal.innerHTML = `
        <div class="collections-nav-modal collections-modal-with-content">
          <div class="modal-header">
            <div class="modal-header-side modal-header-side-left">
              <button class="modal-sidebar-toggle btn btn-flat btn--toggle no-text btn-icon narrow-desktop" aria-label="Toggle sidebar" type="button" title="Toggle sidebar">
                <svg class="fa d-icon d-icon-discourse-sidebar svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                  <use href="#discourse-sidebar"></use>
                </svg>
              </button>
            </div>

            <div class="modal-header-center">
              <div class="modal-header-content">
                <h2 class="modal-title">${collectionName}</h2>
                ${
                  collectionDesc
                    ? `<p class="collection-description">${collectionDesc}</p>`
                    : ""
                }

                <div class="topic-slider-shell">
                  <button class="topic-slider-edge topic-slider-edge-prev" type="button" aria-label="Previous items">
                    <svg class="fa d-icon d-icon-chevron-left svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                      <use href="#chevron-left"></use>
                    </svg>
                  </button>

                  <div class="topic-slider-container">
                    <div class="topic-slider">
                      ${items
                        .map(
                          (item, idx) => `
                            <button class="slider-item ${
                              idx === currentIndex ? "active" : ""
                            }" data-index="${idx}" title="${item.title}">
                              ${item.external ? externalLinkIcon : ""}
                              <span class="slider-item-title">${item.title}</span>
                              <span class="slider-item-count">${idx + 1}/${totalItems}</span>
                            </button>
                          `
                        )
                        .join("")}
                    </div>
                  </div>

                  <button class="topic-slider-edge topic-slider-edge-next" type="button" aria-label="Next items">
                    <svg class="fa d-icon d-icon-chevron-right svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                      <use href="#chevron-right"></use>
                    </svg>
                  </button>
                </div>
              </div>
            </div>

            <div class="modal-header-side modal-header-side-right">
              <button class="modal-close-btn" aria-label="Close modal" type="button">
                <svg class="fa d-icon d-icon-xmark svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
                  <use href="#xmark"></use>
                </svg>
              </button>
            </div>
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
                              ? `<span class="collections-external-link-button" aria-hidden="true">${externalLinkIcon}</span>`
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

      const modalPanel = modal.querySelector(".collections-nav-modal");
      ensureSidebarResizer(modalPanel);
      bindSidebarResizer();

      const contentArea = modal.querySelector(".cooked-content");

      if (cookedNode && contentArea) {
        contentArea.innerHTML = "";
        contentArea.appendChild(cookedNode);
      } else {
        enhanceCooked(contentArea);
      }

      const toggleBtn = navBar.querySelector(".collections-nav-toggle");
      const prevBtn = navBar.querySelector(".collections-nav-prev");
      const nextBtn = navBar.querySelector(".collections-nav-next");
      const closeBtn = modal.querySelector(".modal-close-btn");
      const itemLinks = modal.querySelectorAll(".collection-item-link");
      const sliderItems = modal.querySelectorAll(".slider-item");
      const contentTitle = modal.querySelector(".content-title");
      const contentHeaderActions = modal.querySelector(
        ".content-header-actions"
      );
      const sidebarToggle = modal.querySelector(".modal-sidebar-toggle");
      const sidebar = modal.querySelector(".modal-items-sidebar");
      const modalContentPrev = modal.querySelector(".modal-content-prev");
      const modalContentNext = modal.querySelector(".modal-content-next");
      const pagingText = modal.querySelector(".paging-text");
      const topicSliderContainer = modal.querySelector(
        ".topic-slider-container"
      );
      const topicSliderShell = modal.querySelector(".topic-slider-shell");
      const topicSlider = modal.querySelector(".topic-slider");
      const topicSliderPrev = modal.querySelector(".topic-slider-edge-prev");
      const topicSliderNext = modal.querySelector(".topic-slider-edge-next");

      let selectedIndex = currentIndex;
      let sidebarOpen = false;

      const syncSliderEdgeState = () => {
        if (!topicSliderContainer || !topicSlider) {
          return;
        }

        const maxScrollLeft =
          topicSliderContainer.scrollWidth - topicSliderContainer.clientWidth;
        const isScrollable = maxScrollLeft > 4;

        topicSliderShell?.classList.toggle("is-scrollable", isScrollable);
        topicSliderShell?.classList.toggle(
          "at-start",
          !isScrollable || topicSliderContainer.scrollLeft <= 2
        );
        topicSliderShell?.classList.toggle(
          "at-end",
          !isScrollable ||
            topicSliderContainer.scrollLeft >= maxScrollLeft - 2
        );
      };

      const scrollSliderByPage = (direction) => {
        if (!topicSliderContainer) {
          return;
        }

        const amount = Math.max(180, Math.floor(topicSliderContainer.clientWidth * 0.7));
        topicSliderContainer.scrollBy({
          left: direction * amount,
          behavior: getScrollBehavior(),
        });
      };

      const setSidebarVisibility = (open) => {
        sidebarOpen = open;

        if (open) {
          sidebar.classList.remove("collapsed");
          modalPanel.classList.add("collections-sidebar-open");
        } else {
          sidebar.classList.add("collapsed");
          modalPanel.classList.remove("collections-sidebar-open");
        }

        if (window.innerWidth <= 767) {
          topicSliderShell?.classList.remove("collapsed");
        } else {
          topicSliderShell?.classList.toggle("collapsed", open);
        }

        window.requestAnimationFrame(() => {
          syncSliderEdgeState();
          scrollSliderToActive();
        });
      };

      const showModal = () => {
        modal.style.display = "flex";
        setSidebarVisibility(window.innerWidth > 767 ? sidebarOpen : false);

        activeModalState = {
          modal,
          totalItems,
          selectedIndexRef: () => selectedIndex,
          prev: () => {
            if (selectedIndex > 0) {
              updateModalContent(selectedIndex - 1);
            }
          },
          next: () => {
            if (selectedIndex < totalItems - 1) {
              updateModalContent(selectedIndex + 1);
            }
          },
          hide: () => {
            modal.style.display = "none";
          },
        };

        window.requestAnimationFrame(() => {
          syncSliderEdgeState();
          scrollSliderToActive();
        });
      };

      const hideModal = () => {
        modal.style.display = "none";
        if (activeModalState?.modal === modal) {
          activeModalState = null;
        }
      };

      const toggleSidebar = () => {
        if (window.innerWidth <= 767) {
          setSidebarVisibility(!sidebarOpen);
          return;
        }

        setSidebarVisibility(!sidebarOpen);
      };

      const scrollSliderToActive = () => {
        const activeSlider = modal.querySelector(".slider-item.active");
        if (activeSlider && !topicSliderShell?.classList.contains("collapsed")) {
          activeSlider.scrollIntoView({
            behavior: getScrollBehavior(),
            block: "nearest",
            inline: "center",
          });
        }
      };

      const updatePageContent = (index) => {
        if (index < 0 || index >= totalItems) {
          return;
        }

        if (items[index].external) {
          return;
        }

        selectedIndex = index;

        const navText = navBar.querySelector(".nav-text");
        navText.textContent = `${collectionName}: ${items[index].title} (${index + 1}/${totalItems})`;

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
              if (!targetContent) {
                targetContent = document.querySelector(".topic-body .cooked");
              }
              if (!targetContent) {
                targetContent = document.querySelector(
                  ".post-stream .posts .boxed-body"
                );
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

      const loadExternalContent = (url) => {
        return `
          <div class="external-url-header">
            <h4>
              <a href="${url}" target="_blank" rel="noopener noreferrer" class="external-url-link">
                ${url.replace(/^https?:\/\//, "")}
                ${externalLinkIcon}
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

      const setupIframeHandlers = (container) => {
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
      };

      const updateModalContent = throttle((index) => {
        if (index < 0 || index >= totalItems) {
          return;
        }

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

        window.requestAnimationFrame(() => {
          scrollSliderToActive();
          syncSliderEdgeState();
        });

        if (items[index].external) {
          modal.classList.add("external-url-active");
          contentArea.classList.add("external-url-content-wrapper");
          contentArea.innerHTML = loadExternalContent(items[index].href);
          setupIframeHandlers(contentArea);

          contentHeaderActions.innerHTML = `
            <a href="${items[index].href}" target="_blank" rel="noopener noreferrer" class="btn btn-primary collections-open-external-button">
              ${externalLinkIcon}
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
        navText.textContent = `${collectionName}: ${items[index].title} (${index + 1}/${totalItems})`;
        prevBtn.disabled = index === 0;
        nextBtn.disabled = index === totalItems - 1;
      }, SCROLL_THROTTLE_MS);

      toggleBtn.addEventListener("click", showModal);
      sidebarToggle.addEventListener("click", toggleSidebar);
      closeBtn.addEventListener("click", hideModal);
      topicSliderPrev?.addEventListener("click", () => scrollSliderByPage(-1));
      topicSliderNext?.addEventListener("click", () => scrollSliderByPage(1));
      topicSliderContainer?.addEventListener("scroll", throttle(syncSliderEdgeState, 30));
      window.addEventListener("resize", throttle(() => {
        if (modal.style.display === "flex") {
          if (window.innerWidth <= 767) {
            sidebar.classList.add("collapsed");
            modalPanel.classList.remove("collections-sidebar-open");
            sidebarOpen = false;
            topicSliderShell?.classList.remove("collapsed");
          }
          syncSliderEdgeState();
        }
      }, 50));

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

      if (!keyboardHandlerBound) {
        let lastKeyPress = 0;

        document.addEventListener("keydown", (e) => {
          if (!activeModalState || activeModalState.modal.style.display !== "flex") {
            return;
          }

          const now = Date.now();
          const selected = activeModalState.selectedIndexRef();
          const maxIndex = activeModalState.totalItems - 1;

          if (e.key === "ArrowLeft" && selected > 0) {
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }
            if (
              document.activeElement?.classList?.contains(
                "collections-sidebar-resizer"
              )
            ) {
              return;
            }
            lastKeyPress = now;
            e.preventDefault();
            activeModalState.prev();
          } else if (e.key === "ArrowRight" && selected < maxIndex) {
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }
            if (
              document.activeElement?.classList?.contains(
                "collections-sidebar-resizer"
              )
            ) {
              return;
            }
            lastKeyPress = now;
            e.preventDefault();
            activeModalState.next();
          } else if (e.key === "Escape") {
            e.preventDefault();
            activeModalState.hide();
          }
        });

        keyboardHandlerBound = true;
      }
    }, 500);
  });
});
