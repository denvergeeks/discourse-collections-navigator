import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.24.0", (api) => {
  const INIT_FLAG = "data-collections-navigator-bound";

  api.onPageChange(() => {
    setTimeout(() => {
      const sidebarPanel = document.querySelector(
        ".discourse-collections-sidebar-panel"
      );
      const postsContainer = document.querySelector(".posts");

      document
        .querySelectorAll(".collections-nav-injected")
        .forEach((el) => el.remove());
      document
        .querySelectorAll(".collections-nav-modal-overlay")
        .forEach((el) => el.remove());

      if (!sidebarPanel || !postsContainer) {
        return;
      }

      const links = sidebarPanel.querySelectorAll(".collection-sidebar-link");
      if (!links.length) {
        return;
      }

      const collectionTitleEl = document.querySelector(
        ".collection-sidebar__title"
      );
      const collectionDescEl = document.querySelector(
        ".collection-sidebar__desc"
      );

      const collectionName =
        collectionTitleEl && collectionTitleEl.textContent
          ? collectionTitleEl.textContent.trim()
          : "Collection";
      const collectionDesc =
        collectionDescEl && collectionDescEl.textContent
          ? collectionDescEl.textContent.trim()
          : "";

      const KEYBOARD_THROTTLE_MS = 150;
      const SCROLL_THROTTLE_MS = 50;
      const EXTERNAL_LINK_TITLE = "Click to Open in New Browser Window";

      const externalLinkIconSvg =
        '<svg class="fa d-icon d-icon-collections-arrow-up-right-from-square svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#collections-arrow-up-right-from-square"></use></svg>';

      const closeIcon =
        '<svg class="fa d-icon d-icon-times svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#times"></use></svg>';

      const checkIcon =
        '<svg class="fa d-icon d-icon-check svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg"><use href="#check"></use></svg>';

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

      function isExternalUrl(href) {
        if (!href) {
          return false;
        }

        if (href.startsWith("http://") || href.startsWith("https://")) {
          try {
            const url = new URL(href);
            return url.hostname !== window.location.hostname;
          } catch (_e) {
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

      function externalLinkButton(url, extraClass = "") {
        if (!url) {
          return "";
        }

        return (
          '<a href="' +
          escapeHtml(url) +
          '" class="collections-external-link-button ' +
          extraClass +
          '" target="_blank" rel="noopener noreferrer" title="' +
          escapeHtml(EXTERNAL_LINK_TITLE) +
          '" aria-label="' +
          escapeHtml(EXTERNAL_LINK_TITLE) +
          '">' +
          externalLinkIconSvg +
          "</a>"
        );
      }

      const items = Array.from(links).map((link) => {
        const href = link.getAttribute("href");

        let title = "";
        const titleEl1 = link.querySelector(".collection-link-content-text");
        const titleEl2 = link.querySelector(".sidebar-section-link-content-text");
        const titleEl3 = link.querySelector("[class*='content-text']");

        if (titleEl1 && titleEl1.textContent) {
          title = titleEl1.textContent.trim();
        }
        if (!title && titleEl2 && titleEl2.textContent) {
          title = titleEl2.textContent.trim();
        }
        if (!title && titleEl3 && titleEl3.textContent) {
          title = titleEl3.textContent.trim();
        }
        if (!title && link.textContent) {
          title = link.textContent.trim();
        }
        if (!title) {
          title = "Untitled";
        }

        const external = isExternalUrl(href);
        const topicId = external ? null : getTopicIdFromHref(href);

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
          return (
            hrefUrl.pathname === currentUrl ||
            currentUrl.indexOf(hrefUrl.pathname) !== -1
          );
        } catch (_e) {
          return false;
        }
      });

      if (currentIndex === -1) {
        return;
      }

      const currentItem = items[currentIndex];
      const totalItems = items.length;

      function getPostContentNode() {
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
      }

      const cookedNode = getPostContentNode();
      const cookedContent = cookedNode
        ? cookedNode.outerHTML
        : "<p>Loading content...</p>";

      function getScrollBehavior() {
        const reduced =
          window.matchMedia &&
          window.matchMedia("(prefers-reduced-motion: reduce)").matches;

        return reduced ? "auto" : "smooth";
      }

      function throttle(func, wait) {
        let timeout;

        return function throttled(...args) {
          clearTimeout(timeout);
          timeout = setTimeout(() => func.apply(this, args), wait);
        };
      }

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

      function enhanceCooked(element) {
        if (!element) {
          return;
        }

        api.decorateCookedElement(() => {}, {
          id: "collections-navigator-modal",
        });

        if (api.applyDecoratorsToElement) {
          api.applyDecoratorsToElement(element);
        }
      }

      function sliderButtonHtml(item, idx) {
        return (
          '<button class="slider-item ' +
          (idx === currentIndex ? "active" : "") +
          '" data-index="' +
          idx +
          '" title="' +
          escapeHtml(item.title) +
          '" type="button">' +
          '<span class="slider-item-title">' +
          escapeHtml(item.title) +
          "</span>" +
          (item.external ? externalLinkButton(item.href, "in-slider") : "") +
          "</button>"
        );
      }

      function itemLinkHtml(item, idx) {
        return (
          '<li class="collection-item ' +
          (idx === currentIndex ? "active" : "") +
          '">' +
          '<div class="collection-item-link ' +
          (item.external ? "external-link" : "") +
          '" data-index="' +
          idx +
          '" title="' +
          escapeHtml(item.title) +
          '" role="button" tabindex="0">' +
          '<span class="item-number">' +
          (idx + 1) +
          "</span>" +
          '<span class="item-title">' +
          escapeHtml(item.title) +
          "</span>" +
          (idx === currentIndex ? checkIcon : "") +
          (item.external ? externalLinkButton(item.href, "in-sidebar") : "") +
          "</div>" +
          "</li>"
        );
      }

      const navBar = document.createElement("div");
      navBar.className = "collections-item-nav-bar collections-nav-injected";
      navBar.innerHTML =
        '<button class="btn btn--primary collections-nav-toggle" title="Open collection navigator" type="button">' +
        '<svg class="fa d-icon d-icon-collection-pip svg-icon fa-width-auto prefix-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#collection-pip"></use>' +
        "</svg>" +
        '<span class="nav-text">' +
        escapeHtml(collectionName) +
        ": " +
        escapeHtml(currentItem.title) +
          " (" +
        (currentIndex + 1) +
        "/" +
        totalItems +
          ")" +
        "</span>" +
        "</button>" +
        '<div class="collections-quick-nav">' +
        '<button class="btn btn--secondary collections-nav-prev" ' +
        (currentIndex === 0 ? "disabled" : "") +
        ' title="Previous (arrow key)" type="button">' +
        '<svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#arrow-left"></use>' +
        "</svg>" +
        "</button>" +
        '<button class="btn btn--secondary collections-nav-next" ' +
        (currentIndex === totalItems - 1 ? "disabled" : "") +
        ' title="Next (arrow key)" type="button">' +
        '<svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#arrow-right"></use>' +
        "</svg>" +
        "</button>" +
        "</div>";

      postsContainer.parentNode.insertBefore(navBar, postsContainer);

      const modal = document.createElement("div");
      modal.className = "collections-nav-modal-overlay";
      modal.innerHTML =
        '<div class="collections-nav-modal collections-modal-with-content">' +





        



      




        
        '<div class="modal-header">' +
        '<button class="modal-sidebar-toggle btn btn-flat btn--toggle no-text btn-icon narrow-desktop" aria-label="Toggle sidebar" type="button" title="Toggle sidebar">' +
        '<svg class="fa d-icon d-icon-bars svg-icon svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#bars"></use>' +
        "</svg>" +
        "</button>" +

        '<div class="modal-header-content">' +
        '<h2 class="modal-title">' +
        escapeHtml(collectionName) +
        "</h2>" +
        (collectionDesc
          ? '<p class="collection-description">' +
            escapeHtml(collectionDesc) +
            "</p>"
          : "") +


        









        
        "</div>" +
        '<button class="modal-close-btn" aria-label="Close modal" type="button">' +
        closeIcon +
        "</button>" +
        "</div>" +





          '<div class="topic-slider-container">' +



'<span class="prev-span">' +
        '<button class="btn btn--secondary modal-content-prev" title="Previous item" type="button" ' +
        (currentIndex === 0 ? "disabled" : "") +
        ">" +
        '<svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#arrow-left"></use>' +
        "</svg>" +
        "Prev" +
        "</button>" +
"</span>" +

        
          '<div class="topic-slider">' +
// To display as a brick wall of buttons
//        '<div class="user-navigation user-navigation-secondary">' +
//        '<div class="horizontal-overflow-nav has-scroll">' +
        items.map(sliderButtonHtml).join("") +
        "</div>" +




'<span class="next-span">' +
        '<button class="btn btn--secondary modal-content-next" title="Next item" type="button" ' +
        (currentIndex === totalItems - 1 ? "disabled" : "") +
        ">" +
        "Next" +
        '<svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#arrow-right"></use>' +
        "</svg>" +
        "</button>" +
"</span>" +

        
        "</div>" +



        
        
        '<div class="modal-body-split">' +
        '<div class="modal-items-sidebar collapsed">' +
        '<ul class="collection-items-list">' +
        items.map(itemLinkHtml).join("") +
        "</ul>" +
        "</div>" +
        '<div class="modal-content-area">' +
        '<div class="content-header">' +
        '<h3 class="content-title">' +
        escapeHtml(currentItem.title) +
        "</h3>" +




        '<span class="modal-paging"><span class="paging-text">' +
        " (" +
        (currentIndex + 1) +
        "/" +
        totalItems +
        ") Slides" +
        "</span></span>" +

        
        '<div class="content-header-actions"></div>' +
        "</div>" +
        '<div class="cooked-content">' +
        cookedContent +
        "</div>" +
        "</div>" +
        "</div>" +
        '<div class="modal-nav-footer">' +
        '<button class="btn btn--secondary modal-content-prev" title="Previous item" type="button" ' +
        (currentIndex === 0 ? "disabled" : "") +
        ">" +
        '<svg class="fa d-icon d-icon-arrow-left svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#arrow-left"></use>' +
        "</svg>" +
        "Previous" +
        "</button>" +





        
        '<button class="btn btn--secondary modal-content-next" title="Next item" type="button" ' +
        (currentIndex === totalItems - 1 ? "disabled" : "") +
        ">" +
        "Next" +
        '<svg class="fa d-icon d-icon-arrow-right svg-icon fa-width-auto svg-string" width="1em" height="1em" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">' +
        '<use href="#arrow-right"></use>' +
        "</svg>" +
        "</button>" +
        "</div>" +
        "</div>";

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

      function bindExternalLinkButtons(scope) {
        if (!scope) {
          return;
        }

        scope
          .querySelectorAll(".collections-external-link-button")
          .forEach((link) => {
            link.addEventListener("click", (e) => {
              e.stopPropagation();
            });

            link.addEventListener("mousedown", (e) => {
              e.stopPropagation();
            });

            link.addEventListener("keydown", (e) => {
              e.stopPropagation();
            });
          });
      }

      function showModal() {
        modal.style.display = "flex";
      }

      function hideModal() {
        modal.style.display = "none";
      }

      function toggleSidebar() {
        sidebarOpen = !sidebarOpen;

        if (sidebarOpen) {
          sidebar.classList.remove("collapsed");
          topicSliderContainer.classList.add("collapsed");
        } else {
          topicSliderContainer.classList.remove("collapsed");
          sidebar.classList.add("collapsed");
        }
      }

      function scrollSliderToActive() {
        const activeSlider = modal.querySelector(".slider-item.active");
        if (activeSlider) {
          activeSlider.scrollIntoView({
            behavior: getScrollBehavior(),
            block: "nearest",
            inline: "center",
          });
        }
      }

      function updatePageNavText(index) {
        const navText = navBar.querySelector(".nav-text");
        navText.textContent =
          collectionName +
          ": " +
          items[index].title +
          " (" +
          (index + 1) +
          "/" +
          totalItems +
          ")";

        prevBtn.disabled = index === 0;
        nextBtn.disabled = index === totalItems - 1;
      }

      function updatePageContent(index) {
        if (index < 0 || index >= totalItems) {
          return;
        }

        if (items[index].external) {
          return;
        }

        selectedIndex = index;
        updatePageNavText(index);

        if (!items[index].topicId) {
          return;
        }

        fetch("/t/" + items[index].topicId + ".json")
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

            const cooked =
              data &&
              data.post_stream &&
              data.post_stream.posts &&
              data.post_stream.posts[0]
                ? data.post_stream.posts[0].cooked
                : null;

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

      function loadExternalContent(url) {
        return (
          '<div class="external-url-header">' +
          "<h4>" +
          '<a href="' +
          escapeHtml(url) +
          '" target="_blank" rel="noopener noreferrer" title="' +
          escapeHtml(EXTERNAL_LINK_TITLE) +
          '" class="external-url-link">' +
          escapeHtml(url.replace(/^https?:\/\//, "")) +
          externalLinkIconSvg +
          "</a>" +
          "</h4>" +
          "</div>" +
          '<div class="iframe-loading">Loading external content...</div>' +
          '<iframe src="' +
          escapeHtml(url) +
          '" class="external-topic-iframe" sandbox="allow-same-origin allow-scripts allow-popups allow-forms allow-downloads allow-top-navigation" loading="lazy" title="External content: ' +
          escapeHtml(url) +
          '"></iframe>'
        );
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
            } catch (_e) {
              onError();
            }
          }
        }, 5000);
      }

      const updateModalContent = throttle((index) => {
        if (index < 0 || index >= totalItems) {
          return;
        }

        selectedIndex = index;
        contentTitle.textContent = items[index].title;
        contentHeaderActions.innerHTML = "";
        pagingText.textContent = index + 1 + "/" + totalItems;
        modalContentPrev.disabled = index === 0;
        modalContentNext.disabled = index === totalItems - 1;

        sliderItems.forEach((item, idx) => {
          item.classList.toggle("active", idx === index);
        });

        itemLinks.forEach((link, idx) => {
          link.classList.toggle("active", idx === index);
        });

        setTimeout(scrollSliderToActive, 100);

        if (items[index].external) {
          modal.classList.add("external-url-active");
          contentArea.classList.add("external-url-content-wrapper");
          contentArea.innerHTML = loadExternalContent(items[index].href);
          setupIframeHandlers(contentArea);

          contentHeaderActions.innerHTML =
            '<a href="' +
            escapeHtml(items[index].href) +
            '" target="_blank" rel="noopener noreferrer" title="' +
            escapeHtml(EXTERNAL_LINK_TITLE) +
            '" class="btn btn-primary collections-open-external-button">' +
            externalLinkIconSvg +
            "Open in New Tab" +
            "</a>";
        } else {
          modal.classList.remove("external-url-active");
          contentArea.classList.remove("external-url-content-wrapper");
          contentArea.style.visibility = "";
          contentArea.style.height = "";
          contentArea.innerHTML = "<p>Loading...</p>";

          if (items[index].topicId) {
            fetch("/t/" + items[index].topicId + ".json")
              .then((r) => r.json())
              .then((data) => {
                const cooked =
                  data &&
                  data.post_stream &&
                  data.post_stream.posts &&
                  data.post_stream.posts[0]
                    ? data.post_stream.posts[0].cooked
                    : null;

                contentArea.innerHTML = cooked || "<p>No content</p>";
                enhanceCooked(contentArea);
              })
              .catch(() => {
                contentArea.innerHTML = "<p>Error loading</p>";
              });
          }
        }

        bindExternalLinkButtons(modal);
        updatePageNavText(index);
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

      bindExternalLinkButtons(modal);

      if (!document.body.hasAttribute(INIT_FLAG)) {
        document.body.setAttribute(INIT_FLAG, "true");

        let lastKeyPress = 0;

        document.addEventListener("keydown", (e) => {
          const currentModal = document.querySelector(
            ".collections-nav-modal-overlay"
          );
          const modalVisible =
            currentModal && currentModal.style.display === "flex";

          const currentPrevBtn = document.querySelector(".collections-nav-prev");
          const currentNextBtn = document.querySelector(".collections-nav-next");
          const currentModalPrev = document.querySelector(".modal-content-prev");
          const currentModalNext = document.querySelector(".modal-content-next");

          const now = Date.now();
          if (now - lastKeyPress < KEYBOARD_THROTTLE_MS) {
            return;
          }

          if (modalVisible) {
            if (
              e.key === "ArrowLeft" &&
              currentModalPrev &&
              !currentModalPrev.disabled
            ) {
              lastKeyPress = now;
              e.preventDefault();
              currentModalPrev.click();
            } else if (
              e.key === "ArrowRight" &&
              currentModalNext &&
              !currentModalNext.disabled
            ) {
              lastKeyPress = now;
              e.preventDefault();
              currentModalNext.click();
            } else if (e.key === "Escape") {
              const currentCloseBtn = document.querySelector(".modal-close-btn");
              if (currentCloseBtn) {
                lastKeyPress = now;
                e.preventDefault();
                currentCloseBtn.click();
              }
            }
          } else {
            if (
              e.key === "ArrowLeft" &&
              currentPrevBtn &&
              !currentPrevBtn.disabled
            ) {
              lastKeyPress = now;
              e.preventDefault();
              currentPrevBtn.click();
            } else if (
              e.key === "ArrowRight" &&
              currentNextBtn &&
              !currentNextBtn.disabled
            ) {
              lastKeyPress = now;
              e.preventDefault();
              currentNextBtn.click();
            }
          }
        });
      }
    }, 500);
  });
});
