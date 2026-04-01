import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.24.0", (api) => {
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

      const KEYBOARD_THROTTLE_MS = 150;
      const SCROLL_THROTTLE_MS = 50;

      const externalLinkIcon = `
        <svg
          class="fa d-icon d-icon-collections-arrow-up-right-from-square svg-icon svg-string"
          width="1em"
          height="1em"
          aria-hidden="true"
          xmlns="http://www.w3.org/2000/svg"
        >
          <use href="#collections-arrow-up-right-from-square"></use>
        </svg>
      `;

      const closeIcon = `
        <svg
          class="fa d-icon d-icon-times svg-icon svg-string"
          width="1em"
          height="1em"
          aria-hidden="true"
          xmlns="http://www.w3.org/2000/svg"
        >
          <use href="#times"></use>
        </svg>
      `;

      const checkIcon = `
        <svg
          class="fa d-icon d-icon-check svg-icon svg-string"
          width="1em"
          height="1em"
          aria-hidden="true"
          xmlns="http://www.w3.org/2000/svg"
        >
          <use href="#check"></use>
        </svg>
      `;

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

      const getTopicIdFromHref = (href) => {
        if (!href) {
          return null;
        }

        const match =
          href.match(/\/t\/[^/]+\/(\d+)/) ||
          href.match(/\/t\/(\d+)/) ||
          href.match(/\/(\d+)(?:\/)?$/);

        return match ? match[1] : null;
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
        const topicId = !external ? getTopicIdFromHref(href) : null;

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

        try {
          const hrefUrl = new URL(item.href, window.location.origin);
          return hrefUrl.pathname === currentUrl || currentUrl.includes(hrefUrl.pathname);
        } catch {
          return false;
        }
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
            <button class="modal-sidebar-toggle btn btn-flat btn--toggle no-text btn-icon narrow-desktop" aria-label="Toggle sidebar" type="button" title="Toggle sidebar">
              <svg class="fa d-icon d-icon-bars svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
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
                    }" data-index="${idx}" title="${item.title}" type="button">
                      ${item.external ? `${externalLinkIcon} ` : ""}${item.title}
                    </button>
                  `
                    )
                    .join("")}
                </div>
              </div>
            </div>
            <button class="modal-close-btn" aria-label="Close modal" type="button">
              ${closeIcon}
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
                    }" data-index="${idx}" title="${item.title}" role="button" tabindex="0">
                      <span class="item-number">${idx + 1}</span>
                      <span class="item-title">${item.title}</span>
                      ${idx === currentIndex ? checkIcon : ""}
                      ${item.external ? externalLinkIcon : ""}
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
      const contentHeaderActions = modal.querySelector(".content-header-actions");
      const sidebarToggle = modal.querySelector(".modal-sidebar-toggle");
      const sidebar = modal.querySelector(".modal-items-sidebar");
      const modalContentPrev = modal.querySelector(".modal-content-prev");
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

      const updatePageContent = (index) => {
        if (index < 0 || index >= totalItems) {
          return;
        }

        if (items[index].external) {
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
                contentArea.classList.remove("external-url-content-wrapper");
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
                ${url.replace(/^https?:\\/\\//, "")}
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

        setTimeout(scrollSliderToActive, 100);

        if (items[index].external) {
          modal.classList.add("external-url-active");
          contentArea.classList.add("external-url-content-wrapper");
          contentArea.innerHTML = loadExternalContent(items[index].href);
          setupIframeHandlers(contentArea);

          contentHeaderActions.innerHTML = `
            <a href="${items[index].href}" target="_blank" rel="noopener noreferrer" class="btn btn-primary">
              ${externalLinkIcon}
              Open in New Tab
            </a>
          `;
        } else {
          modal.classList.remove("external-url-active");
          contentArea.classList.remove("external-url-content-wrapper");
          contentArea.style.visibility = "";
          contentArea.style.height = "";
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

        link.addEventListener("keydown", (e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            const index = parseInt(link.getAttribute("data-index"), 10);
            updateModalContent(index);
          }
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
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }

            lastKeyPress = now;
            e.preventDefault();
            updateModalContent(selectedIndex - 1);
          } else if (
            e.key === "ArrowRight" &&
            selectedIndex < totalItems - 1
          ) {
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
          if (e.key === "ArrowLeft" && selectedIndex > 0) {
            if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
              return;
            }

            lastKeyPress = now;
            e.preventDefault();
            updatePageContent(selectedIndex - 1);
          } else if (
            e.key === "ArrowRight" &&
            selectedIndex < totalItems - 1
          ) {
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
