import Component from "@glimmer/component";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { getCollectionsNavigatorState } from "../lib/collections-navigator-state";

export default class CollectionsNavBar extends Component {
  static shouldRender() {
    return true;
  }

  get state() {
    return getCollectionsNavigatorState();
  }

  get shouldRenderBar() {
    return this.state?.ready;
  }

  get navText() {
    if (!this.shouldRenderBar) {
      return "";
    }

    return `${this.state.collectionName}: ${this.state.currentItem.title} (${
      this.state.currentIndex + 1
    }/${this.state.totalItems})`;
  }

  get isFirst() {
    return !this.shouldRenderBar || this.state.currentIndex <= 0;
  }

  get isLast() {
    return (
      !this.shouldRenderBar ||
      this.state.currentIndex >= this.state.totalItems - 1
    );
  }

  @action
  openModal() {
    document.dispatchEvent(
      new CustomEvent("collections:navigator:open", { bubbles: true })
    );
  }

  @action
  previousItem() {
    document.dispatchEvent(
      new CustomEvent("collections:navigator:previous", { bubbles: true })
    );
  }

  @action
  nextItem() {
    document.dispatchEvent(
      new CustomEvent("collections:navigator:next", { bubbles: true })
    );
  }

  <template>
    {{#if this.shouldRenderBar}}
      <div class="collections-item-nav-bar collections-nav-injected">
        <button
          class="btn btn--primary collections-nav-toggle"
          type="button"
          title="Open collection navigator"
          {{on "click" this.openModal}}
        >
          <svg
            class="fa d-icon d-icon-collection-pip svg-icon fa-width-auto prefix-icon svg-string"
            width="1em"
            height="1em"
            aria-hidden="true"
            xmlns="http://www.w3.org/2000/svg"
          >
            <use href="#collection-pip"></use>
          </svg>

          <span class="nav-text">{{this.navText}}</span>
        </button>

        <div class="collections-quick-nav">
          <button
            class="btn btn--secondary collections-nav-prev"
            type="button"
            title="Previous (arrow key)"
            disabled={{this.isFirst}}
            {{on "click" this.previousItem}}
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
            disabled={{this.isLast}}
            {{on "click" this.nextItem}}
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
    {{/if}}
  </template>
}
