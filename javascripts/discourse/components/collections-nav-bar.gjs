import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getCollectionsNavigatorState } from "../lib/collections-navigator-state";

export default class CollectionsNavBar extends Component {
  get state() {
    return getCollectionsNavigatorState();
  }

  get shouldRender() {
    return this.state?.ready;
  }

  get navText() {
    if (!this.shouldRender) {
      return "";
    }

    return `${this.state.collectionName}: ${this.state.currentItem.title} (${
      this.state.currentIndex + 1
    }/${this.state.totalItems})`;
  }

  get isFirst() {
    return !this.shouldRender || this.state.currentIndex <= 0;
  }

  get isLast() {
    return (
      !this.shouldRender ||
      this.state.currentIndex >= this.state.totalItems - 1
    );
  }

  @action
  openModal() {
    document.dispatchEvent(new CustomEvent("collections:navigator:open"));
  }

  @action
  previousItem() {
    document.dispatchEvent(new CustomEvent("collections:navigator:previous"));
  }

  @action
  nextItem() {
    document.dispatchEvent(new CustomEvent("collections:navigator:next"));
  }

  <template>
    {{#if this.shouldRender}}
      <div class="collections-item-nav-bar collections-nav-injected">
        <button
          class="btn btn--primary collections-nav-toggle"
          type="button"
          title={{theme-i18n "collections_navigator.open"}}
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
            title={{theme-i18n "collections_navigator.previous"}}
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
            title={{theme-i18n "collections_navigator.next"}}
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
