import { apiInitializer } from "discourse/lib/api";
import CollectionsNavBar from "../components/collections-nav-bar";
import {
  bindCollectionsNavigatorEvents,
  ensureCollectionsNavigatorModal,
  initializeCollectionsNavigatorState,
} from "../lib/collections-navigator-state";

export default apiInitializer("1.24.0", (api) => {
  api.renderInOutlet("topic-above-post-stream", CollectionsNavBar);

  api.onPageChange(() => {
    if (!settings.collections_navigator_enabled) {
      return;
    }

    setTimeout(() => {
      initializeCollectionsNavigatorState(api);
      ensureCollectionsNavigatorModal(api);
      bindCollectionsNavigatorEvents(api);
    }, 300);
  });
});
